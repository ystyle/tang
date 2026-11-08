package tang

import ystyle::tachyon.Server
import std.net.{TcpSocket, TcpServerSocket}
import std.convert.*

/// e2e 测试辅助：用 tachyon 起服务，用原始 TcpSocket 发请求
///
/// 为什么不用 HTTP 客户端库：tang core 已零 stdx，测试也不该把 stdx 拉回来。
/// 这几条 e2e 只需要"发原始报文 + 读回原始响应"，裸 socket 足够且更可控。

/// 起服务（固定端口），返回 (server, socket) 供 stop 使用
func startTestServer(router: Router, port: UInt16): (Server, TcpServerSocket) {
    let srv = Server({ ctx => router.handle(ctx) })
    srv.readTimeout = Duration.second * 10
    let sock = TcpServerSocket(bindAt: port)
    sock.reuseAddress = true
    sock.bind()
    spawn { srv.serve(sock) }
    // 轮询直到能连上
    var i = 0
    while (i < 100) {
        let ok = try {
            let c = TcpSocket("127.0.0.1", port)
            c.connect()
            c.close()
            true
        } catch (e: Exception) {
            false
        }
        if (ok) {
            break
        }
        sleep(Duration.millisecond * 50)
        i += 1
    }
    return (srv, sock)
}

func stopTestServer(srv: Server, sock: TcpServerSocket): Unit {
    try {
        srv.shutdown()
    } catch (e: Exception) {
        ()
    }
    try {
        sock.close()
    } catch (e: Exception) {
        ()
    }
}

/// 发一条原始请求，返回完整响应报文
func rawRequest(port: UInt16, raw: String): String {
    let c = TcpSocket("127.0.0.1", port)
    c.connect()
    c.readTimeout = Duration.second * 5
    c.write(raw.toArray())
    let buf = Array<Byte>(65536, repeat: 0)
    var total: Int64 = 0
    var guard = 0
    while (guard < 20) {
        guard += 1
        let n = try {
            c.read(buf[total..])
        } catch (e: Exception) {
            0
        }
        if (n <= 0) {
            break
        }
        total += n
        // 读到 header 结束 + 已知 Content-Length 就停
        if (total >= 4) {
            let resp = String.fromUtf8(buf[0..total])
            if (let Some(idx) <- resp.indexOf("\r\n\r\n")) {
                let head = resp[0..idx]
                var contentLen: Int64 = 0
                for (line in head.split("\r\n")) {
                    if (line.startsWith("Content-Length:")) {
                        match (Int64.tryParse(line[15..].trimAscii())) {
                            case Some(v) => contentLen = v
                            case None => ()
                        }
                    }
                }
                if (total >= idx + 4 + contentLen) {
                    break
                }
            }
        }
    }
    try {
        c.close()
    } catch (e: Exception) {
        ()
    }
    if (total <= 0) {
        return ""
    }
    return String.fromUtf8(buf[0..total])
}

func httpGet(port: UInt16, path: String): String {
    return rawRequest(port, "GET " + path + " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
}

func httpPost(port: UInt16, path: String, body: String): String {
    return rawRequest(port,
        "POST " + path + " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\nContent-Length: " +
        body.size.toString() + "\r\n\r\n" + body)
}

/// 取响应状态码
func statusOf(resp: String): Int64 {
    // "HTTP/1.1 200 OK..." -> 200
    if (resp.size < 12) {
        return -1
    }
    match (Int64.tryParse(resp[9..12])) {
        case Some(v) => return v
        case None => return -1
    }
}

/// 取响应 body
func bodyOf(resp: String): String {
    match (resp.indexOf("\r\n\r\n")) {
        case Some(i) => return resp[i + 4..]
        case None => return ""
    }
}

/// 取响应头（大小写不敏感）
func headerOf(resp: String, name: String): ?String {
    match (resp.indexOf("\r\n\r\n")) {
        case Some(end) =>
            let head = resp[0..end]
            for (line in head.split("\r\n")) {
                if (line.size > name.size && line[0..name.size].toAsciiLower() == name.toAsciiLower() && line[name.size] == 58) {
                    return Some(line[name.size + 1..].trimAscii())
                }
            }
            return None
        case None => return None
    }
}
