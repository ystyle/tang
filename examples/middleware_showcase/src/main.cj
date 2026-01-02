package middleware_showcase

import std.collection.HashMap
import std.collection.ArrayList
import std.time.DateTime
import stdx.log.LogLevel
import stdx.net.http.ServerBuilder
import tang.*

// 导入所有中间件
import tang.middleware.exception.recovery
import tang.middleware.accesslog.accesslog
import tang.middleware.requestid.requestid
import tang.middleware.cors.{newCors, withAllowAllOrigins, withAllowCredentials}
import tang.middleware.security.{security, withStrictSecurity}
import tang.middleware.staticfile.{staticFiles, withPrefix}
import tang.middleware.bodylimit.{bodyLimit, withMaxSize}
import tang.middleware.ratelimit.{rateLimit, withMaxRequests}

import tang.middleware.healthcheck.{healthcheck, withLivenessCheck, withReadinessCheck, withSystemInfo}
import tang.middleware.redirect.{redirect, redirectMiddleware}
import tang.middleware.favicon.favicon
import tang.middleware.timeout.{timeout, withTimeout, isTimeout}
import tang.middleware.keyauth.{keyAuth, withKey, withLookup}
import tang.middleware.rewrite.{createRewriteFunction}
import tang.middleware.cache.{cache, withDuration,withRules, withExcludePath, CacheRule}
import tang.middleware.etag.{etag, withWeak}

