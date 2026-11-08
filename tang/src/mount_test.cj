package tang

/// Router.mount(prefix, router) Fiber 风格子应用挂载测试
/// 1. 子路由以完整前缀生效（/api/users/:id）
/// 2. 路径参数保留（:id → "123"）
/// 3. 子 Router 中间件链保留（mount 前 wrap 的中间件原样重注册）
/// 4. 父应用自身路由不受影响
/// 5. all() 注册的路由 mount 后任意方法命中
@Test
class MountTest {
    @TestCase
    func testMountSubRouter(): Unit {
        let app = Tang()
        let subApp = Tang()

        // 子应用：先加中间件再注册路由（Group.wrap 顺序）
        let md: MiddlewareFunc = { next =>
            {
                ctx =>
                ctx.set("X-Sub-MW", "yes")
                next(ctx)
            }
        }
        subApp.getRouter()._group.use([md])
        subApp.get("/users/:id", { ctx => ctx.writeString("user-" + ctx.param("id")) })

        // 父应用自身路由
        app.get("/ping", { ctx => ctx.writeString("pong") })

        // 挂载子应用
        app.mount("/api", subApp.getRouter())

        let (srv, sock) = startTestServer(app.getRouter(), 18191u16)

        // ① 子路由带前缀生效 + 路径参数保留
        let resp = httpGet(18191u16, "/api/users/123")
        @Expect(statusOf(resp), 200)
        @Expect(bodyOf(resp), "user-123")

        // ② 子中间件保留
        match (headerOf(resp, "X-Sub-MW")) {
            case Some(v) => @Expect(v, "yes")
            case None => @Fail("子应用中间件 header 缺失，mount 未保留中间件链")
        }

        // ③ 父应用自身路由不受影响
        let resp2 = httpGet(18191u16, "/ping")
        @Expect(statusOf(resp2), 200)
        @Expect(bodyOf(resp2), "pong")

        stopTestServer(srv, sock)
    }

    @TestCase
    func testMountAllMethod(): Unit {
        let app = Tang()
        let subApp = Tang()
        subApp.all("/echo", { ctx => ctx.writeString("echo") })

        app.mount("/sub", subApp.getRouter())

        let (srv, sock) = startTestServer(app.getRouter(), 18192u16)

        // GET 命中
        let resp1 = httpGet(18192u16, "/sub/echo")
        @Expect(statusOf(resp1), 200)
        @Expect(bodyOf(resp1), "echo")

        // POST 命中（all 语义保留）
        let resp2 = httpPost(18192u16, "/sub/echo", "x")
        @Expect(statusOf(resp2), 200)
        @Expect(bodyOf(resp2), "echo")

        stopTestServer(srv, sock)
    }
}
