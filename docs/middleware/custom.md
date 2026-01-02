# 自定义中间件开发

## 概述

本文档介绍如何开发自定义中间件，扩展 Tang 框架的功能。

## 中间件基础

### 类型定义

```cj
// Handler 函数类型
public type HandlerFunc = (TangHttpContext) -> Unit

// 中间件函数类型
public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc
```

### 基本结构

```cj
func myMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 1. 前置处理（请求到达 Handler 之前）

            // 执行下一个中间件或 Handler
            next(ctx)

            // 2. 后置处理（Handler 返回之后）
        }
    }
}
```

## 快速开始

### 示例 1：简单的日志中间件

```cj
import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}
import std.time.DateTime

func simpleLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 记录请求开始
            let startTime = DateTime.now()
            let method = ctx.method()
            let path = ctx.path()

            println("[${startTime}] ${method} ${path}")

            // 执行下一个中间件/Handler
            next(ctx)

            // 记录请求完成
            let endTime = DateTime.now()
            let duration = endTime.toUnixTimeStamp().toMilliseconds() -
                         startTime.toUnixTimeStamp().toMilliseconds()

            println("[${endTime}] ${method} ${path} - ${duration}ms")
        }
    }
}

// 使用
let r = Router()
r.use(simpleLogger())

r.get("/", { ctx =>
    ctx.writeString("Hello, World!")
})
```

### 示例 2：认证中间件

```cj
import std.collection.HashMap

var validTokens = HashMap<String, String>()

func initTokens() {
    validTokens["secret-token-123"] = "user-1"
    validTokens["admin-token-456"] = "admin-1"
}

func authToken(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 检查 Authorization header
            let authHeader = ctx.request.headers.getFirst("Authorization")

            match (authHeader) {
                case Some(header) =>
                    if (header.startsWith("Bearer ")) {
                        let token = header[7..]  // 移除 "Bearer " 前缀

                        // 验证 token
                        if (validTokens.contains(token)) {
                            let userId = validTokens.get(token).getOrThrow()

                            // 将用户信息存储到 Context
                            ctx.kvSet("user_id", userId)
                            ctx.kvSet("token", token)

                            // 继续执行
                            next(ctx)
                        } else {
                            // Token 无效
                            ctx.status(401u16).body("Invalid token")
                        }
                    } else {
                        // Header 格式错误
                        ctx.status(401u16).body("Invalid authorization header")
                    }
                }
                case None =>
                    // 缺少 Authorization header
                    ctx.status(401u16).body("Missing authorization header")
                }
            }
        }
    }
}

// 使用
let r = Router()

// 公开路由（无需认证）
r.get("/public", { ctx =>
    ctx.writeString("Public endpoint")
})

// 受保护的路由（需要认证）
let protected = r.group("/api")
protected.use([authToken()])

protected.get("/data", { ctx =>
    let userId = ctx.kvGet<String>("user_id").getOrThrow()
    ctx.writeString("Protected data for user: ${userId}")
})
```

## 高级模式

### 模式 1：可配置的中间件

使用 Option 函数模式，使中间件可配置：

```cj
// 1. 定义配置类
public class TimedLoggerConfig {
    var enableTime: Bool = true
    var enableDate: Bool = false

    public init() {}

    public func setTime(enable: Bool) {
        this.enableTime = enable
    }

    public func setDate(enable: Bool) {
        this.enableDate = enable
    }
}

// 2. 定义 Option 类型
public type TimedLoggerOption = (TimedLoggerConfig) -> Unit

// 3. 定义 Option 函数
public func withTime(): TimedLoggerOption {
    return { config => config.setTime(true) }
}

public func withDate(): TimedLoggerOption {
    return { config => config.setDate(true) }
}

public func withoutTime(): TimedLoggerOption {
    return { config => config.setTime(false) }
}

// 4. 中间件函数
public func timedLogger(opts: Array<TimedLoggerOption>): MiddlewareFunc {
    let config = TimedLoggerConfig()

    // 应用所有选项
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx =>
            let now = DateTime.now()
            var timestamp = ""

            if (config.enableDate && config.enableTime) {
                timestamp = "${now}"
            } else if (config.enableTime) {
                timestamp = "${now.hour}:${now.minute}:${now.second}"
            } else if (config.enableDate) {
                timestamp = "${now.year}-${now.month}-${now.day}"
            }

            println("[${timestamp}] ${ctx.method()} ${ctx.path()}")

            next(ctx)
        }
    }
}

// 使用
let r = Router()

// 默认配置
r.use(timedLogger([]))

// 自定义配置
r.use(timedLogger([
    withTime(),     // 启用时间
    withDate()      // 启用日期
]))
```

