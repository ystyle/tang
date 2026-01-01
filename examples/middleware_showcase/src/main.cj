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

main() {
    // 创建路由器，应用所有中间件
    //
    // 中间件执行顺序很重要：
    // 1. recovery 应该放在最外层，捕获所有异常
    // 2. accesslog 记录请求日志
    // 3. requestid 生成/传递请求 ID
    // 4. ratelimit 限制请求速率（防止 DDoS）
    // 5. bodylimit 限制请求体大小（防止大文件攻击）
    // 6. cors 处理跨域请求
    // 7. security 添加安全响应头
    let r = Router(
        use(
            favicon(),                            // 0. Favicon 处理（优先级高）
            recovery(),                           // 1. 异常恢复（必须放在最外层）
            accesslog(),                          // 2. 访问日志
            requestid,                            // 3. 请求 ID（用于追踪）
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
            timeout(withTimeout(2000))
        )
    )

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
            - GET  /api/user              - Protected with Basic Auth
            - GET  /api/data              - JSON response
            - GET  /api/error             - Test exception recovery
            - GET  /api/headers           - Show all request headers
            - GET  /api/delay             - Test slow response (1s)
            - GET  /api/slow              - Test timeout middleware
            - POST /api/upload            - Test body limit (max 10MB)
            - GET  /api/test-limit        - Test rate limit (100 req/min)
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

    api.get("/user", { ctx =>
        ctx.json(HashMap<String, String>([
            ("username", "admin"),
            ("role", "administrator"),
            ("status", "authenticated")
        ]))
    })

    api.get("/data", { ctx =>
        // 返回一些示例数据
        ctx.json(HashMap<String, String>([
            ("timestamp", "${DateTime.now()}"),
            ("message", "This is example JSON data")
        ]))
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
    println("Available endpoints:")
    println("  GET  /                 - Homepage")
    println("  GET  /api/info         - API information")
    println("  GET  /api/user         - Protected (user: admin, pass: secret123)")
    println("  GET  /api/data         - Protected JSON data")
    println("  GET  /api/error        - Test exception handling")
    println("  GET  /api/headers      - Show request headers")
    println("  GET  /api/delay        - Test slow response (1s)")
    println("  POST /api/upload       - Test body limit (max 10MB)")
    println("  GET  /api/test-limit   - Test rate limit (100 req/min)")
    println("  GET  /static/*         - Static files (from public/)")
    println("")
    println("Active middlewares:")
    println("  ✓ Recovery           - Exception handling")
    println("  ✓ Access Log         - Request logging")
    println("  ✓ Request ID         - Request tracking")
    println("  ✓ Rate Limit         - Rate limiting (100 req/min)")
    println("  ✓ Body Limit         - Request body size limit (10MB)")
    println("  ✓ CORS               - Cross-origin support")
    println("  ✓ Security Headers   - Security policy")
    println("  ✓ Static Files       - Static file serving")
    println("")
    println("  (Compression: Recommended to use Nginx/Proxy)")
    println("")
    println("Press Ctrl+C to stop the server")
    println("========================================")
    println("")

    server.serve()
}
