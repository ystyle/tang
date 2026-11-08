package tang.websocket

import std.collection.ArrayList
import std.net.TcpSocket
import ystyle::tachyon.{Bytes, HijackedConn, RequestCtx}
import tang.{HandlerFunc, TangHttpContext}

/// WebSocket 帧类型（RFC 6455 §5.1）
public enum WsOpcode {
    | Continuation
    | Text
    | Binary
    | Close
    | Ping
    | Pong
}

/// 一条完整的消息（分片会被拼好）
public class WsMessage {
    public let opcode: WsOpcode
    public let data: Array<Byte>

    init(opcode: WsOpcode, data: Array<Byte>) {
        this.opcode = opcode
        this.data = data
    }

    public func text(): String {
        return String.fromUtf8(data)
    }
}

/// 解析出来的单帧（内部用）
class WsFrame {
    let fin: Bool
    let opcode: WsOpcode
    let data: Array<Byte>

    init(fin: Bool, opcode: WsOpcode, data: Array<Byte>) {
        this.fin = fin
        this.opcode = opcode
        this.data = data
    }
}

/// 一条已建立的 WebSocket 连接
///
/// 生命周期：handler 拿到它 → 循环读写 → 返回后连接关闭。
/// 实现边界（与 fasthttp 生态的 ws 库一致）：不做 permessage-deflate、不做扩展协商、
/// 不做协议级超时（需要由使用者通过 socket 读超时控制）。
public class WebSocketConn {
    let socket: TcpSocket
    /// 劫持前已经读进 tachyon 缓冲区、但还没被消费的字节（握手后的第一帧可能就在这里）
    var pending: ArrayList<Byte>

    init(socket: TcpSocket, pendingBytes: Bytes) {
        this.socket = socket
        this.pending = ArrayList<Byte>()
        for (b in pendingBytes.toArray()) {
            this.pending.add(b)
        }
    }

    /// 设置读超时（0 表示不限）
    public func setReadTimeout(d: Duration): Unit {
        socket.readTimeout = d
    }

    /// 读下一条完整消息；连接关闭返回 None
    ///
    /// 控制帧（ping/pong/close）在内部处理：ping 自动回 pong，close 回 close 并返回 None。
    public func readMessage(): ?WsMessage {
        var opcode = WsOpcode.Text
        var payload = ArrayList<Byte>()
        var started = false
        while (true) {
            let frame = match (readFrame()) {
                case Some(f) => f
                case None => return None
            }
            match (frame.opcode) {
                case WsOpcode.Ping =>
                    writeFrame(WsOpcode.Pong, frame.data)
                    continue
                case WsOpcode.Pong =>
                    continue
                case WsOpcode.Close =>
                    // 回 close 完成关闭握手
                    writeFrame(WsOpcode.Close, Array<Byte>(0, repeat: 0))
                    return None
                case WsOpcode.Text | WsOpcode.Binary =>
                    if (started) {
                        // 协议错误：上一条消息还没结束又来了数据帧
                        return None
                    }
                    opcode = frame.opcode
                    started = true
                case WsOpcode.Continuation =>
                    if (!started) {
                        return None
                    }
            }
            for (b in frame.data) {
                payload.add(b)
            }
            if (frame.fin) {
                return Some(WsMessage(opcode, toArray(payload)))
            }
        }
        return None
    }

    /// 发文本消息（UTF-8）
    public func writeText(text: String): Unit {
        writeFrame(WsOpcode.Text, text.toArray())
    }

    /// 发二进制消息
    public func writeBinary(data: Array<Byte>): Unit {
        writeFrame(WsOpcode.Binary, data)
    }

    /// 发 ping
    public func ping(payload: Array<Byte>): Unit {
        writeFrame(WsOpcode.Ping, payload)
    }

    /// 发 close（正常关闭 1000）
    public func close(code!: UInt16 = 1000, reason!: String = ""): Unit {
        let payload = ArrayList<Byte>()
        payload.add(UInt8((code >> 8) & 0xFF))
        payload.add(UInt8(code & 0xFF))
        for (b in reason.toArray()) {
            payload.add(b)
        }
        writeFrame(WsOpcode.Close, toArray(payload))
    }

    /// 关闭底层连接（不抛异常）
    public func closeSocket(): Unit {
        try {
            socket.close()
        } catch (e: Exception) {
            ()
        }
    }

    // ---- 帧读写 ----

