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

中间件按**是否依赖 stdx** 分两类：核心成员里的 16 个零依赖，加密相关的 5 个在 `tang_ext_crypto`。

### 核心（`tang`，零 stdx）

import 前缀：`tang.middleware.<名字>`

| 分类 | 中间件 |
|---|---|
| 监控与检查 | HealthCheck |
| 路由与请求控制 | Redirect、Rewrite、Favicon、Timeout、Proxy（自带 HTTP 客户端，零 stdx） |
| 安全类 | Security、CORS、BasicAuth、KeyAuth |
| 日志与监控 | Log、AccessLog、RequestID |
| 异常处理 | Exception（取代旧 Recovery，动机会在文档里说明） |
| 流量控制 | RateLimit、BodyLimit |
| 静态文件 | StaticFile（基于 tachyon `FileServer` / `std.fs`） |
| 缓存与优化 | Cache |

### 加密类（`tang_ext_crypto`，依赖 stdx.crypto）

import 前缀：`tang_ext_crypto.<名字>`

| 中间件 | 说明 |
|---|---|
| CSRF | CSRF 保护（token 生成/校验） |
| Session | 会话管理（签名 Cookie） |
| EncryptCookie | Cookie 加密 |
| ETag | 基于摘要的 ETag 校验 |
| Idempotency | 幂等键控制（防重复提交） |

> 迁移提示：这 5 个的 import 从 `tang.middleware.xxx` 改成了 `tang_ext_crypto.xxx`，
> 并需要在 `cjpm.toml` 里加上 `tang_ext_crypto` 依赖（以及 `CANGJIE_STDX_PATH` 环境）。
