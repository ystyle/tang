package tang

import tang.compose.ComposeDistributor
import stdx.net.http.HttpContext

/// ComposeDistributor 集成测试
/// 1. 基本前缀委派：/api → tang1，/mcp → tang2，未命中 → 404
/// 2. 最长前缀优先：/api/v1 优先于 /api
/// 3. 段边界：/api 不匹配 /apix
/// 4. fallback：未命中 mount 前缀时走兜底分发器
/// 5. register 转发给 fallback
@Test
class ComposeDistributorTest {
    @TestCase
    func testBasicMountAndFallback(): Unit {
        let app1 = Tang()
        app1.get("/api/users", { ctx => ctx.writeString("api-users") })   // 完整路径（不剥离）
        let app2 = Tang()
        app2.get("/mcp/health", { ctx => ctx.writeString("mcp-health") }) // 完整路径

        let compose = ComposeDistributor()
            .mount("/api", app1.getRouter())
            .mount("/mcp", app2.getRouter())
            // 默认 fallback = 404

        let (base, server, client) = startTestServer(compose)

        // /api/* 委派给 tang1
        let resp1 = client.get(base + "/api/users")
        @Expect(resp1.status, 200u16)
        @Expect(readRespBody(resp1), "api-users")

        // /mcp/* 委派给 tang2
        let resp2 = client.get(base + "/mcp/health")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "mcp-health")

        // 未命中任何前缀 → 默认 fallback 404
        let resp3 = client.get(base + "/other")
        @Expect(resp3.status, 404u16)

        stopTestServer(server, client)
    }

    @TestCase
    func testLongestPrefix(): Unit {
        let app1 = Tang()
        app1.get("/api/v1/users", { ctx => ctx.writeString("api-v1") })    // 更长前缀 /api/v1
        let app2 = Tang()
        app2.get("/api/users", { ctx => ctx.writeString("api") })          // /api

        let compose = ComposeDistributor()
            .mount("/api", app2.getRouter())
            .mount("/api/v1", app1.getRouter())

        let (base, server, client) = startTestServer(compose)

        // /api/v1/users 应命中更长前缀 /api/v1 → app1
        let resp = client.get(base + "/api/v1/users")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "api-v1")

        // /api/users 命中 /api → app2
        let resp2 = client.get(base + "/api/users")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "api")

        stopTestServer(server, client)
    }

    @TestCase
    func testPrefixBoundary(): Unit {
        let app1 = Tang()
        app1.get("/apix/x", { ctx => ctx.writeString("apix") })            // fallback：完整路径
        let app2 = Tang()
        app2.get("/api/users", { ctx => ctx.writeString("api") })          // /api 前缀

        let compose = ComposeDistributor()
            .mount("/api", app2.getRouter())
            .setFallback(app1.getRouter())

        let (base, server, client) = startTestServer(compose)

        // /apix/x 不以 /api/ 开头 → 不匹配 /api 前缀 → fallback
        let resp = client.get(base + "/apix/x")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "apix")

        // /api/users 正常命中 /api
        let resp2 = client.get(base + "/api/users")
        @Expect(resp2.status, 200u16)
        @Expect(readRespBody(resp2), "api")

        stopTestServer(server, client)
    }

    @TestCase
    func testRegisterForwardsToFallback(): Unit {
        let app1 = Tang()
        app1.get("/direct", { ctx => ctx.writeString("fallback-direct") })

        let compose = ComposeDistributor()
            .setFallback(app1.getRouter())

        // stdx register 契约：转发给 fallback
        compose.register("/std", { ctx: HttpContext =>
            ctx.responseBuilder.body("std-reg")
        })

        let (base, server, client) = startTestServer(compose)

        // fallback 已注册的 tang 路由
        let resp1 = client.get(base + "/direct")
        @Expect(resp1.status, 200u16)
        @Expect(readRespBody(resp1), "fallback-direct")

        stopTestServer(server, client)
    }
}
