package tang

import stdx.net.http.HttpContext

/// Router.register() 恢复测试（stdx 风格路径级注册）
/// 1. register 后 GET/POST 等全方法都能命中（all 语义，radix tree getWithFallBack）
/// 2. register 的路径支持 tang 的 :param / * 语法（同一条 radix tree）
@Test
class RegisterTest {
    @TestCase
    func testRegisterAllMethods(): Unit {
        let app = Tang()

        // stdx 风格：Router 作为 HttpRequestDistributor 的 register
        app.getRouter().register("/reg", { ctx: HttpContext =>
            ctx.responseBuilder.body("reg-ok")
        })

        let (base, server, client) = startTestServer(app)

        // GET 命中
        let resp1 = client.get(base + "/reg")
        @Expect(resp1.status, 200u16)
        @Expect(readRespBody(resp1), "reg-ok")

        // POST 命中（all 语义，stdx register 不区分 method）
        let resp2 = client.post(base + "/reg", "body")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "reg-ok")

        // DELETE 命中
        let resp3 = client.delete(base + "/reg")
        @Expect(resp3.status, 200u16)

        stopTestServer(server, client)
    }

    /// register 的路径支持 :param 语法（radix tree 模式匹配）
    @TestCase
    func testRegisterPathParam(): Unit {
        let app = Tang()
        app.getRouter().register("/users/:id", { ctx: HttpContext =>
            ctx.responseBuilder.body("user-param")
        })

        let (base, server, client) = startTestServer(app)

        // /users/123 命中 :id 模式（stdx handler 无 params 概念，验证匹配即可）
        let resp = client.get(base + "/users/123")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "user-param")

        stopTestServer(server, client)
    }

    /// register 的函数式重载：注册 (HttpContext) -> Unit
    @TestCase
    func testRegisterFuncOverload(): Unit {
        let app = Tang()
        app.getRouter().register("/func", { ctx: HttpContext =>
            ctx.responseBuilder.body("func-overload")
        })

        let (base, server, client) = startTestServer(app)

        let resp = client.get(base + "/func")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "func-overload")

        stopTestServer(server, client)
    }
}
