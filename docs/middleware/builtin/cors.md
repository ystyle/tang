# CORS - 跨域资源共享

## 概述

- **功能**：处理跨域资源共享（Cross-Origin Resource Sharing）
- **分类**：安全类
- **文件**：`src/middleware/cors/cors.cj`

CORS 中间件用于处理跨域请求，设置适当的响应头来允许或限制跨域访问。这是前后端分离架构中必不可少的中间件。

## 签名

```cj
public func cors(): MiddlewareFunc
public func cors(opts: Array<CORSOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withOrigins()` | `Array<String>` | `["*"]` | 允许的源（`*` 表示所有源） |
| `withMethods()` | `Array<String>` | 常用方法 | 允许的 HTTP 方法 |
| `withHeaders()` | `Array<String>` | 常用头 | 允许的请求头 |
| `withCredentials()` | `Bool` | `false` | 是否允许发送凭据（Cookie、Authorization） |
| `withMaxAge()` | `Int64` | `86400` | 预检请求缓存时间（秒） |

## 快速开始

### 基础用法（允许所有源）

```cj
import tang.middleware.cors.cors

let r = Router()

// 允许所有源（开发环境）
r.use(cors())

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello from CORS!")
        ]))
})
```

**响应头**：

```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS
Access-Control-Allow-Headers: Origin,Content-Type,Accept
```

### 带配置的用法（生产环境）

```cj
import tang.middleware.cors.{cors, withOrigins, withMethods, withHeaders, withCredentials}

let r = Router()

// 仅允许特定源
r.use(cors([
    withOrigins(["https://example.com", "https://www.example.com"]),
    withMethods(["GET", "POST", "PUT", "DELETE"]),
    withHeaders(["Content-Type", "Authorization"]),
    withCredentials(true)  // 允许发送 Cookie
]))

r.get("/api/users", { ctx =>
    ctx.json(ArrayList<String>())
})
```

> **💡 提示：CORS 工作原理**
>
> 跨域请求分为两类：
>
> **1. 简单请求**（Simple Request）：
> - 方法：GET、HEAD、POST
> - 头：Content-Type（仅 application/x-www-form-urlencoded、multipart/form-data、text/plain）
>
> **2. 预检请求**（Preflight Request）：
> - 方法：OPTIONS
> - 先发送 OPTIONS 请求，服务器返回允许的方法和头
> - 浏览器验证通过后才发送实际请求

## 完整示例

### 示例 1：前后端分离配置

```cj
import tang.*
import tang.middleware.cors.{cors, withOrigins, withMethods, withHeaders, withCredentials}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // CORS 配置（前端域名）
    r.use(cors([
        withOrigins(["https://frontend.example.com"]),
        withMethods(["GET", "POST", "PUT", "DELETE", "PATCH"]),
        withHeaders(["Content-Type", "Authorization", "X-Requested-With"]),
        withCredentials(true),  // 允许前端携带 Cookie
        withMaxAge(3600)  // 预检请求缓存 1 小时
    ]))

    // API 路由
    let api = r.group("/api")

    api.get("/users", { ctx =>
        ctx.json(ArrayList<Map<String, String>>())
    })

    api.post("/login", { ctx =>
        // 设置 Cookie
        ctx.setSimpleCookie("session", "abc123")
        ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：多域名配置

```cj
import tang.middleware.cors.{cors, withOrigins}

let r = Router()

// 允许多个域名
r.use(cors([
    withOrigins([
        "https://example.com",
        "https://www.example.com",
        "https://app.example.com",
        "http://localhost:3000",  // 开发环境
        "http://localhost:8080"
    ]),
    withCredentials(true)
]))
```

### 示例 3：动态源配置

```cj
import tang.middleware.cors.cors

func dynamicCORS(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let origin = ctx.getHeader("Origin")

            match (origin) {
                case Some(o) =>
                    // 检查源是否在白名单中
                    if (isOriginAllowed(o)) {
                        // 动态设置允许的源
                        ctx.responseBuilder.header("Access-Control-Allow-Origin", o)
                        ctx.responseBuilder.header("Access-Control-Allow-Credentials", "true")
                    }
                case None => ()
            }

            // 处理 OPTIONS 预检请求
            if (ctx.method() == "OPTIONS") {
                ctx.responseBuilder
                    .status(200u16)
                    .header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
                    .header("Access-Control-Allow-Headers", "Content-Type,Authorization")
                    .header("Access-Control-Max-Age", "86400")
                    .body("")
                return
            }

            next(ctx)
        }
    }
}

func isOriginAllowed(origin: String): Bool {
    let allowedOrigins = [
        "https://example.com",
        "https://www.example.com"
    ]
    return allowedOrigins.contains(origin)
}

let r = Router()
r.use(dynamicCORS())
```

### 示例 4：开发环境 vs 生产环境

```cj
import std.env.Env
import tang.middleware.cors.{cors, withOrigins, withCredentials}

func getCORS(): MiddlewareFunc {
    let env = Env.get("ENV") ?? "development"

    if (env == "production") {
        // 生产环境：仅允许前端域名
        return cors([
            withOrigins(["https://example.com"]),
            withCredentials(true)
        ])
    } else {
        // 开发环境：允许所有源
        return cors()
    }
}

