package tang

/// Router.mount(prefix, router) Fiber 风格子应用挂载测试
/// 1. 子路由以完整前缀生效（/api/users/:id）
/// 2. 路径参数保留（:id → "123"）
/// 3. 子 Router 中间件链保留（mount 前 wrap 的中间件原样重注册）
/// 4. 父应用自身路由不受影响
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

        let (base, server, client) = startTestServer(app)

        // ① 子路由带前缀生效 + 路径参数保留
        let resp = client.get(base + "/api/users/123")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "user-123")

        // ② 子中间件保留（mount 前 wrap 的中间件在重注册后仍生效）
        if (let Some(v) <- resp.headers.getFirst("X-Sub-MW")) {
            @Expect(v, "yes")
        } else {
            @Fail("子应用中间件 header 缺失，mount 未保留中间件链")
        }

        // ③ 父应用自身路由不受影响
        let resp2 = client.get(base + "/ping")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "pong")

        stopTestServer(server, client)
    }

    /// 子应用用 all() 注册的路由，mount 后任意方法命中
    @TestCase
    func testMountAllMethod(): Unit {
        let app = Tang()
        let subApp = Tang()
        subApp.all("/echo", { ctx => ctx.writeString("echo") })

        app.mount("/sub", subApp.getRouter())

        let (base, server, client) = startTestServer(app)

        // GET 命中
        let resp1 = client.get(base + "/sub/echo")
        @Expect(resp1.status, 200u16)
        @Expect(readRespBody(resp1), "echo")

        // POST 命中（all 语义保留）
        let resp2 = client.post(base + "/sub/echo", "x")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "echo")

        stopTestServer(server, client)
    }
}
