package middleware_showcase

import std.collection.HashMap
import std.collection.ArrayList
import std.time.DateTime
import tang.log.LogLevel
// hex 编解码：核心零 stdx，示例内自实现（见文件末尾）
import tang.*

// 导入所有中间件
import tang.middleware.exception.newRecovery
import tang.middleware.accesslog.newAccessLog
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
import tang.middleware.rewrite.{rewrite, createRewriteFunction}
import tang.middleware.cache.{cache, withDuration,withRules, withExcludePath, CacheRule}
import tang_ext_crypto.etag.{etag, withWeak}
import tang_ext_crypto.csrf.{csrf, withSecretKey, withExpiration, withExcludePath as csrfExcludePath}
import tang_ext_crypto.session.{session, withExpiration as sessionExpiration, withCookieName, Session}
import tang_ext_crypto.encryptcookie.{encryptCookie, withKeysFromHex, withExcludeCookie}
import tang_ext_crypto.idempotency.{idempotency, withLifetime, withKeyHeader, IdempotencyStore, CachedResponse}
import tang.middleware.proxy.{proxy, withBackend, withStripPrefix, LoadBalanceStrategy}

main() {
    // 创建 Tang 应用，应用全局中间件
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
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10001u16),
        withShowBanner(),
        withShowRoutes()
    ])

    // 应用全局中间件
    // 中间件挂在根分组上（放在路由注册前，对后续路由生效）
    let root = app.group("")
    root.use(favicon())                           // 0. Favicon 处理（优先级高）
    root.use(newRecovery())                          // 1. 异常恢复（必须放在最外层）
    root.use(newAccessLog())                         // 2. 访问日志
    root.use(requestid())
    root.use(rateLimit([                           // 4. 限流（每分钟 100 个请求）
        withMaxRequests(100)
    ]))
    root.use(bodyLimit([                           // 5. 请求体限制（最大 10MB）
        withMaxSize(10 * 1024 * 1024)
    ]))
    root.use(newCors([                             // 6. CORS 跨域支持
        withAllowAllOrigins(),            //    允许所有来源
        withAllowCredentials()            //    允许携带凭证
    ]))
    root.use(security([withStrictSecurity()]))     // 7. 安全头（严格策略）
    root.use(cache([                               // 8. Cache 缓存控制
        withDuration(3600),               //     默认缓存 1 小时
        withExcludePath("/test/nocache"), //     排除手动设置 header 的路径
        withRules([
            CacheRule("/api/*", 0),       // API 不缓存
            CacheRule("/static/*", 86400) // 静态文件缓存 1 天
        ])
    ]))
    root.use(etag())                               // 9. ETag 缓存验证
    root.use(timeout(withTimeout(2000)))

    // 添加路径重写规则（在路由匹配之前执行）
    root.use(rewrite("/api/v1/(.*)", "/api/v2/$1"))
    root.use(rewrite("/old/api/(.*)", "/api/$1"))

    // ============ 测试路由 ============

    // 基础路由：返回请求 ID
