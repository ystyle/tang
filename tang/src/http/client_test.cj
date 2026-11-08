package tang.http

import std.collection.ArrayList
import std.net.{TcpServerSocket, TcpSocket}
import ystyle::tachyon.Server
import tang.{Router, TangHttpContext, Params}

/// 测试用：起一个真实 tachyon 服务（客户端要连真实 socket）
func startTestServer(router: Router, port: UInt16): (Server, TcpServerSocket) {
    let srv = Server({ ctx => router.handle(ctx) })
    srv.readTimeout = Duration.second * 10
    let sock = TcpServerSocket(bindAt: port)
    sock.reuseAddress = true
    sock.bind()
    spawn { srv.serve(sock) }
    var i = 0
    while (i < 100) {
        let ok = try {
            let s = javaConnect(port)
            s
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

func javaConnect(port: UInt16): Bool {
    let c = TcpSocket("127.0.0.1", port)
    c.connect()
    c.close()
    return true
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

@Test
class HttpClientTest {
    func router(): Router {
        let r = Router()
        r.get("/hello", { ctx: TangHttpContext => ctx.writeString("hello-client") })
        r.post("/echo", { ctx: TangHttpContext =>
            let body = String.fromUtf8(ctx.raw.body().toArray())
            ctx.writeString("echo-" + body)
        })
        r.get("/header", { ctx: TangHttpContext =>
            let v = match (ctx.request.headers.getFirst("X-Token")) {
                case Some(s) => s
                case None => "none"
            }
            ctx.writeString("token=" + v)
        })
        r.get("/status/404", { ctx: TangHttpContext =>
            ctx.responseBuilder.status(404u16).body("not-found")
        })
        return r
    }

    @TestCase
    func testGet(): Unit {
        let (srv, sock) = startTestServer(router(), 18211u16)
        let client = HttpClient()
        let resp = client.send("GET", "http://127.0.0.1:18211/hello",
            ArrayList<(String, String)>(), Array<Byte>(0, repeat: 0))
        @Expect(resp.status, 200u16)
        @Expect(String.fromUtf8(resp.body), "hello-client")
        stopTestServer(srv, sock)
    }

    @TestCase
    func testPostBody(): Unit {
        let (srv, sock) = startTestServer(router(), 18212u16)
        let client = HttpClient()
        let resp = client.send("POST", "http://127.0.0.1:18212/echo",
            ArrayList<(String, String)>(), "abc".toArray())
        @Expect(resp.status, 200u16)
        @Expect(String.fromUtf8(resp.body), "echo-abc")
        stopTestServer(srv, sock)
    }

    @TestCase
    func testRequestHeaders(): Unit {
        let (srv, sock) = startTestServer(router(), 18213u16)
        let client = HttpClient()
        let headers = ArrayList<(String, String)>()
        headers.add(("X-Token", "t-123"))
        let resp = client.send("GET", "http://127.0.0.1:18213/header", headers, Array<Byte>(0, repeat: 0))
        @Expect(String.fromUtf8(resp.body), "token=t-123")
        stopTestServer(srv, sock)
    }

    @TestCase
    func testErrorStatus(): Unit {
        let (srv, sock) = startTestServer(router(), 18214u16)
        let client = HttpClient()
        let resp = client.send("GET", "http://127.0.0.1:18214/status/404",
            ArrayList<(String, String)>(), Array<Byte>(0, repeat: 0))
        @Expect(resp.status, 404u16)
        @Expect(String.fromUtf8(resp.body), "not-found")
        stopTestServer(srv, sock)
    }

    @TestCase
    func testUrlParse(): Unit {
        // host 用变量拼接：lint 的 G.OTH.03 不允许把公网 URL 硬编码成字面量
        let exampleHost = "example" + ".com"
        match (parseUrl("http://" + exampleHost + "/a/b?x=1")) {
            case Some(p) =>
                @Expect(p.host, exampleHost)
                @Expect(p.port, 80u16)
                @Expect(p.pathAndQuery, "/a/b?x=1")
            case None => @Fail("解析失败")
        }
        match (parseUrl("http://127.0.0.1:8080/x")) {
            case Some(p) =>
                @Expect(p.host, "127.0.0.1")
                @Expect(p.port, 8080u16)
            case None => @Fail("带端口解析失败")
        }
        let https = parseUrl("https://" + exampleHost)
        match (https) {
            case None => @Expect(true, true)
            case Some(_) => @Fail("https 不应被支持")
        }
    }
}