### 模式 2：条件中间件

根据条件执行不同逻辑：

```cj
func conditionalMiddleware(shouldApply: (TangHttpContext) -> Bool): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (shouldApply(ctx)) {
                // 条件满足：执行逻辑
                println("Condition met for ${ctx.path()}")
                next(ctx)
            } else {
                // 条件不满足：直接跳过
                next(ctx)
            }
        }
    }
}

// 使用：只对 /api/* 路径记录日志
let r = Router()

r.use(conditionalMiddleware({ ctx =>
    ctx.path().startsWith("/api/")
}))

r.get("/api/data", { ctx => ctx.json(HashMap<String, String>([
            ("data", "value")
        ])) })
r.get("/home", { ctx => ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ])) })
```

### 模式 3：修改请求/响应

```cj
func headerModifier(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 修改请求头
            ctx.request.headers.add("X-Custom-Header", "request-value")

            // 执行下一个中间件/Handler
            next(ctx)

            // 修改响应头
            ctx.responseBuilder.header("X-Custom-Header", "response-value")
        }
    }
}
```

### 模式 4：异常处理中间件

```cj
func recoveryMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            try {
                next(ctx)
            } catch (e: Exception) {
                // 捕获异常，返回友好错误
                println("[ERROR] ${e.message}")

                ctx.status(500u16)
                ctx.json(HashMap<String, String>([
            ("error", "Internal server error"),
            ("message", "An error occurred while processing your request")
        ]))
            }
        }
    }
}
```

## 实用中间件示例

### 示例 1：请求计时器

```cj
func requestTimer(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let startTime = DateTime.now()

            next(ctx)

            let endTime = DateTime.now()
            let duration = endTime.toUnixTimeStamp().toMilliseconds() -
                         startTime.toUnixTimeStamp().toMilliseconds()

            // 将耗时存储到 Context
            ctx.kvSet("duration", duration)

            println("Request took ${duration}ms")
        }
    }
}
```

### 示例 2：请求体大小检查

```cj
func maxSizeChecker(maxBytes: Int64): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let contentLength = ctx.request.headers.getFirst("Content-Length")

            match (contentLength) {
                case Some(lengthStr) =>
                    if (let length <- Int64.parse(lengthStr)) {
                        if (length > maxBytes) {
                            ctx.status(413u16).body("Request entity too large")
                            return  // 不执行下一个中间件
                        }
                    }
                case None => ()  // 没有 Content-Length，继续执行
            }

            next(ctx)
        }
    }
}

// 使用：限制请求体最大 10MB
r.use(maxSizeChecker(10 * 1024 * 1024))
```

### 示例 3：响应压缩

```cj
import stdx.compression.*

func compression(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            next(ctx)

            // 检查客户端是否支持 gzip
            let acceptEncoding = ctx.request.headers.getFirst("Accept-Encoding")

            match (acceptEncoding) {
                case Some(encoding) =>
                    if (encoding.contains("gzip")) {
                        // 压缩响应体
                        let originalBody = ctx.responseBody
                        let compressedBody = gzipCompress(originalBody)

                        ctx.responseBuilder
                            .header("Content-Encoding", "gzip")
                            .body(compressedBody)
                    }
                }
                case None => ()
            }
        }
    }
}
```

### 示例 4：IP 白名单

```cj
import std.collection.HashSet

func ipWhitelist(allowedIPs: HashSet<String>): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let ip = ctx.ip()

            if (allowedIPs.contains(ip)) {
                // IP 在白名单中，继续执行
                next(ctx)
            } else {
                // IP 不在白名单中，拒绝访问
                ctx.status(403u16).body("Forbidden")
            }
        }
    }
}

// 使用
let whitelist = HashSet<String>()
whitelist.add("127.0.0.1")
whitelist.add("192.168.1.100")

r.use(ipWhitelist(whitelist))
```

## 中间件测试

### 单元测试示例