app.get("/", { ctx =>
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

            New Security Middlewares (Third Batch):
            - GET  /test/csrf/token       - Get CSRF token
            - POST /test/csrf/protected   - Test CSRF validation (needs token)
            - GET  /test/csrf/public      - Public endpoint (no CSRF)
            - POST /test/session/login    - Create session
            - GET  /test/session/profile  - Read session data
            - POST /test/session/logout   - Clear session
            - GET  /test/encryptcookie/*  - Test cookie encryption
            "#
        ctx.responseBuilder.body(body)
        println("Request ID: ${ridStr}")  // 使用 ridStr 避免警告
    })


    // ============ 新中间件测试路由（待解决模块导出问题）===========
    // 健康检查
app.get("/health", healthcheck())

    // 带自定义检查的健康检查
app.get("/health/full", healthcheck([
        withLivenessCheck({ ctx => true }),
        withReadinessCheck({ ctx => true }),
        withSystemInfo()
    ]))

    // 重定向测试
app.get("/old-path", redirect(url: "/new-path", statusCode: 301))
app.get("/new-path", { ctx => ctx.responseBuilder.body("This is the new path!\n") })

    // 超时测试
app.get("/api/slow", { ctx =>
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
app.get("/test/keyauth", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This is a public endpoint"),
            ("auth", "not required"),
            ("test", "Try accessing /test/keyauth/protected with X-API-Key header")
        ]))
    })

    // 受保护端点（需要 KeyAuth）
    let protectedRoutes = app.group("/test/keyauth")
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
app.get("/test/cache", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This response is cached for 1 hour"),
            ("cache-control", "max-age=3600"),
            ("hint", "Check the Cache-Control response header")
        ]))
    })

app.get("/test/nocache", { ctx =>
        // 手动设置 Cache-Control header（中间件已排除此路径）
        ctx.responseBuilder.header("Cache-Control", "no-store, no-cache, must-revalidate")
        ctx.json(HashMap<String, String>([
            ("message", "This response is not cached"),
            ("cache-control", "no-store")
        ]))
    })

    // ========== ETag 测试 ==========
app.get("/test/etag", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This response includes ETag header"),
            ("timestamp", "${DateTime.now()}"),
            ("etag", "Check the ETag response header"),
            ("hint", "ETag is generated from URL path and query params")
        ]))
    })

    // ========== CSRF 测试 ==========
    // CSRF 中间件路由组
    let csrfRoutes = app.group("/test/csrf")
    csrfRoutes.use(csrf([
        withSecretKey("012345678901234567890123456789012"),  // 32 字节 hex 密钥
        withExpiration(3600),  // 1 小时过期
        csrfExcludePath("/test/csrf/public")  // 公开端点不需要 CSRF
    ]))

    // 调试端点：测试 kvSet/kvGet
    csrfRoutes.get("/debug", { ctx =>
        ctx.kvSet("debug_key", "debug_value")
        let value = ctx.kvGet<String>("debug_key")
        let valueStr = match (value) {
            case Some(v) => v
            case None => "none"
        }
        ctx.json(HashMap<String, String>([
            ("debug", "kvSet/kvGet test"),
            ("value", valueStr),
            ("path", ctx.path())
        ]))
    })

    // 获取 CSRF token（GET 请求会生成 token）
    csrfRoutes.get("/token", { ctx =>
        let tokenStr = match (ctx.csrfToken()) {
            case Some(t) => t
            case None => "no-token"
        }
        ctx.json(HashMap<String, String>([
            ("message", "CSRF token generated"),
            ("token", tokenStr),
            ("header", "X-CSRF-Token"),
            ("hint", "Include this token in X-CSRF-Token header for POST/PUT/DELETE requests")
        ]))
    })

    // 测试 CSRF 验证（POST 请求需要 token）
    csrfRoutes.post("/protected", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "CSRF validation successful"),
            ("status", "authenticated"),
            ("info", "Your request included a valid CSRF token")
        ]))
    })

    // 公开端点（不需要 CSRF token）
app.get("/test/csrf/public", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This is a public endpoint"),
            ("csrf", "not required"),
            ("path", "excluded from CSRF protection")
        ]))
    })

    // 测试：直接在路由上应用 CSRF 中间件
    let testCSRF = app.group("/test/csrf2")
    testCSRF.use(csrf([withSecretKey("test123456789012345678901234567890")]))
    testCSRF.get("/direct", { ctx =>
        let tokenStr = match (ctx.csrfToken()) {
            case Some(t) => t
            case None => "no-token"
        }
        ctx.json(HashMap<String, String>([
            ("test", "direct middleware application"),
            ("token", tokenStr)
        ]))
    })

    // ========== Session 测试 ==========
    // Session 中间件路由组
    let sessionRoutes = app.group("/test/session")
    sessionRoutes.use(session([
        sessionExpiration(3600),  // 1 小时过期
        withCookieName("test_session")
    ]))

    // 设置 session
    sessionRoutes.post("/login", { ctx =>
        let sess = ctx.kvGet<Session>("session")
        if (let Some(s) <- sess) {
            s.data.set("userId", "12345")
            s.data.set("username", "testuser")
            s.data.set("loginTime", "${DateTime.now()}")
        }
        ctx.json(HashMap<String, String>(
            ("message", "Session created successfully"),
            ("action", "login"),
            ("hint", "Session data stored: userId, username, loginTime")
        ))
    })

    // 读取 session
    sessionRoutes.get("/profile", { ctx =>
        let sess = ctx.kvGet<Session>("session")
        if (let Some(s) <- sess) {
            let userId = s.data.get("userId") ?? "none"
            let username = s.data.get("username") ?? "none"
            let loginTime = s.data.get("loginTime") ?? "none"

            ctx.json(HashMap<String, String>([
                ("message", "Session retrieved successfully"),
                ("userId", userId),
                ("username", username),
                ("loginTime", loginTime),
                ("sessionId", s.id)
            ]))
        } else {
            ctx.json(HashMap<String, String>([
                ("message", "No session found"),
                ("hint", "POST /test/session/login first")
            ]))
        }
    })

    // 清除 session
    sessionRoutes.post("/logout", { ctx =>
        let sess = ctx.kvGet<Session>("session")
        if (let Some(s) <- sess) {
            s.data.clear()
        }
        ctx.json(HashMap<String, String>([
            ("message", "Session cleared successfully"),
            ("action", "logout")
        ]))
    })

    // ========== EncryptCookie 测试 ==========
app.get("/test/encryptcookie/set", { ctx =>
        // 由于当前框架限制，这里只展示说明
        // 实际使用时需要在应用路由前添加 encryptCookie 中间件
        ctx.json(HashMap<String, String>([
            ("message", "EncryptCookie middleware demonstration"),
            ("encryption", "SM4-CBC + HMAC-SHA256"),
            ("format", "base64(iv+encrypted).hex(signature)"),
            ("usage", "Add encryptCookie middleware to your router"),
            ("hint", "See middleware/encryptcookie/encryptcookie.cj for usage examples")
        ]))
    })

app.get("/test/encryptcookie/get", { ctx =>
        // 读取 cookie（会自动解密）
        let testCookie = ctx.cookie("test_cookie")
        let cookieValue = match (testCookie) {
            case Some(v) => v
            case None => "not-set"
        }

        ctx.json(HashMap<String, String>([
            ("message", "Cookie retrieved"),
            ("test_cookie", cookieValue),
            ("note", "EncryptCookie middleware auto-decrypts on read")
        ]))
    })

    // ========== Idempotency 测试 ==========
    let idempotencyRoutes = app.group("/test/idempotency")
    idempotencyRoutes.use(idempotency([
        withKeyHeader("X-Idempotency-Key"),
        withLifetime(3600)  // 1 小时
    ]))

    // 模拟支付接口（需要幂等性保护）
    idempotencyRoutes.post("/payment", { ctx =>
        // 检查是否已经处理过（中间件已经检查过缓存，这里直接处理）
        let keyOpt = ctx.kvGet<String>("idempotency_key")
        let storeOpt = ctx.kvGet<IdempotencyStore>("idempotency_store")

        // 模拟支付处理
        let paymentId = "PAY-${DateTime.now().toUnixTimeStamp().toSeconds()}"
        let amount = "100.00"

        // 构建响应
        let responseBody = """
        {"message":"Payment successful","paymentId":"${paymentId}","amount":"${amount}","status":"completed"}
        """

        // 返回响应
        ctx.responseBuilder.status(200u16)
        ctx.responseBuilder.body(responseBody)

        // 保存到缓存（首次请求）
        if (let Some(key) <- keyOpt && let Some(store) <- storeOpt) {
            let cachedResponse = CachedResponse(200u16, responseBody)
            store.set(key, cachedResponse)
        }
    })

    // 模拟订单创建（需要幂等性保护）
    idempotencyRoutes.post("/order", { ctx =>
        let keyOpt = ctx.kvGet<String>("idempotency_key")
        let storeOpt = ctx.kvGet<IdempotencyStore>("idempotency_store")

        let orderId = "ORD-${DateTime.now().toUnixTimeStamp().toSeconds()}"
        let items = "item1,item2,item3"

        let responseBody = """
        {"message":"Order created","orderId":"${orderId}","items":"${items}","status":"pending","hint":"Send same request again with same key to test idempotency"}
        """

        ctx.responseBuilder.status(200u16)
        ctx.responseBuilder.body(responseBody)

        // 保存到缓存（首次请求）
        if (let Some(key) <- keyOpt && let Some(store) <- storeOpt) {
            let cachedResponse = CachedResponse(200u16, responseBody)
            store.set(key, cachedResponse)
        }
    })

    // 不需要幂等性的接口（GET 请求，自动排除）
    idempotencyRoutes.get("/info", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "This endpoint does not require idempotency key"),
            ("reason", "GET requests are automatically excluded"),
            ("usage", "POST endpoints require X-Idempotency-Key header")
        ]))
    })

    // ============ Proxy 中间件测试 ============
    // Proxy 演示：将 /test/proxy/* 转发到本地 API
    // 注意：需要在 proxyRoutes 下注册一个 catch-all 路由
    let proxyRoutes = app.group("/test/proxy")

    // 应用 Proxy 中间件（代理到本地 API）
    proxyRoutes.use(proxy([
        withBackend("http://localhost:10001"),  // 代理到本地服务器
        withStripPrefix("/test/proxy")           // 移除 /test/proxy 前缀
    ]))

    // 注册 catch-all 路由，让 Proxy 中间件处理所有请求
    proxyRoutes.all("/*", { ctx =>
        // 这个 handler 实际上不会被执行到
        // 因为 Proxy 中间件会转发请求并返回响应
        ctx.responseBuilder.status(404u16).body("Proxy: No route configured")
    })

    // Favicon 测试 - 直接路由处理器
app.get("/favicon.ico", { ctx =>
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
app.get("/api/info", { ctx =>
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
    let api = app.group("/api")

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
        // 用 StringBuilder（引用类型、let 绑定）收集：仓颉限制
        // 「捕获可变变量的 lambda 必须直接调用」，不能往 var 数组里塞
        let sb = StringBuilder()
        ctx.request.headers.forEach({ name, value =>
            sb.append(name + ": " + value + "\n")
        })
        ctx.responseBuilder.body(sb.toString())
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
app.get("/static/*", staticFiles("public", opts: [withPrefix("/static")]))
app.get("/static", staticFiles("public", opts: [withPrefix("/static")]))

    // 为所有路径添加 OPTIONS 处理器，让 CORS 中间件能够处理预检请求
    // 注意：需要为每个路径前缀注册 OPTIONS 路由，因为 radix tree 的 /* 只匹配单层路径
app.options("/*", { ctx =>
        ctx.responseBuilder.body("")
    })
    api.options("/*", { ctx =>
        ctx.responseBuilder.body("")
    })

    // ============ 启动服务器 ============

    println("========================================")
    println("  Tang Middleware Showcase Server")
    println("========================================")
    println("")
    println("Server running at: http://localhost:10001")
    println("")
    println("🔐 Middleware Testing Guide:")
    println("")
    println("[KeyAuth Test]")
    println("  curl http://localhost:10001/test/keyauth")
    println("  curl -H 'X-API-Key: test-secret-key-12345' http://localhost:10001/test/keyauth/protected")
    println("")
    println("[Rewrite Test]")
    println("  curl http://localhost:10001/old/api/data")
    println("  curl http://localhost:10001/api/v1/users")
    println("")
    println("[Cache Test]")
    println("  curl -I http://localhost:10001/test/cache")
    println("  curl -I http://localhost:10001/test/nocache")
    println("")
    println("[ETag Test]")
    println("  curl -I http://localhost:10001/test/etag")
    println("")
    println("========== New Security Middlewares (Third Batch) ==========")
    println("")
    println("[CSRF Test]")
    println("  # 1. Get CSRF token")
    println("  curl http://localhost:10001/test/csrf/token")
    println("")
    println("  # 2. Use token in protected endpoint")
    println("  curl -H 'X-CSRF-Token: <token>' http://localhost:10001/test/csrf/protected")
    println("")
    println("  # 3. Public endpoint (no token needed)")
    println("  curl http://localhost:10001/test/csrf/public")
    println("")
    println("[Session Test]")
    println("  # 1. Create session")
    println("  curl -c cookies.txt http://localhost:10001/test/session/login -X POST")
    println("")
    println("  # 2. Read session")
    println("  curl -b cookies.txt http://localhost:10001/test/session/profile")
    println("")
    println("  # 3. Clear session")
    println("  curl -b cookies.txt http://localhost:10001/test/session/logout -X POST")
    println("")
    println("[EncryptCookie Test]")
    println("  # Note: Due to framework limitations, this is a demonstration endpoint")
    println("  curl http://localhost:10001/test/encryptcookie/set")
    println("")
    println("========== New Advanced Middlewares (Fourth Batch) ==========")
    println("")
    println("[Idempotency Test]")
    println("  # 1. GET request (no idempotency key needed)")
    println("  curl http://localhost:10001/test/idempotency/info")
    println("")
    println("  # 2. First payment request (with idempotency key)")
    println("  curl -H 'X-Idempotency-Key: unique-key-123' -X POST http://localhost:10001/test/idempotency/payment")
    println("")
    println("  # 3. Second request with same key (should return cached response)")
    println("  curl -H 'X-Idempotency-Key: unique-key-123' -X POST http://localhost:10001/test/idempotency/payment")
    println("")
    println("  # 4. Order creation test")
    println("  curl -H 'X-Idempotency-Key: order-key-456' -X POST http://localhost:10001/test/idempotency/order")
    println("")
    println("[Proxy Test]")
    println("  # 1. Proxy GET request (forwards to /api/info)")
    println("  curl http://localhost:10001/test/proxy/api/info")
    println("")
    println("  # 2. Proxy POST request")
    println("  curl -X POST -H 'Content-Type: application/json' -d '{\"test\":\"data\"}' http://localhost:10001/test/proxy/api/test-cache")
    println("")
    println("  # 3. WebSocket Upgrade test (should return 426 error)")
    println("  curl -H 'Upgrade: websocket' http://localhost:10001/test/proxy/api/info")
    println("")
    println("Press Ctrl+C to stop the server")
    println("========================================")
    println("")

    // 启动应用
    app.listen()
}


// ── hex 编解码（示例内自实现：核心与扩展成员都不依赖 stdx.encoding.hex）──

func toHexString(bytes: Array<Byte>): String {
    let digits = "0123456789abcdef"
    var sb = StringBuilder()
    for (b in bytes) {
        let v = Int64(b)
        sb.append(String.fromUtf8([digits.toArray()[Int64((v >> 4) & 0xF)]]))
        sb.append(String.fromUtf8([digits.toArray()[v & 0xF]]))
    }
    return sb.toString()
}

func fromHexString(s: String): Array<Byte> {
    let src = s.toArray()
    let out = Array<Byte>(src.size / 2, repeat: 0)
    var i: Int64 = 0
    while (i + 1 < src.size) {
        out[i / 2] = UInt8(hexVal(src[i]) * 16 + hexVal(src[i + 1]))
        i += 2
    }
    return out
}

func hexVal(c: Byte): Int64 {
    if (c >= 48 && c <= 57) {
        return Int64(c - 48)
    }
    if (c >= 97 && c <= 102) {
        return Int64(c - 97) + 10
    }
    if (c >= 65 && c <= 70) {
        return Int64(c - 65) + 10
    }
    return 0
}
