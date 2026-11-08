package tang.middleware.proxy

import std.collection.ArrayList
import std.net.{TcpServerSocket, TcpSocket}
import ystyle::tachyon.Server
import tang.{Tang, Router, TangHttpContext}
import tang.http.HttpClient

func startRouterServer(router: Router, port: UInt16): (Server, TcpServerSocket) {
    let srv = Server({ ctx => router.handle(ctx) })
    srv.readTimeout = Duration.second * 15
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

func stopServer(srv: Server, sock: TcpServerSocket): Unit {
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

/// 后端应用：把收到的路径/方法/头/body 回显，便于断言
func backendRouter(name: String): Router {
    let r = Router()
    r.get("/hello", { ctx: TangHttpContext => ctx.writeString("hello-from-" + name) })
    r.get("/users/:id", { ctx: TangHttpContext => ctx.writeString("user-" + ctx.param("id")) })
    r.post("/echo", { ctx: TangHttpContext =>
        let body = String.fromUtf8(ctx.raw.body().toArray())
        ctx.writeString("echo-" + body)
    })
    r.get("/headers", { ctx: TangHttpContext =>
        let xff = match (ctx.request.headers.getFirst("X-Forwarded-For")) {
            case Some(v) => v
            case None => "none"
        }
        let host = match (ctx.request.headers.getFirst("X-Forwarded-Host")) {
            case Some(v) => v
            case None => "none"
        }
        ctx.writeString("xff=" + xff + ";host=" + host)
    })
    r.get("/path", { ctx: TangHttpContext => ctx.writeString("path=" + ctx.path()) })
    r.get("/teapot", { ctx: TangHttpContext =>
        ctx.responseBuilder.status(418u16)
        ctx.responseBuilder.header("X-Teapot", "yes")
        ctx.writeString("short and stout")
    })
    return r
}

/// 前端应用：/api 下全部代理到后端
func frontRouter(opts: Array<ProxyOption>): Router {
    let app = Tang()
    let g = app.group("/api")
    g.use([proxy(opts)])
    // 路由只是给中间件链一个挂载点；proxy 命中后不会调用它
    g.all("/*", { ctx: TangHttpContext => ctx.writeString("unreachable") })
    return app.getRouter()
}

@Test
class ProxyTest {
    func noBody(): Array<Byte> {
        return Array<Byte>(0, repeat: 0)
    }

    func noHeaders(): ArrayList<(String, String)> {
        return ArrayList<(String, String)>()
    }

    @TestCase
    func testForwardGetWithStripPrefix(): Unit {
        let (bsrv, bsock) = startRouterServer(backendRouter("b1"), 18221u16)
        let (fsrv, fsock) = startRouterServer(
            frontRouter([withBackend("http://127.0.0.1:18221"), withStripPrefix("/api")]), 18222u16)

        let client = HttpClient()
        let resp = client.send("GET", "http://127.0.0.1:18222/api/hello", noHeaders(), noBody())
        @Expect(resp.status, 200u16)
        @Expect(String.fromUtf8(resp.body), "hello-from-b1")

        // 路径参数
        let resp2 = client.send("GET", "http://127.0.0.1:18222/api/users/7", noHeaders(), noBody())
        @Expect(String.fromUtf8(resp2.body), "user-7")

        // 上游看到的路径是剥离后的 /hello
        let resp3 = client.send("GET", "http://127.0.0.1:18222/api/path", noHeaders(), noBody())
        @Expect(String.fromUtf8(resp3.body), "path=/path")

        stopServer(fsrv, fsock)
        stopServer(bsrv, bsock)
    }

    @TestCase
    func testForwardPostBody(): Unit {
        let (bsrv, bsock) = startRouterServer(backendRouter("b2"), 18223u16)
        let (fsrv, fsock) = startRouterServer(
            frontRouter([withBackend("http://127.0.0.1:18223"), withStripPrefix("/api")]), 18224u16)

        let client = HttpClient()
        let resp = client.send("POST", "http://127.0.0.1:18224/api/echo", noHeaders(), "payload".toArray())
        @Expect(resp.status, 200u16)
        @Expect(String.fromUtf8(resp.body), "echo-payload")

        stopServer(fsrv, fsock)
        stopServer(bsrv, bsock)
    }

    @TestCase
    func testForwardHeadersAndStatus(): Unit {
        let (bsrv, bsock) = startRouterServer(backendRouter("b3"), 18225u16)
        let (fsrv, fsock) = startRouterServer(
            frontRouter([withBackend("http://127.0.0.1:18225"), withStripPrefix("/api")]), 18226u16)

        let client = HttpClient()
        // 转发头注入
        let resp = client.send("GET", "http://127.0.0.1:18226/api/headers", noHeaders(), noBody())
        let text = String.fromUtf8(resp.body)
        @Expect(text.contains("xff="), true)
        @Expect(text.contains("host="), true)

        // 状态码与响应头透传
        let resp2 = client.send("GET", "http://127.0.0.1:18226/api/teapot", noHeaders(), noBody())
        @Expect(resp2.status, 418u16)
        match (resp2.header("X-Teapot")) {
            case Some(v) => @Expect(v, "yes")
            case None => @Fail("X-Teapot 未透传")
        }
        @Expect(String.fromUtf8(resp2.body), "short and stout")

        stopServer(fsrv, fsock)
        stopServer(bsrv, bsock)
    }

    @TestCase
    func testRoundRobinAcrossBackends(): Unit {
        let (b1srv, b1sock) = startRouterServer(backendRouter("r1"), 18227u16)
        let (b2srv, b2sock) = startRouterServer(backendRouter("r2"), 18228u16)
        let (fsrv, fsock) = startRouterServer(
            frontRouter([
                withBackend("http://127.0.0.1:18227"),
                withBackend("http://127.0.0.1:18228"),
                withStrategy(LoadBalanceStrategy.RoundRobin),
                withStripPrefix("/api")
            ]), 18229u16)

        let client = HttpClient()
        let r1 = String.fromUtf8(client.send("GET", "http://127.0.0.1:18229/api/hello", noHeaders(), noBody()).body)
        let r2 = String.fromUtf8(client.send("GET", "http://127.0.0.1:18229/api/hello", noHeaders(), noBody()).body)
        let r3 = String.fromUtf8(client.send("GET", "http://127.0.0.1:18229/api/hello", noHeaders(), noBody()).body)
        // 轮询：前两个必然不同源，第三个回到第一个
        @Expect(r1 != r2, true)
        @Expect(r1, r3)

        stopServer(fsrv, fsock)
        stopServer(b1srv, b1sock)
        stopServer(b2srv, b2sock)
    }

    @TestCase
    func testNoBackendPassesThrough(): Unit {
        let app = Tang()
        let g = app.group("/api")
        g.use([proxy()])
        g.all("/*", { ctx: TangHttpContext => ctx.writeString("passthrough") })
        let (fsrv, fsock) = startRouterServer(app.getRouter(), 18230u16)

        let client = HttpClient()
        let resp = client.send("GET", "http://127.0.0.1:18230/api/x", noHeaders(), noBody())
        @Expect(resp.status, 200u16)
        @Expect(String.fromUtf8(resp.body), "passthrough")

        stopServer(fsrv, fsock)
    }

    @TestCase
    func testBackendDownReturns502(): Unit {
        // 18231 上没有服务
        let (fsrv, fsock) = startRouterServer(
            frontRouter([withBackend("http://127.0.0.1:18231"), withStripPrefix("/api"), withRetry(0)]), 18232u16)
        let client = HttpClient()
        let resp = client.send("GET", "http://127.0.0.1:18232/api/hello", noHeaders(), noBody())
        @Expect(resp.status, 502u16)
        stopServer(fsrv, fsock)
    }
}