```cj
@Test
class MiddlewareTest {

    @TestCase
    func testAuthMiddleware() {
        // 创建测试 Context
        let ctx = createTestContext()

        // 模拟认证成功的请求
        ctx.request.headers.add("Authorization", "Bearer secret-token-123")

        // 创建认证中间件
        let auth = authToken()

        // 创建 Handler
        let handler = auth({ ctx =>
            ctx.kvGet<String>("user_id")
        })

        // 执行 Handler
        handler(ctx)

        // 验证结果
        let userId = ctx.kvGet<String>("user_id")
        @Assert(userId, Some("user-1"))
    }

    @TestCase
    func testAuthMiddlewareFail() {
        let ctx = createTestContext()

        // 模拟没有 Token 的请求
        let auth = authToken()
        let handler = auth({ ctx =>
            ctx.writeString("Should not reach here")
        })

        handler(ctx)

        // 验证返回 401
        @Assert(ctx.responseBuilder.statusCode, 401u16)
    }
}
```

## 最佳实践

### 1. 保持中间件简单

```cj
// ✅ 好：每个中间件只做一件事
r.use(logger())
r.use(auth())
r.use(rateLimit())

// ❌ 差：一个中间件做多件事
r.use(complexLoggerAuthRateLimit())
```

### 2. 中间件应该是可测试的

```cj
// ✅ 好：依赖注入，易于测试
func dbMiddleware(db: Database): MiddlewareFunc {
    return { next =>
        return { ctx =>
            ctx.kvSet("db", db)
            next(ctx)
        }
    }
}

// ❌ 差：硬编码依赖，难以测试
func dbMiddleware(): MiddlewareFunc {
    let db = GlobalDatabase  // 硬编码
    return { next => ... }
}
```

### 3. 正确处理 next(ctx) 调用

```cj
// ✅ 好：总是调用 next(ctx)，除非需要中断请求
func goodMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 前置处理
            next(ctx)  // 总是调用 next
            // 后置处理
        }
    }
}

// ⚠️ 注意：需要中断请求时可以不调用 next(ctx)
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (!isAuthenticated(ctx)) {
                ctx.status(401u16).body("Unauthorized")
                return  // 不调用 next(ctx)，中断请求
            }
            next(ctx)
        }
    }
}
```

### 4. 避免修改全局状态

```cj
// ✅ 好：使用 Context 传递数据
func userMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            ctx.kvSet("user", getCurrentUser())
            next(ctx)
        }
    }
}

// ❌ 差：修改全局变量
var currentUser: ?User = None

func userMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            currentUser = getCurrentUser()  // 不安全！并发问题
            next(ctx)
        }
    }
}
```

## 常见陷阱

### 陷阱 1：忘记调用 next(ctx)

```cj
// ❌ 错误：永远不调用 next(ctx)，请求被挂起
func brokenMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 做一些处理
            // 忘记调用 next(ctx)！
        }
    }
}

// ✅ 正确：调用 next(ctx)
func correctMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 做一些处理
            next(ctx)  // 继续执行
        }
    }
}
```

### 陷阱 2：在 next(ctx) 之后修改 Context

```cj
// ⚠️ 注意：next(ctx) 之后修改 Context 可能无效
func badMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            next(ctx)

            // Handler 可能已经发送了响应
            // 此时修改状态码或 Headers 无效
            ctx.status(200u16)  // 可能无效
        }
    }
}
```

### 陷阱 3：重复执行中间件逻辑

```cj
// ⚠️ 注意：避免重复逻辑
func counterMiddleware(): MiddlewareFunc {
    var count = 0  // ❌ 错误：多个请求共享计数器

    return { next =>
        return { ctx =>
            count++  // ❌ 线程不安全
            println("Request count: ${count}")
            next(ctx)
        }
    }
}

// ✅ 正确：使用 Context 或线程安全存储
func counterMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let count = ctx.kvGet<Int64>("request_count") ?? 0
            ctx.kvSet("request_count", count + 1)

            println("Request count: ${count + 1}")
            next(ctx)
        }
    }
}
```

## 下一步

- **[中间件系统原理](overview.md)** - 深入理解中间件系统
- **[内置中间件](builtin/)** - 23+ 内置中间件文档
- **[示例代码](../../examples/middleware_showcase/)** - 完整示例

## 相关链接

- **[源码](../../src/middleware/)** - 中间件源代码
- **[Router API](../api/router.md)** - Router API 文档