let r = Router()
r.use(getCORS())
```

## 测试

### 测试简单请求

```bash
# 简单 GET 请求
curl -H "Origin: https://example.com" \
     http://localhost:8080/api/users

# 响应头包含：
# Access-Control-Allow-Origin: https://example.com
```

### 测试预检请求

```bash
# OPTIONS 预检请求
curl -X OPTIONS \
     -H "Origin: https://example.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     http://localhost:8080/api/users

# 响应头包含：
# Access-Control-Allow-Origin: https://example.com
# Access-Control-Allow-Methods: GET,POST,PUT,DELETE
# Access-Control-Allow-Headers: Content-Type,Authorization
# Access-Control-Max-Age: 86400
```

### 测试带凭据的请求

```bash
# 带Cookie的请求
curl -H "Origin: https://example.com" \
     -H "Cookie: session=abc123" \
     --cookie-jar cookies.txt \
     http://localhost:8080/api/profile

# 需要 withCredentials(true) 配置
```

## 工作原理

### 简单请求流程

```
1. 浏览器发送请求：
   GET /api/users
   Origin: https://example.com

2. 服务器返回响应：
   Access-Control-Allow-Origin: https://example.com
   { "users": [...] }

3. 浏览器验证响应头，检查是否允许访问
```

### 预检请求流程

```
1. 浏览器发送 OPTIONS 请求：
   OPTIONS /api/users
   Origin: https://example.com
   Access-Control-Request-Method: POST
   Access-Control-Request-Headers: Content-Type

2. 服务器返回允许的方法和头：
   Access-Control-Allow-Origin: https://example.com
   Access-Control-Allow-Methods: POST
   Access-Control-Allow-Headers: Content-Type
   Access-Control-Max-Age: 86400

3. 浏览器验证通过后，发送实际请求：
   POST /api/users
   Origin: https://example.com
   Content-Type: application/json
   { "name": "Test" }
```

## 注意事项

### 1. `withCredentials(true)` 的限制

当设置 `withCredentials(true)` 时，**不能使用通配符 `*`**：

```cj
// ❌ 错误：withCredentials 和通配符不能同时使用
r.use(cors([
    withOrigins(["*"]),      // 通配符
    withCredentials(true)    // 错误！
]))

// ✅ 正确：指定具体的源
r.use(cors([
    withOrigins(["https://example.com"]),
    withCredentials(true)
]))
```

### 2. 生产环境避免使用通配符

生产环境应该明确指定允许的源：

```cj
// ❌ 生产环境：不安全
r.use(cors())  // 允许所有源

// ✅ 生产环境：明确指定
r.use(cors([
    withOrigins(["https://your-frontend.com"])
]))
```

### 3. 预检请求缓存

合理设置预检请求缓存时间，减少 OPTIONS 请求：

```cj
r.use(cors([
    withMaxAge(3600)  // 缓存 1 小时（秒）
]))
```

**说明**：
- 预检请求结果会被浏览器缓存
- 在缓存时间内，同一个 URL 不会再发送 OPTIONS 请求
- 过长的缓存时间可能导致配置变更不生效

### 4. 响应头不要设置过多

只设置必要的响应头，避免响应过大：

```cj
// ❌ 错误：过多的响应头
r.use(cors([
    withHeaders([
        "Content-Type",
        "Authorization",
        "X-Custom-Header-1",
        "X-Custom-Header-2",
        // ... 更多头
    ])
]))

// ✅ 正确：只设置必要的头
r.use(cors([
    withHeaders(["Content-Type", "Authorization"])
]))
```

### 5. 与 Nginx/Apache 配置协同

如果使用反向代理，CORS 配置可以在应用层或代理层：

**应用层（Tang）**：
```cj
r.use(cors([withOrigins(["https://example.com")]))
```

**Nginx 代理层**：
```nginx
add_header Access-Control-Allow-Origin https://example.com;
add_header Access-Control-Allow-Methods GET,POST,PUT,DELETE;
add_header Access-Control-Allow-Headers Content-Type,Authorization;
```

> **💡 提示：CORS 配置位置选择**
>
> - **应用层（推荐）**：更灵活，可以根据业务逻辑动态调整
> - **代理层**：统一管理，性能稍好（不需要转发到应用）
>
> 如果两者都有配置，确保配置一致，避免冲突

## 常见问题

### 问题 1：CORS 错误 "No 'Access-Control-Allow-Origin' header"

**原因**：未正确配置 CORS 中间件

**解决**：
```cj
r.use(cors())  // 添加 CORS 中间件
```

### 问题 2：Cookie 无法发送

**原因**：未设置 `withCredentials(true)`

**解决**：
```cj
r.use(cors([
    withOrigins(["https://example.com"]),
    withCredentials(true)  // 允许凭据
]))
```

### 问题 3：预检请求失败

**原因**：请求头未在 `withHeaders()` 中声明

**解决**：
```cj
r.use(cors([
    withHeaders(["Content-Type", "Authorization", "X-Custom-Header"])
]))
```

## 相关链接

- **[CSRF 中间件](csrf.md)** - 跨站请求伪造保护
- **[Security 中间件](security.md)** - 安全响应头设置
- **[源码](../../../src/middleware/cors/cors.cj)** - CORS 源代码
