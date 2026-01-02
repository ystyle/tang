# 中间件文档

Tang 框架提供了 23+ 个内置中间件，覆盖日志、安全、认证、缓存、流量控制等各个方面。

## 中间件分类

### 监控与检查
- **[HealthCheck](builtin/healthcheck.md)** - 健康检查（存活、就绪、系统信息）

### 路由与请求控制
- **[Redirect](builtin/redirect.md)** - URL 重定向（301/302/303/307/308）
- **[Favicon](builtin/favicon.md)** - 网站图标处理
- **[Timeout](builtin/timeout.md)** - 请求超时控制

### 安全类
- **[Security](builtin/security.md)** - 安全头设置（类似 helmet）
- **[CORS](builtin/cors.md)** - 跨域资源共享
- **[BasicAuth](builtin/basicauth.md)** - HTTP 基本认证
- **[CSRF](builtin/csrf.md)** - 跨站请求伪造保护
- **[KeyAuth](builtin/keyauth.md)** - API 密钥认证

### 日志与监控
- **[AccessLog](builtin/accesslog.md)** - 访问日志（记录请求方法、路径、状态码、延迟等）
- **[Logger](builtin/log.md)** - 简化的请求日志
- **[RequestID](builtin/requestid.md)** - 请求 ID（用于请求追踪）

### 异常处理
- **[Recovery](builtin/recovery.md)** - 异常恢复（捕获 panic，返回友好错误响应）

### 流量控制
- **[RateLimit](builtin/ratelimit.md)** - 请求速率限制（滑动窗口算法）
- **[BodyLimit](builtin/bodylimit.md)** - 请求体大小限制

### 静态文件
- **[StaticFile](builtin/staticfile.md)** - 静态文件服务（支持目录浏览、索引文件）

### 会话与Cookie
- **[Session](builtin/session.md)** - 会话管理（内存存储、Cookie 自动管理）
- **[EncryptCookie](builtin/encryptcookie.md)** - Cookie 加密（SM4-CBC + HMAC-SHA256）

### 缓存与优化
- **[Cache](builtin/cache.md)** - 缓存控制（Cache-Control 响应头）
- **[ETag](builtin/etag.md)** - 缓存验证（ETag 响应头）

### 路由处理
- **[Rewrite](builtin/rewrite.md)** - URL 重写（支持正则表达式）
- **[Proxy](builtin/proxy.md)** - 反向代理（支持负载均衡）

### 高级功能
- **[Idempotency](builtin/idempotency.md)** - 幂等性控制（防止重复提交）

## 中间件使用方式

### 基础用法

```cj
import tang.middleware.log.logger

let r = Router()
r.use(logger())  // 全局应用

r.get("/", { ctx =>
    ctx.writeString("Hello, World!")
})
```

### 带配置的用法

```cj
import tang.middleware.cors.{cors, withOrigins, withMethods}

let r = Router()
r.use(cors([
    withOrigins(["https://example.com"]),
    withMethods(["GET", "POST", "PUT"])
]))
```

### 路由组应用

```cj
let api = r.group("/api")
api.use([logger(), cors()])  // 仅应用于 /api 路由组
```

### 单个路由应用

```cj
r.get("/protected", authMiddleware(), { ctx =>
    ctx.writeString("Protected route")
})
```

## 自定义中间件

了解如何开发自己的中间件：

```cj
func myMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 请求前处理
            println("Request: ${ctx.method()} ${ctx.path()}")

            next(ctx)  // 调用下一个中间件/处理器

            // 响应后处理
            println("Response sent")
        }
    }
}
```

详细教程请参考：[自定义中间件开发](custom.md)

## 中间件执行顺序

中间件按照注册顺序执行（洋葱模型）：

```
请求 → Logger → CORS → Auth → Handler
响应 ← Logger ← CORS ← Auth ← Handler
```

**示例**：

```cj
r.use(recovery())   // 1. 最外层：异常恢复
r.use(logger())     // 2. 请求日志
r.use(cors())       // 3. CORS 处理
r.use(auth())       // 4. 认证检查
```

## 相关链接

- **[自定义中间件开发](custom.md)** - 如何编写自己的中间件
- **[中间件原理](overview.md)** - 中间件系统工作原理
- **[源码](../../src/middleware/)** - 中间件源代码