    func readFrame(): ?WsFrame {
        let b0 = match (readByte()) {
            case Some(v) => v
            case None => return None
        }
        let b1 = match (readByte()) {
            case Some(v) => v
            case None => return None
        }
        let fin = (b0 & 0x80) != 0
        let opcodeVal = Int64(b0 & 0x0F)
        let opcode = match (opcodeVal) {
            case 0 => WsOpcode.Continuation
            case 1 => WsOpcode.Text
            case 2 => WsOpcode.Binary
            case 8 => WsOpcode.Close
            case 9 => WsOpcode.Ping
            case 10 => WsOpcode.Pong
            case _ => return None
        }
        let masked = (b1 & 0x80) != 0
        var len = Int64(b1 & 0x7F)
        if (len == 126) {
            let h = match (readBytes(2)) {
                case Some(v) => v
                case None => return None
            }
            len = (Int64(h[0]) << 8) | Int64(h[1])
        } else if (len == 127) {
            let h = match (readBytes(8)) {
                case Some(v) => v
                case None => return None
            }
            len = 0
            var i: Int64 = 0
            while (i < 8) {
                len = (len << 8) | Int64(h[i])
                i += 1
            }
        }
        var mask = Array<Byte>(4, repeat: 0)
        if (masked) {
            mask = match (readBytes(4)) {
                case Some(v) => v
                case None => return None
            }
        }
        let payload = match (readBytes(len)) {
            case Some(v) => v
            case None => return None
        }
        if (masked) {
            var i: Int64 = 0
            while (i < payload.size) {
                payload[i] = UInt8(Int64(payload[i]) ^ Int64(mask[i % 4]))
                i += 1
            }
        }
        return Some(WsFrame(fin, opcode, payload))
    }

    func writeFrame(opcode: WsOpcode, data: Array<Byte>): Unit {
        let out = ArrayList<Byte>()
        var b0: Byte = match (opcode) {
            case WsOpcode.Continuation => 0
            case WsOpcode.Text => 1
            case WsOpcode.Binary => 2
            case WsOpcode.Close => 8
            case WsOpcode.Ping => 9
            case WsOpcode.Pong => 10
        }
        out.add(UInt8(Int64(b0) | 0x80))   // FIN=1
        let n = data.size
        if (n < 126) {
            out.add(UInt8(n))
        } else if (n <= 0xFFFF) {
            out.add(126)
            out.add(UInt8((n >> 8) & 0xFF))
            out.add(UInt8(n & 0xFF))
        } else {
            out.add(127)
            var shift: Int64 = 56
            while (shift >= 0) {
                out.add(UInt8((n >> shift) & 0xFF))
                shift -= 8
            }
        }
        // 服务端发帧不加掩码（RFC 6455 §5.1）
        for (b in data) {
            out.add(b)
        }
        try {
            socket.write(toArray(out))
        } catch (e: Exception) {
            ()
        }
    }

    func readByte(): ?Byte {
        let r = readBytes(1)
        match (r) {
            case Some(v) => return Some(v[0])
            case None => return None
        }
    }

    func readBytes(n: Int64): ?Array<Byte> {
        if (n == 0) {
            return Some(Array<Byte>(0, repeat: 0))
        }
        while (pending.size < n) {
            let chunk = Array<Byte>(8192, repeat: 0)
            let got = try {
                socket.read(chunk)
            } catch (e: Exception) {
                0
            }
            if (got <= 0) {
                return None
            }
            var i: Int64 = 0
            while (i < got) {
                pending.add(chunk[i])
                i += 1
            }
        }
        let out = Array<Byte>(n, repeat: 0)
        var i: Int64 = 0
        while (i < n) {
            out[i] = pending[i]
            i += 1
        }
        // 消费掉前 n 个字节
        var rest = ArrayList<Byte>()
        var j = n
        while (j < pending.size) {
            rest.add(pending[j])
            j += 1
        }
        pending = rest
        return Some(out)
    }

    func toArray(list: ArrayList<Byte>): Array<Byte> {
        let out = Array<Byte>(list.size, repeat: 0)
        var i: Int64 = 0
        while (i < list.size) {
            out[i] = list[i]
            i += 1
        }
        return out
    }
}

const WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

/// 算 Sec-WebSocket-Accept（RFC 6455 §4.2.2）
func acceptKey(clientKey: String): String {
    return base64Encode(sha1((clientKey + WS_GUID).toArray()))
}

/// WebSocket 升级 handler
///
/// 用法：`app.get("/ws", websocket({ conn => 循环读写 }))`
///
/// 实现走 tachyon 的 hijack：握手响应由本函数直接写 socket，
/// 之后连接完全交给 handler，服务端不再插手。
public func websocket(handler: (WebSocketConn) -> Unit): HandlerFunc {
    return { ctx: TangHttpContext =>
        let raw = ctx.raw
        let upgrade = raw.headerGet("Upgrade").toStr()   // 缺失时是空 Bytes
        if (upgrade.toAsciiLower() != "websocket") {
            raw.error("Expected WebSocket upgrade (Upgrade: websocket)", 426)
            return
        }
        let key = raw.headerGet("Sec-WebSocket-Key").toStr()
        if (key.isEmpty()) {
            raw.error("Missing Sec-WebSocket-Key", 400)
            return
        }
        let accept = acceptKey(key)
        raw.hijack({ hc: HijackedConn =>
            let resp = StringBuilder()
            resp.append("HTTP/1.1 101 Switching Protocols\r\n")
            resp.append("Upgrade: websocket\r\n")
            resp.append("Connection: Upgrade\r\n")
            resp.append("Sec-WebSocket-Accept: ")
            resp.append(accept)
            resp.append("\r\n\r\n")
            try {
                hc.socket.write(resp.toString().toArray())
            } catch (e: Exception) {
                return
            }
            let conn = WebSocketConn(hc.socket, hc.pendingBytes)
            try {
                handler(conn)
            } catch (e: Exception) {
                ()
            }
            conn.closeSocket()
        })
    }
}
