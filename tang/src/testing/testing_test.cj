package tang.testing

import tang.*

/// tang.testing 自身的测试：验证「不起服务、不走网络」也能测路由
@Test
class TestingTest {
    func buildApp(): Tang {
        let app = Tang()
        app.get("/hello", { ctx => ctx.writeString("hello world") })
        app.get("/user/:id", { ctx => ctx.writeString("id=" + ctx.param("id")) })
        app.get("/query", { ctx =>
            let page = match (ctx.query("page")) {
                case Some(v) => v
                case None => "none"
            }
            ctx.writeString("page=" + page)
        })
        app.post("/echo", { ctx =>
            let body = String.fromUtf8(ctx.raw.body().toArray())
            ctx.writeString("post-" + body)
        })
        app.get("/json", { ctx =>
            ctx.responseBuilder.header("Content-Type", "application/json")
            ctx.responseBuilder.body("{\"ok\":true}")
        })
        app.get("/cookie", { ctx =>
            ctx.setSimpleCookie("session", "abc")
            ctx.writeString("set")
        })
        app.get("/boom", { ctx =>
            ctx.responseBuilder.status(500u16)
            ctx.writeString("boom")
        })
        return app
    }

    @TestCase
    func testBasicRoute(): Unit {
        let app = buildApp()
        let resp = test(app, TestRequest.get("/hello"))
        resp.assertStatus(200).assertBody("hello world")
    }

    @TestCase
    func testPathParam(): Unit {
        let app = buildApp()
        test(app, TestRequest.get("/user/42")).assertStatus(200).assertBody("id=42")
    }

    @TestCase
    func testQueryParam(): Unit {
        let app = buildApp()
        test(app, TestRequest.get("/query?page=3")).assertStatus(200).assertBody("page=3")
        test(app, TestRequest.get("/query")).assertStatus(200).assertBody("page=none")
    }

    @TestCase
    func testPostWithJsonBody(): Unit {
        let app = buildApp()
        let resp = test(app, TestRequest.post("/echo").json("{\"a\":1}"))
        resp.assertStatus(200).assertBody("post-" + "{\"a\":1}")
    }

    @TestCase
    func testHeadersAndStatus(): Unit {
        let app = buildApp()
        test(app, TestRequest.get("/json"))
            .assertStatus(200)
            .assertHeaderContains("Content-Type", "application/json")
            .assertBody("{\"ok\":true}")
        test(app, TestRequest.get("/boom")).assertStatus(500).assertBody("boom")
    }

    @TestCase
    func testSetCookieHeader(): Unit {
        let app = buildApp()
        let resp = test(app, TestRequest.get("/cookie"))
        resp.assertStatus(200)
        @Expect(resp.hasHeader("Set-Cookie"), true)
    }

    @TestCase
    func testRawRequest(): Unit {
        let app = buildApp()
        let resp = testRaw(app, "GET /hello HTTP/1.1\r\nHost: x\r\n\r\n")
        resp.assertStatus(200).assertBody("hello world")
    }

    @TestCase
    func testNotFound(): Unit {
        let app = buildApp()
        test(app, TestRequest.get("/nope")).assertStatus(404)
    }

    @TestCase
    func testMiddleware(): Unit {
        let app = Tang()
        let md: MiddlewareFunc = { next =>
            { ctx =>
                ctx.responseBuilder.header("X-Test", "mw")
                next(ctx)
            }
        }
        app.getRouter()._group.use([md])
        app.get("/mw", { ctx => ctx.writeString("ok") })
        test(app, TestRequest.get("/mw")).assertStatus(200).assertHeader("X-Test", "mw")
    }

    @TestCase
    func testCustomMethod(): Unit {
        let app = Tang()
        app.all("/any", { ctx => ctx.writeString(ctx.request.method) })
        test(app, TestRequest.of("PUT", "/any")).assertStatus(200).assertBody("PUT")
    }
}