main() {
    // 创建路由器，应用全局中间件
    //
    // 中间件执行顺序很重要：
    // 1. recovery 应该放在最外层，捕获所有异常
    // 2. accesslog 记录请求日志
    // 3. requestid 生成/传递请求 ID
    // 4. ratelimit 限制请求速率（防止 DDoS）
    // 5. bodylimit 限制请求体大小（防止大文件攻击）
    // 6. cors 处理跨域请求
    // 7. security 添加安全响应头
    // 8. cache 缓存控制
    // 9. etag 缓存验证
    // 注意：KeyAuth 不在全局应用，在特定路由上测试
    let r = Router(
        use([
            favicon(),                            // 0. Favicon 处理（优先级高）
            recovery(),                           // 1. 异常恢复（必须放在最外层）
            accesslog(),                          // 2. 访问日志
            requestid(),
            rateLimit([                           // 4. 限流（每分钟 100 个请求）
                withMaxRequests(100)
            ]),
            bodyLimit([                           // 5. 请求体限制（最大 10MB）
                withMaxSize(10 * 1024 * 1024)
            ]),
            newCors([                             // 6. CORS 跨域支持
                withAllowAllOrigins(),            //    允许所有来源
                withAllowCredentials()            //    允许携带凭证
            ]),
            security([withStrictSecurity()]),     // 7. 安全头（严格策略）
            cache([                               // 8. Cache 缓存控制
                withDuration(3600),               //     默认缓存 1 小时
                withExcludePath("/test/nocache"), //     排除手动设置 header 的路径
                withRules([
                    CacheRule("/api/*", 0),       // API 不缓存
                    CacheRule("/static/*", 86400) // 静态文件缓存 1 天
                ])
            ]),
            etag(),                               // 9. ETag 缓存验证
            timeout(withTimeout(2000))
        ])
    )

    // 添加路径重写规则（在路由匹配之前执行）
    r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))
    r.addRewriteRule(createRewriteFunction("/old/api/(.*)", "/api/$1"))

    // ============ 测试路由 ============

    // 基础路由：返回请求 ID
    r.get("/", { ctx =>
        let rid = ctx.requestid()
        let ridStr = match (rid) {
            case Some(v) => v
            case None => "none"
        }
        let body = #"Welcome to Tang Middleware Showcase!
            Request ID: ${ridStr}
            Available endpoints:
            - GET  /                      - Homepage
            - GET  /health                - Basic health check
            - GET  /health/full           - Full health check with system info
            - GET  /old-path              - Test redirect (301 -> /new-path)
            - GET  /new-path              - Redirect target
            - GET  /api/info              - API info
            - GET  /api/user              - Protected with KeyAuth (X-API-Key header)
            - GET  /api/data              - JSON response
            - GET  /api/error             - Test exception recovery
            - GET  /api/headers           - Show all request headers
            - GET  /api/delay             - Test slow response (1s)
            - GET  /api/slow              - Test timeout middleware
            - POST /api/upload            - Test body limit (max 10MB)
            - GET  /api/test-limit        - Test rate limit (100 req/min)
            - GET  /api/test-cache        - Test Cache & ETag middleware
            - GET  /old/api/info          - Test Rewrite middleware -> /api/info
            - GET  /static/*              - Static files (real files from public/)
            "#
        ctx.responseBuilder.body(body)
        println("Request ID: ${ridStr}")  // 使用 ridStr 避免警告
    })


    // ============ 新中间件测试路由（待解决模块导出问题）===========
    // 健康检查
    r.get("/health", healthcheck())

    // 带自定义检查的健康检查
    r.get("/health/full", healthcheck([
        withLivenessCheck({ ctx => true }),
        withReadinessCheck({ ctx => true }),
        withSystemInfo()
    ]))

    // 重定向测试
    r.get("/old-path", redirect(url: "/new-path", statusCode: 301))
    r.get("/new-path", { ctx => ctx.responseBuilder.body("This is the new path!\n") })

    // 超时测试
    r.get("/api/slow", { ctx =>
        // 模拟慢操作
        sleep(Duration.second * 1)

        // 检查是否超时
        if (isTimeout(ctx)) {
            ctx.responseBuilder.status(504).body("Request timeout\n")
            return
        }

        ctx.responseBuilder.body("Slow operation completed\n")
    })

    // ============ 新中间件测试路由 ============

    // ========== KeyAuth 测试 ==========
    // 公开端点（不需要认证）
    r.get("/test/keyauth", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This is a public endpoint"),
            ("auth", "not required"),
            ("test", "Try accessing /test/keyauth/protected with X-API-Key header")
        ]))
    })

    // 受保护端点（需要 KeyAuth）
    let protectedRoutes = r.group("/test/keyauth")
    protectedRoutes.use(
        keyAuth([
            withKey("test-secret-key-12345"),
            withLookup("header:X-API-Key")
        ])
    )

    protectedRoutes.get("/protected", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "You are authenticated!"),
            ("auth", "success"),
            ("info", "KeyAuth middleware is working correctly")
        ]))
    })

    // ========== Rewrite 测试 ==========
    // Rewrite 中间件已在全局中间件中配置（第 61-62 行）
    // 这里只需要注册目标路由即可

    // ========== Cache 测试 ==========
    r.get("/test/cache", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This response is cached for 1 hour"),
            ("cache-control", "max-age=3600"),
            ("hint", "Check the Cache-Control response header")
        ]))
    })

    r.get("/test/nocache", { ctx =>
        // 手动设置 Cache-Control header（中间件已排除此路径）
        ctx.responseBuilder.header("Cache-Control", "no-store, no-cache, must-revalidate")
        ctx.json(HashMap<String, String>([
            ("message", "This response is not cached"),
            ("cache-control", "no-store")
        ]))
    })

    // ========== ETag 测试 ==========
    r.get("/test/etag", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This response includes ETag header"),
            ("timestamp", "${DateTime.now()}"),
            ("etag", "Check the ETag response header"),
            ("hint", "ETag is generated from URL path and query params")
        ]))
    })

    // Favicon 测试 - 直接路由处理器
    r.get("/favicon.ico", { ctx =>
        // 1x1 透明 GIF
        let gifData = Array<UInt8>(35, { i =>
            [0x47u8, 0x49u8, 0x46u8, 0x38u8, 0x39u8, 0x61u8, 0x01u8, 0x00u8,
             0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x21u8, 0xF9u8, 0x04u8,
             0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x2Cu8, 0x00u8, 0x00u8,
             0x00u8, 0x00u8, 0x01u8, 0x00u8, 0x01u8, 0x00u8, 0x00u8, 0x02u8,
             0x02u8, 0x04u8, 0x01u8, 0x00u8, 0x3Bu8][i]
        })
        ctx.responseBuilder.status(200u16)
        ctx.responseBuilder.header("Content-Type", "image/x-icon")
        ctx.responseBuilder.header("Cache-Control", "public, max-age=86400")
        ctx.responseBuilder.body(gifData)
    })

    // ============ 原有 API 路由 ============

    // API 信息路由
    r.get("/api/info", { ctx =>
        let rid = ctx.requestid()
        let ridStr = rid ?? "unknown"
        let clientIP = ctx.request.headers.getFirst("X-Real-IP") ?? ctx.request.headers.getFirst("X-Forwarded-For") ?? ctx.request.remoteAddr

        ctx.json(HashMap<String, String>([
            ("framework", "Tang"),
            ("language", "Cangjie"),
            ("version", "0.1.0"),
            ("requestId", ridStr),
            ("clientIP", clientIP)
        ]))
    })

    // 创建 API 分组
    let api = r.group("/api")

    // Rewrite 测试路由：/api/v1/users -> /api/v2/users
    api.get("/v2/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("users", "[]"),
            ("note", "This endpoint can be accessed via /api/v1/users (rewritten to /api/v2/users)")
        ]))
    })

    // Rewrite 测试路由：/old/api/data -> /api/data
    api.get("/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "URL was rewritten from /old/api/data to /api/data"),
            ("original", "/old/api/data"),
            ("current", "/api/data"),
            ("middleware", "Rewrite is working!")
        ]))
    })

    api.get("/test-cache", { ctx =>
        // 测试 Cache 和 ETag 中间件
        let data = HashMap<String, String>([
            ("timestamp", "${DateTime.now()}"),
            ("message", "This response should have Cache-Control and ETag headers"),
            ("cache", "Check the Cache-Control header"),
            ("etag", "Check the ETag header")
        ])
        ctx.json(data)
    })

    // 测试异常恢复
    api.get("/error", { _ =>
        throw Exception("This is a test exception to demonstrate recovery middleware")
    })

    // 显示所有请求头
    api.get("/headers", { ctx =>
        var headersInfo = ArrayList<String>()
        for ((name, values) in ctx.request.headers) {
            for (value in values) {
                headersInfo.add("${name}: ${value}")
            }
        }
        ctx.responseBuilder.body(String.join(headersInfo.toArray(), delimiter: "\n"))
    })

    // 测试慢响应（用于测试 accesslog 的延迟记录）
    api.get("/delay", { ctx =>
        // 模拟一些处理时间
        sleep(Duration.second) // 睡眠 1 秒
        ctx.responseBuilder.body("This request took about 1 second to process\n")
    })

    // 测试请求体限制
    api.post("/upload", { ctx =>
        ctx.responseBuilder.body("Upload endpoint (max 10MB)\n")
    })

    // 测试限流
    api.get("/test-limit", { ctx =>
        ctx.responseBuilder.body("If you see this, rate limit is working (100 req/min)\n")
    })

    // 静态文件服务（从 public 目录提供文件）
    // 使用绝对路径避免工作目录问题
    r.get("/static/*", staticFiles("/home/ystyle/Code/CangJie/online/tang/examples/middleware_showcase/public", [withPrefix("/static")]))
    r.get("/static", staticFiles("/home/ystyle/Code/CangJie/online/tang/examples/middleware_showcase/public", [withPrefix("/static")]))

    // 为所有路径添加 OPTIONS 处理器，让 CORS 中间件能够处理预检请求
    // 注意：需要为每个路径前缀注册 OPTIONS 路由，因为 radix tree 的 /* 只匹配单层路径
    r.options("/*", { ctx =>
        ctx.responseBuilder.body("")
    })
    api.options("/*", { ctx =>
        ctx.responseBuilder.body("")
    })

    // ============ 启动服务器 ============

    let server = ServerBuilder()
        .distributor(r)
        .addr("127.0.0.1")
        .port(10001)
        .build()

    // 设置日志级别为 INFO，以便看到中间件日志
    server.logger.level = LogLevel.INFO

    println("========================================")
    println("  Tang Middleware Showcase Server")
    println("========================================")
    println("")
    println("Server running at: http://localhost:${server.port}")
    println("")
    println("🔐 Middleware Testing Guide:")
    println("")
    println("[KeyAuth Test]")
    println("  curl http://localhost:${server.port}/test/keyauth")
    println("  curl -H 'X-API-Key: test-secret-key-12345' http://localhost:${server.port}/test/keyauth/protected")
    println("")
    println("[Rewrite Test]")
    println("  curl http://localhost:${server.port}/old/api/data")
    println("  curl http://localhost:${server.port}/api/v1/users")
    println("")
    println("[Cache Test]")
    println("  curl -I http://localhost:${server.port}/test/cache")
    println("  curl -I http://localhost:${server.port}/test/nocache")
    println("")
    println("[ETag Test]")
    println("  curl -I http://localhost:${server.port}/test/etag")
    println("")
    println("Press Ctrl+C to stop the server")
    println("========================================")
    println("")

    server.serve()
}
