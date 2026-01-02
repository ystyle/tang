# 中间件系统概述

## 概述

Tang 的中间件系统提供了一种强大而灵活的方式来拦截和处理 HTTP 请求和响应。中间件可以用于日志记录、身份验证、缓存、压缩等各种场景。

## 什么是中间件？

中间件是一个函数，它接收一个 `HandlerFunc` 并返回一个新的 `HandlerFunc`。这种设计允许中间件在请求到达最终处理器之前或之后执行代码。

### 基本概念

```cj
// 中间件类型定义
public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

// Handler 类型
public type HandlerFunc = (TangHttpContext) -> Unit
```

### 工作原理

```
请求 → 中间件 1 → 中间件 2 → ... → Handler → ... → 中间件 2 → 中间件 1 → 响应
```

每个中间件可以：
1. **在请求到达 Handler 之前**执行代码（如身份验证、日志记录）
2. **调用下一个中间件或 Handler**（通过 `next(ctx)`）
3. **在 Handler 返回之后**执行代码（如设置响应头、记录响应时间）

## 中间件执行流程

### 请求生命周期

```
1. HTTP Request
   ↓
2. Router 接收请求
   ↓
3. 中间件链开始执行
   ↓
4. Middleware 1
   ├── [前置处理]
   │   // 例如：记录请求开始时间
   │   let startTime = DateTime.now()
   │
   │   // 调用下一个中间件
   │   next(ctx)
   │
   │   // [后置处理]
   │   // 例如：记录响应时间
   │   let duration = DateTime.now() - startTime
   │
   ↓
5. Middleware 2
   ├── [前置处理]
   │   // 例如：验证身份
   │   if (!isAuthenticated(ctx)) {
   │       ctx.status(401u16).body("Unauthorized")
   │       return  // 不调用 next(ctx)，中断请求
   │   }
   │
   │   next(ctx)  // 继续执行
   │
   │   // [后置处理]
   │
   ↓
6. ... 更多中间件
   ↓
7. Handler（业务逻辑）
   ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
   ↓
8. 返回经过中间件链
   ↓
9. HTTP Response
```

### 中间件链示例

```cj
let r = Router()

// 添加多个中间件
r.use(recovery())  // 1. 异常恢复
r.use(logger())    // 2. 日志记录
r.use(cors())      // 3. CORS 处理

r.get("/api/data", { ctx =>
    // Handler
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**执行顺序**：
```
请求 → Recovery → Logger → CORS → Handler → CORS → Logger → Recovery → 响应
```

## 中间件类型

### 1. 全局中间件

应用于所有路由：

```cj
let r = Router()

// 全局中间件：影响所有路由
r.use(logger())
r.use(cors())

r.get("/api/users", handler)
r.post("/api/users", handler)
```

### 2. 路由组中间件

应用于特定路由组：

```cj
let r = Router()

let api = r.group("/api")

// 只影响 /api/* 路由
api.use(rateLimit())
api.use(auth())

api.get("/users", handler)
api.post("/users", handler)
```

### 3. 单个路由中间件

应用于特定路由：

```cj
// 只影响 /admin 路由
r.get("/admin", auth(), adminHandler)

// 只影响 /api/data 路由
r.post("/api/data", [validate(), rateLimit()], handler)
```

## 中间件设计模式

### 1. Before/After 模式

```cj
func loggingMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // Before: 记录请求信息
            let startTime = DateTime.now()
            let method = ctx.method()
            let path = ctx.path()

            println("[${startTime}] ${method} ${path}")

            // 执行下一个中间件/Handler
            next(ctx)

            // After: 记录响应时间
            let endTime = DateTime.now()
            let duration = endTime - startTime
            println("[${endTime}] ${method} ${path} - ${duration}ms")
        }
    }
}
```

### 2. 中断模式

```cj
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 检查认证
            if (!isAuthenticated(ctx)) {
                // 认证失败：返回错误，不调用 next(ctx)
                ctx.status(401u16).body("Unauthorized")
                return  // 中断请求
            }

            // 认证成功：继续执行
            next(ctx)
        }
    }
}
```

### 3. 修改 Context 模式

```cj
func userMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 从 Cookie 获取用户信息
            let userId = ctx.cookie("user_id")

            match (userId) {
                case Some(id) =>
                    // 将用户信息存储到 Context
                    ctx.kvSet("user_id", id)
                    ctx.kvSet("authenticated", "true")
                case None => ()
            }

            // 继续执行
            next(ctx)
        }
    }
}
```

## 内置中间件分类

Tang 提供了 23+ 内置中间件，按功能分类：

### 监控与检查
- **HealthCheck** - 健康检查（Liveness/Readiness）

### 路由与请求控制
- **Redirect** - URL 重定向（301/302）
- **Rewrite** - URL 重写（服务器端）
- **Favicon** - Favicon 处理
- **Timeout** - 请求超时控制
- **Proxy** - 反向代理

### 安全类
- **Security** - 安全响应头（XSS、Clickjacking 等）
- **CORS** - 跨域资源共享
- **BasicAuth** - HTTP 基本认证
- **CSRF** - CSRF 保护
- **KeyAuth** - API 密钥认证

### 日志与监控
- **Log** - 请求日志（简化版）
- **AccessLog** - 访问日志（详细版）
- **RequestID** - 请求 ID 生成

### 异常处理
- **Recovery** - 异常恢复和错误处理

### 流量控制
- **RateLimit** - 请求速率限制
- **BodyLimit** - 请求体大小限制

### 静态文件
- **StaticFile** - 静态文件服务

### 会话与 Cookie
- **Session** - 会话管理
- **EncryptCookie** - Cookie 加密

### 缓存与优化
- **Cache** - Cache-Control 头
- **ETag** - ETag 缓存验证

### 高级功能
- **Idempotency** - 幂等性控制（防止重复提交）

## 中间件最佳实践

### 1. 中间件顺序很重要

```cj
// ✅ 正确的顺序
r.use(recovery())     // 1. 最外层（异常恢复）
r.use(requestid())    // 2. 生成请求 ID
r.use(logger())       // 3. 日志记录
r.use(cors())         // 4. CORS
r.use(auth())         // 5. 认证
r.use(rateLimit())    // 6. 限流

