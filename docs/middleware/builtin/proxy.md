# Proxy - 反向代理

> **本分支暂不可用**：Proxy 需要 HTTP 客户端能力，而 tachyon 只提供服务端。
> 该中间件在 `_disabled/` 里，计划拆成 `tang_ext_proxy`（可引入 stdx.net.http 客户端）。

## 概述

- **功能**：将请求反向代理到后端服务器
- **分类**：路由处理
- **文件**：`src/middleware/proxy/proxy.cj`

Proxy 中间件提供完整的 HTTP 反向代理功能，支持负载均衡（RoundRobin、Random）、完整转发请求/响应、添加代理 Headers 等功能。

> **💡 提示：代理类型**
>
> **反向代理（Reverse Proxy）**：
> - 代表服务器接收请求
> - 客户端不知道实际处理请求的服务器
> - 常用于负载均衡、缓存、SSL 卸载
>
> **正向代理（Forward Proxy）**：
> - 代表客户端发送请求
> - 服务器不知道实际客户端 IP
> - 常用于访问控制、匿名访问
>
> Tang Proxy 是**反向代理**

## 签名

```cj
public func proxy(): MiddlewareFunc
public func proxy(opts: Array<ProxyOption>): MiddlewareFunc
public func proxy(targetUrl: String): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withBackend()` | `String` | 必填 | 后端服务器 URL |
| `withBackends()` | `Array<String>` | 必填 | 后端服务器列表（负载均衡） |
| `withStrategy()` | `LoadBalanceStrategy` | `RoundRobin` | 负载均衡策略 |
| `withTimeout()` | `Int64` | `30000`（30秒） | 超时时间（毫秒） |
| `withRetry()` | `Int32` | `3` | 重试次数 |
| `withStripPrefix()` | `String` | `""` | 移除的 URL 前缀 |
| `withModifyResponse()` | `(TangHttpContext, HttpResponse) -> Unit` | - | 自定义响应修改函数 |

## 快速开始

### 单个后端服务器

```cj
import tang.middleware.proxy.{proxy, withBackend}

let r = Router()

// 代理所有请求到后端服务器
r.use(proxy([
    withBackend("http://localhost:3000")
]))

// 注册 catch-all 路由
r.all("/*", { ctx =>
    ctx.responseBuilder.status(404u16).body("Proxy: No route configured")
})
```

**请求流程**：
```
客户端 → Tang (localhost:8080) → 后端 (localhost:3000)
```

### 多个后端服务器（负载均衡）

```cj
import tang.middleware.proxy.{proxy, withBackends, withStrategy, LoadBalanceStrategy}

let r = Router()

r.use(proxy([
    withBackends([
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:3002"
    ]),
    withStrategy(LoadBalanceStrategy.RoundRobin)  // 轮询策略
]))
```

**请求分配**（RoundRobin）：
```
请求 1 → localhost:3000
请求 2 → localhost:3001
请求 3 → localhost:3002
请求 4 → localhost:3000  (循环)
...
```

## 完整示例

### 示例 1：API 网关

```cj
import tang.*
import tang.middleware.proxy.{proxy, withBackends, withStrategy, LoadBalanceStrategy}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())

    // API 路由组：代理到后端服务
    let apiRoutes = r.group("/api")
    apiRoutes.use(proxy([
        withBackends([
            "http://backend-1.example.com:8080",
            "http://backend-2.example.com:8080",
            "http://backend-3.example.com:8080"
        ]),
        withStrategy(LoadBalanceStrategy.RoundRobin),
        withTimeout(10000),  // 10 秒超时
        withRetry(3)
    ]))

    // 注册 catch-all 路由
    apiRoutes.all("/*", { ctx =>
        ctx.responseBuilder.status(404u16).body("API endpoint not found")
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**测试**：
```bash
# 访问代理
curl http://localhost:8080/api/users

# 请求被转发到：
# http://backend-X.example.com:8080/api/users
```

### 示例 2：移除 URL 前缀

```cj
import tang.middleware.proxy.{proxy, withBackend, withStripPrefix}

let r = Router()

let apiRoutes = r.group("/api/v1")
apiRoutes.use(proxy([
    withBackend("http://backend.example.com:3000"),
    withStripPrefix("/api/v1")  // 移除 /api/v1 前缀
]))

