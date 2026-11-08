package tang.compose

import tang.{Tang, TangHttpContext, Params}
import tang.testing.{test, TestRequest}

/// ComposeRouter：按前缀把请求委派给独立子 Router
@Test
class ComposeTest {
    func buildApp(): (Tang, ComposeRouter) {
        let app = Tang()

        // 约定：compose 不剥离前缀，子 Router 按**完整路径**注册（与 Router.mount 的注册展开语义不同）
        let api = Tang()
        api.get("/api/users/:id", { ctx => ctx.writeString("api-user-" + ctx.param("id")) })
        api.get("/api/v1/ping", { ctx => ctx.writeString("api-v1-ping") })

        let mcp = Tang()
        mcp.get("/mcp/health", { ctx => ctx.writeString("mcp-health") })

        let compose = ComposeRouter()
            .mount("/api", api.getRouter())
            .mount("/api/v1", api.getRouter())
            .mount("/mcp", mcp.getRouter())
        compose.install(app)
        return (app, compose)
    }

    @TestCase
    func testPrefixDelegation(): Unit {
        let (app, _) = buildApp()
        test(app, TestRequest.get("/api/users/42"))
            .assertStatus(200)
            .assertBody("api-user-42")
        test(app, TestRequest.get("/mcp/health"))
            .assertStatus(200)
            .assertBody("mcp-health")
    }

    @TestCase
    func testLongestPrefixWins(): Unit {
        let (app, _) = buildApp()
        // /api/v1 更长，应命中它挂的那个 router（内容相同，这里验证能命中而非 404）
        test(app, TestRequest.get("/api/v1/ping"))
            .assertStatus(200)
            .assertBody("api-v1-ping")
    }

    @TestCase
    func testSegmentBoundary(): Unit {
        let (app, _) = buildApp()
        // /apix 不是 /api 的段边界匹配
        test(app, TestRequest.get("/apix/users/1")).assertStatus(404)
    }

    @TestCase
    func testFallback(): Unit {
        let app = Tang()
        let compose = ComposeRouter()
            .mount("/api", { ctx: TangHttpContext => ctx.writeString("api") })
            .setFallback({ ctx: TangHttpContext => ctx.writeString("fallback-hit") })
        compose.install(app)

        test(app, TestRequest.get("/api/x")).assertStatus(200).assertBody("api")
        test(app, TestRequest.get("/other")).assertStatus(200).assertBody("fallback-hit")
    }

    @TestCase
    func testDefaultFallbackIs404(): Unit {
        let app = Tang()
        let compose = ComposeRouter().mount("/api", { ctx: TangHttpContext => ctx.writeString("api") })
        compose.install(app)
        test(app, TestRequest.get("/nope")).assertStatus(404)
    }

    @TestCase
    func testMountWithoutLeadingSlash(): Unit {
        let app = Tang()
        let compose = ComposeRouter().mount("api", { ctx: TangHttpContext => ctx.writeString("ok") })
        compose.install(app)
        test(app, TestRequest.get("/api/x")).assertStatus(200).assertBody("ok")
    }
}
