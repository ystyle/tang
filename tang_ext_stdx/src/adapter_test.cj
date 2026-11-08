package tang_ext_stdx

import stdx.net.http.{ClientBuilder, Client, HttpContext, HttpResponse}
import tang.Tang

@Test
class StdxCompatTest {
    func readBody(resp: HttpResponse): String {
        let chunk = Array<Byte>(8192, repeat: 0)
        let total = try {
            resp.body.read(chunk)
        } catch (e: Exception) {
            0
        }
        if (total > 0) {
            return String.fromUtf8(chunk[0..total])
        }
        return ""
    }

    func waitUp(client: Client, url: String): Bool {
        var i = 0
        while (i < 100) {
            try {
                let r = client.get(url)
                if (r.status == 200u16) {
                    return true
                }
            } catch (e: Exception) {
                ()
            }
            sleep(Duration.millisecond * 50)
            i += 1
        }
        return false
    }

    @TestCase
    func testTangRoutesOnStdxServer(): Unit {
        let app = Tang()
        app.get("/hello", { ctx => ctx.writeString("hello from tang") })
        app.post("/echo", { ctx =>
            let body = String.fromUtf8(ctx.raw.body().toArray())
            ctx.writeString("echo-" + body)
        })
        app.get("/stdx", fromStd({ stdc: HttpContext =>
            stdc.responseBuilder.header("X-From", "stdx-handler")
            stdc.responseBuilder.status(201u16)
            stdc.responseBuilder.body("hello from stdx handler")
        }))

        let server = serveAsync(app, "127.0.0.1", 18201u16)
        spawn { server.serve() }
        let client = ClientBuilder().build()
        let up = waitUp(client, "http://127.0.0.1:18201/hello")
        @Expect(up, true)

        // ① tang 自身路由在 stdx server 上照常工作
        let r1 = client.get("http://127.0.0.1:18201/hello")
        @Expect(r1.status, 200u16)
        @Expect(readBody(r1), "hello from tang")

        // ② POST + body 透传
        let r2 = client.post("http://127.0.0.1:18201/echo", "abc")
        @Expect(r2.status, 200u16)
        @Expect(readBody(r2), "echo-abc")

        // ③ fromStd：stdx 风格 handler 拿到真 HttpContext
        let r3 = client.get("http://127.0.0.1:18201/stdx")
        @Expect(r3.status, 201u16)
        @Expect(readBody(r3), "hello from stdx handler")

        // ④ 404 透传
        let r4 = client.get("http://127.0.0.1:18201/nope")
        @Expect(r4.status, 404u16)

        client.close()
        try {
            server.close()
        } catch (e: Exception) {
            ()
        }
    }
}