apiRoutes.all("/*", { ctx =>
    ctx.responseBuilder.status(404u16).body("Not found")
})
```

**请求映射**：
```
客户端请求：/api/v1/users
代理转发：http://backend.example.com:3000/users
```

### 示例 3：修改响应

```cj
import tang.middleware.proxy.{proxy, withBackend, withModifyResponse}
import stdx.net.http.HttpResponse

let r = Router()

r.use(proxy([
    withBackend("http://backend.example.com:3000"),
    withModifyResponse({ ctx, response =>
        // 添加自定义响应头
        ctx.responseBuilder.header("X-Proxied-By", "Tang")
        ctx.responseBuilder.header("X-Backend", response.headers.getFirst("Server") ?? "Unknown")
    })
]))
```

### 示例 4：条件代理

```cj
import tang.middleware.proxy.{proxy, withBackend}

let r = Router()

// 根据路径代理到不同的后端
r.get("/service-a/*", { ctx =>
    // 使用不同的代理规则
    let proxyA = proxy([
        withBackend("http://service-a.example.com")
    ])
    proxyA({ ctx => })(ctx)
})

r.get("/service-b/*", { ctx =>
    let proxyB = proxy([
        withBackend("http://service-b.example.com")
    ])
    proxyB({ ctx => })(ctx)
})
```

### 示例 5：错误处理和重试

```cj
import tang.middleware.proxy.{proxy, withBackends, withStrategy, withTimeout, withRetry}
import tang.middleware.log.logger

let r = Router()

r.use(logger())

r.use(proxy([
    withBackends([
        "http://backend-1.example.com",
        "http://backend-2.example.com",
        "http://backend-3.example.com"
    ]),
    withStrategy(LoadBalanceStrategy.Random),  // 随机策略
    withTimeout(5000),    // 5 秒超时
    withRetry(2)         // 失败后重试 2 次
]))

r.all("/api/*", { ctx =>
    ctx.responseBuilder.status(404u16).body("Not found")
})
```

## 负载均衡策略

### RoundRobin（轮询）

```cj
import tang.middleware.proxy.{proxy, withBackends, withStrategy, LoadBalanceStrategy}

r.use(proxy([
    withBackends([
        "http://backend-1:8080",
        "http://backend-2:8080",
        "http://backend-3:8080"
    ]),
    withStrategy(LoadBalanceStrategy.RoundRobin)
]))
```

**请求分配**：
```
请求 1 → backend-1
请求 2 → backend-2
请求 3 → backend-3
请求 4 → backend-1  (循环)
```

### Random（随机）

```cj
r.use(proxy([
    withBackends([
        "http://backend-1:8080",
        "http://backend-2:8080",
        "http://backend-3:8080"
    ]),
    withStrategy(LoadBalanceStrategy.Random)
]))
```

**请求分配**：
```
请求 1 → backend-2  (随机)
请求 2 → backend-1  (随机)
请求 3 → backend-3  (随机)
```

## 测试

### 测试 GET 代理

```bash
# 客户端请求
curl http://localhost:8080/api/users

# 后端服务器收到：
# GET /api/users
# Host: localhost:8080
# X-Forwarded-Host: localhost:8080
# X-Forwarded-Proto: http
# X-Forwarded-Path: /api/users

# 客户端收到后端响应
```

### 测试 POST 代理

```bash
# POST 请求
curl -X POST http://localhost:8080/api/data \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","value":"123"}'

# 请求体、Content-Type 等都会被转发到后端
```

### 测试 WebSocket 检测

```bash
# 尝试 WebSocket 升级
curl -H "Upgrade: websocket" \
     -H "Connection: Upgrade" \
     http://localhost:8080/api/data

# 响应：
# HTTP 426 Upgrade Required
# {"error":"WebSocket not supported by HTTP proxy"}
```

> **💡 提示：WebSocket 代理**
>
> **当前限制**：Proxy 中间件**不支持 WebSocket**。
>
> **原因**：
> - Proxy 使用请求-响应模式
> - WebSocket 需要双向持久连接
> - `Client.send()` 是一次性 HTTP 请求
>
> **替代方案**：
> 1. **直接连接后端**：客户端直接连接到后端 WebSocket 服务器
> 2. **使用专门的 WebSocket Proxy Handler**（未来功能）
>
> **检测机制**：
> - 检测 `Upgrade: websocket` 头
> - 返回 426 错误，友好提示

## 工作原理

### 代理流程

```
1. 客户端发送请求到 Tang
   ↓
