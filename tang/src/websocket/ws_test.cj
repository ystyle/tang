package tang.websocket

import std.collection.ArrayList
import std.net.{TcpServerSocket, TcpSocket}
import ystyle::tachyon.Server
import tang.{Router, Tang, TangHttpContext}

func hexOf(data: Array<Byte>): String {
    let digits = "0123456789abcdef".toArray()
    let sb = StringBuilder()
    for (b in data) {
        let v = Int64(b)
        sb.append(String.fromUtf8([digits[(v >> 4) & 0xF]]))
        sb.append(String.fromUtf8([digits[v & 0xF]]))
    }
    return sb.toString()
}

@Test
class DigestTest {
    @TestCase
    func testSha1Vectors(): Unit {
        // RFC 3174 测试向量
        @Expect(hexOf(sha1("abc".toArray())), "a9993e364706816aba3e25717850c26c9cd0d89d")
        @Expect(hexOf(sha1("".toArray())), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        @Expect(hexOf(sha1("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".toArray())),
                "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
    }

    @TestCase
    func testBase64Encode(): Unit {
        @Expect(base64Encode("".toArray()), "")
        @Expect(base64Encode("f".toArray()), "Zg==")
        @Expect(base64Encode("fo".toArray()), "Zm8=")
        @Expect(base64Encode("foo".toArray()), "Zm9v")
        @Expect(base64Encode("hello".toArray()), "aGVsbG8=")
    }

    @TestCase
    func testAcceptKeyRfcVector(): Unit {
        // RFC 6455 §1.3 的示例值
        @Expect(acceptKey("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }
}

// ---- e2e：真起 tachyon 服务，用裸 socket 走一次握手 + 回显 ----

func startWsServer(port: UInt16): (Server, TcpServerSocket) {
    let app = Tang()
    app.get("/ws", websocket({ conn: WebSocketConn =>
        // 回显：收到文本就原样发回，收到 close 自然退出
        while (true) {
            match (conn.readMessage()) {
                case Some(msg) => conn.writeText("echo:" + msg.text())
                case None => break
            }
        }
    }))
    let srv = Server({ ctx => app.getRouter().handle(ctx) })
    srv.readTimeout = Duration.second * 10
    let sock = TcpServerSocket(bindAt: port)
    sock.reuseAddress = true
    sock.bind()
    spawn { srv.serve(sock) }
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

func stopWsServer(srv: Server, sock: TcpServerSocket): Unit {
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

/// 构造客户端帧（必须加掩码）
func clientFrame(opcode: Int64, payload: Array<Byte>): Array<Byte> {
    let out = ArrayList<Byte>()
    out.add(UInt8(0x80 | opcode))
    let n = payload.size
    if (n < 126) {
        out.add(UInt8(0x80 | n))
    } else if (n <= 0xFFFF) {
        out.add(UInt8(0x80 | 126))
        out.add(UInt8((n >> 8) & 0xFF))
        out.add(UInt8(n & 0xFF))
    } else {
        out.add(UInt8(0x80 | 127))
        var shift: Int64 = 56
        while (shift >= 0) {
            out.add(UInt8((n >> shift) & 0xFF))
            shift -= 8
        }
    }
    let mask = [UInt8(0x37), UInt8(0xFA), UInt8(0x21), UInt8(0x3D)]
    for (m in mask) {
        out.add(m)
    }
    var i: Int64 = 0
    while (i < n) {
        out.add(UInt8(Int64(payload[i]) ^ Int64(mask[i % 4])))
        i += 1
    }
    let arr = Array<Byte>(out.size, repeat: 0)
    var j: Int64 = 0
    while (j < out.size) {
        arr[j] = out[j]
        j += 1
    }
    return arr
}

/// 读 socket 直到凑够 n 字节（或超时/关闭）
func readN(s: TcpSocket, n: Int64, initial: ArrayList<Byte>): ArrayList<Byte> {
    var buf = initial
    let chunk = Array<Byte>(4096, repeat: 0)
    while (buf.size < n) {
        let got = try {
            s.read(chunk)
        } catch (e: Exception) {
            0
        }
        if (got <= 0) {
            break
        }
        var i: Int64 = 0
        while (i < got) {
            buf.add(chunk[i])
            i += 1
        }
    }
    return buf
}

@Test
class WebSocketE2ETest {
    @TestCase
    func testHandshakeAndEcho(): Unit {
        let port: UInt16 = 27351
        let (srv, sock) = startWsServer(port)

        let c = TcpSocket("127.0.0.1", port)
        c.connect()
        c.readTimeout = Duration.second * 5
        let req = "GET /ws HTTP/1.1\r\n" +
                  "Host: 127.0.0.1\r\n" +
                  "Upgrade: websocket\r\n" +
                  "Connection: Upgrade\r\n" +
                  "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" +
                  "Sec-WebSocket-Version: 13\r\n\r\n"
        c.write(req.toArray())

        // 读握手响应
        var buf = ArrayList<Byte>()
        let chunk = Array<Byte>(4096, repeat: 0)
        var headerEnd: Int64 = -1
        while (headerEnd < 0) {
            let got = try {
                c.read(chunk)
            } catch (e: Exception) {
                0
            }
            if (got <= 0) {
                break
            }
            var i: Int64 = 0
            while (i < got) {
                buf.add(chunk[i])
                i += 1
            }
            // 找 


            var k: Int64 = 0
            while (k + 3 < buf.size) {
                if (buf[k] == 13 && buf[k + 1] == 10 && buf[k + 2] == 13 && buf[k + 3] == 10) {
                    headerEnd = k
                    break
                }
                k += 1
            }
        }
        @Expect(headerEnd >= 0, true)
        let head = StringBuilder()
        var h: Int64 = 0
        while (h <= headerEnd) {
            head.append(String.fromUtf8([buf[h]]))
            h += 1
        }
        let headText = head.toString()
        @Expect(headText.startsWith("HTTP/1.1 101"), true)
        @Expect(headText.contains("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), true)

        // 发一条 masked 文本帧
        c.write(clientFrame(1, "hi".toArray()))

        // 收 echo 帧：2 字节头 + payload
        let rest = ArrayList<Byte>()
        var q = headerEnd + 4
        while (q < buf.size) {
            rest.add(buf[q])
            q += 1
        }
        let got2 = readN(c, 4, rest)   // b0 b1 + "ec"? 先凑够头 2 字节 + 至少 1 字节
        // 头两字节
        @Expect(got2.size >= 2, true)
        let b0 = got2[0]
        let b1 = got2[1]
        @Expect(Int64(b0 & 0x0F), 1)          // text
        let len = Int64(b1 & 0x7F)
        @Expect(Int64(b1 & 0x80), 0)          // 服务端不加掩码
        let full = readN(c, 2 + len, got2)
        let payload = StringBuilder()
        var p: Int64 = 2
        while (p < 2 + len && p < full.size) {
            payload.append(String.fromUtf8([full[p]]))
            p += 1
        }
        @Expect(payload.toString(), "echo:hi")

        // 客户端发 close，服务端应回 close 并关闭
        c.write(clientFrame(8, [UInt8(0x03), UInt8(0xE8)]))
        try {
            c.close()
        } catch (e: Exception) {
            ()
        }
        stopWsServer(srv, sock)
    }

    @TestCase
    func testNonUpgradeGets426(): Unit {
        let port: UInt16 = 27352
        let app = Tang()
        app.get("/ws", websocket({ conn: WebSocketConn => conn.writeText("x") }))
        let srv = Server({ ctx => app.getRouter().handle(ctx) })
        let sock = TcpServerSocket(bindAt: port)
        sock.reuseAddress = true
        sock.bind()
        spawn { srv.serve(sock) }
        sleep(Duration.millisecond * 300)

        let c = TcpSocket("127.0.0.1", port)
        c.connect()
        c.readTimeout = Duration.second * 3
        c.write("GET /ws HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n".toArray())
        let chunk = Array<Byte>(2048, repeat: 0)
        let got = try {
            c.read(chunk)
        } catch (e: Exception) {
            0
        }
        let text = if (got > 0) { String.fromUtf8(chunk[0..got]) } else { "" }
        @Expect(text.startsWith("HTTP/1.1 426"), true)
        try {
            c.close()
        } catch (e: Exception) {
            ()
        }
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
}