// ❌ 错误的顺序
r.use(rateLimit())    // 限流太早，会限制合法请求
r.use(auth())         // 认证在 CORS 之前，可能导致预检失败
r.use(cors())         // CORS 太晚
r.use(logger())       // 日志太晚，无法记录错误
r.use(recovery())     // 恢复在最内层，无法捕获外层异常
```

### 2. 中间件应该专注单一职责

```cj
// ✅ 好：每个中间件只做一件事
r.use(logger())       // 只记录日志
r.use(cors())         // 只处理 CORS
r.use(auth())         // 只验证身份

// ❌ 差：一个中间件做多件事
r.use(complexMiddleware())  // 日志 + CORS + 认证混在一起
```

### 3. 中间件应该是可复用的

```cj
// ✅ 好：可配置、可复用
r.use(rateLimit([
    withMaxRequests(100),
    withWindowMs(60000)
]))

// ❌ 差：硬编码、不可复用
r.use(hardcodedRateLimit())
```

### 4. 中间件应该优雅地处理错误

```cj
func errorHandlingMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            try {
                next(ctx)
            } catch (e: Exception) {
                // 记录错误
                println("[ERROR] ${e.message}")

                // 返回友好的错误响应
                ctx.status(500u16).json(HashMap<String, String>([
            ("error", "Internal server error")
        ]))
            }
        }
    }
}
```

## 中间件配置模式

### Option 函数模式

Tang 使用 Option 函数模式来配置中间件：

```cj
// 定义 Option 类型
public type SomeMiddlewareOption = (SomeMiddlewareConfig) -> Unit

// Option 函数
public func withConfig(value: String): SomeMiddlewareOption {
    return { config => config.setConfig(value) }
}

// 中间件函数
public func someMiddleware(opts: Array<SomeMiddlewareOption>): MiddlewareFunc {
    let config = SomeMiddlewareConfig()

    // 应用所有选项
    for (opt in opts) {
        opt(config)
    }

    return { next => ... }
}
```

**使用示例**：
```cj
r.use(someMiddleware([
    withConfig("value1"),
    withOption(123)
]))
```

## 中间件性能考虑

### 1. 避免重复创建中间件

```cj
// ❌ 差：每次请求都创建新中间件
r.get("/api/data", { ctx =>
    let middleware = new ExpensiveMiddleware()
    middleware.process(ctx)
})

// ✅ 好：复用中间件实例
let middleware = new ExpensiveMiddleware()
r.use({ next => return { ctx => middleware.process(ctx); next(ctx) } })
```

### 2. 尽早过滤请求

```cj
// ✅ 好：尽早拒绝无效请求
r.use(validateRequest())  // 在其他中间件之前验证
r.use(auth())
r.use(rateLimit())
```

### 3. 使用惰性初始化

```cj
class DatabaseConnection {
    static let instance = DatabaseConnection()
}

func dbMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 只在需要时才初始化连接
            let db = DatabaseConnection.instance
            ctx.kvSet("db", db)
            next(ctx)
        }
    }
}
```

## 中间件调试

### 记录中间件执行顺序

```cj
func debugMiddleware(name: String): MiddlewareFunc {
    return { next =>
        return { ctx =>
            println("[ENTER] ${name}")
            next(ctx)
            println("[EXIT] ${name}")
        }
    }
}

// 使用
r.use(debugMiddleware("Recovery"))
r.use(debugMiddleware("Logger"))
r.use(debugMiddleware("CORS"))
```

**输出**：
```
[ENTER] Recovery
[ENTER] Logger
[ENTER] CORS
[EXIT] CORS
[EXIT] Logger
[EXIT] Recovery
```

## 下一步

- **[自定义中间件开发](custom.md)** - 如何开发自己的中间件
- **[内置中间件](builtin/)** - 23+ 内置中间件文档
- **[中间件示例](../../examples/middleware_showcase/)** - 完整示例代码

## 相关链接

- **[源码](../../src/middleware/)** - 中间件源代码
- **[Router API](../api/router.md)** - Router API 文档