2. Proxy 中间件接收请求
   ↓
3. 检测 WebSocket Upgrade（如果是，返回 426）
   ↓
4. 选择后端服务器（负载均衡）
   ↓
5. 移除 URL 前缀（如果配置了 withStripPrefix）
   ↓
6. 构建目标 URL
   ↓
7. 使用 HTTP Client 转发请求
   - 复制 HTTP 方法
   - 复制请求体
   - 复制请求头（除 Connection）
   - 添加 X-Forwarded-* 头
   ↓
8. 接收后端响应
   ↓
9. 复制响应状态码
   ↓
10. 复制响应头（除 Connection）
   ↓
11. 复制响应体
   ↓
12. 调用自定义响应修改函数
   ↓
13. 返回响应给客户端
```

### 代理 Headers

Proxy 中间件会自动添加以下代理相关 Headers：

```http
X-Forwarded-Host: localhost:8080
X-Forwarded-Proto: http
X-Forwarded-Path: /api/users
```

**用途**：
- 后端服务器可以知道原始请求信息
- 用于日志记录、安全验证等

## 注意事项

### 1. Connection 头的处理

Proxy 会自动删除 `Connection` 头，避免连接混淆：

```cj
// 不转发 Connection 头
for ((name, values) in ctx.request.headers) {
    if (name != "Connection") {
        for (value in values) {
            requestBuilder.header(name, value)
        }
    }
}
```

### 2. 后端健康检查

建议实现健康检查，自动移除不健康的后端：

```cj
class BackendHealthChecker {
    var healthyBackends: ArrayList<String> = ArrayList()
    let mu: Mutex = Mutex()

    public func checkHealth(): Unit {
        synchronized(this.mu) {
            for (backend in this.healthyBackends) {
                // 发送健康检查请求
                let response = httpClient.get("${backend}/health")

                if (response.status != 200) {
                    // 不健康，移除
                    this.healthyBackends.remove(backend)
                }
            }
        }
    }
}
```

### 3. 超时和重试

合理设置超时和重试次数：

```cj
// ❌ 超时太长：用户等待过久
r.use(proxy([withTimeout(60000)]))  // 60 秒

// ❌ 重试太多：雪崩效应
r.use(proxy([withRetry(10)]))  // 失败后重试 10 次

// ✅ 合理配置
r.use(proxy([
    withTimeout(5000),  // 5 秒
    withRetry(2)        // 最多重试 2 次
]))
```

### 4. 日志记录

记录代理请求和响应，便于调试：

```cj
func loggingProxy(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()

            next(ctx)

            let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()
            println("[Proxy] ${ctx.method()} ${ctx.path()} - ${duration}ms")
        }
    }
}

r.use(loggingProxy())
r.use(proxy([withBackend("http://backend:3000")]))
```

## 常见问题

### 问题 1：后端返回 404

**原因**：URL 路径不正确

**解决**：
```cj
// 检查是否需要移除前缀
r.use(proxy([
    withBackend("http://backend:3000"),
    withStripPrefix("/api")  // 移除 /api 前缀
]))

// 请求：/api/users
// 转发：http://backend:3000/users
```

### 问题 2：POST 请求体丢失

**原因**：后端没有正确接收请求体

**解决**：
```cj
// 确保 Proxy 正确转发请求体
let bodyRaw = ctx.bodyRaw()
if (bodyRaw.size > 0) {
    requestBuilder.body(bodyRaw)  // ✅ 转发请求体
}
```

### 问题 3：CORS 错误

**原因**：后端 CORS 配置问题

**解决**：
```cj
// 在 Tang 网关处理 CORS
r.use(cors())

// 后端不需要再配置 CORS（或者配置允许网关域名）
```

## 相关链接

- **[Rewrite 中间件](rewrite.md)** - URL 重写
- **[源码](../../../src/middleware/proxy/proxy.cj)** - Proxy 源代码
