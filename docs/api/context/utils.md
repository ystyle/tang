
# 辅助方法

## 概述

TangHttpContext 提供了丰富的辅助方法用于获取请求信息、URL 详情、客户端信息、协议版本等。这些方法帮助你在处理请求时获取上下文信息。

**主要功能**：
- **请求信息**：`method()`, `path()`, `originalURL()`
- **URL 信息**：`baseURL()`, `hostName()`, `port()`
- **客户端信息**：`ip()`, `ips()`, `secure()`
- **协议信息**：`protocolVersion()`
- **内容类型**：`contentType()`, `is()`, `isType()`
- **自定义存储**：`kvGet<T>()`, `kvSet()`
- **请求头**：`getHeader()`

## 请求信息

### 获取 HTTP 方法

使用 `method()` 获取请求的 HTTP 方法（返回字符串）：

```cj
r.all("/debug", { ctx =>
    let m = ctx.method()  // "GET", "POST", "PUT", "DELETE", etc.

    ctx.json(HashMap<String, String>([
        ("method", m),
        ("message", "HTTP method is ${m}")
    ]))
})

r.post("/webhook", { ctx =>
    if (ctx.method() != "POST") {
        ctx.jsonWithCode(405u16,
            HashMap<String, String>([
            ("error", "Method not allowed")
        ])
        )
        return
    }
    // 处理 POST 请求...
})
```

### 获取请求路径

使用 `path()` 获取请求路径（考虑路径重写）：

```cj
r.get("/users/:id", { ctx =>
    let path = ctx.path()  // "/users/123"

    ctx.json(HashMap<String, String>([
        ("path", path),
        ("userId", ctx.param("id"))
    ]))
})
```

**重要**：如果使用了 Rewrite 中间件，`path()` 返回重写后的路径：

```cj
// 添加重写规则
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))

r.get("/new/:id", { ctx =>
    // 请求 /old/123 会被重写为 /new/123
    ctx.path()  // 返回 "/new/123"（重写后的路径）
})
```

### 获取原始 URL

使用 `originalURL()` 获取完整的原始 URL（包含协议和域名）：

```cj
r.get("/debug", { ctx =>
    let url = ctx.originalURL()  // "http://example.com/debug?foo=bar"

    ctx.json(HashMap<String, String>([
        ("url", url)
    ]))
})
```

## URL 信息

### 获取 Base URL

使用 `baseURL()` 获取基础 URL（协议 + 域名）：

```cj
r.get("/info", { ctx =>
    let base = ctx.baseURL()  // "http://example.com" 或 "https://example.com"

    ctx.json(HashMap<String, String>([
        ("baseURL", base)
    ]))
})
```

**使用场景**：生成绝对链接：

```cj
r.get("/post/:id", { ctx =>
    let postID = ctx.param("id")
    let baseURL = ctx.baseURL()
    let postURL = "${baseURL}/post/${postID}"

    ctx.json(HashMap<String, String>([
        ("post_id", postID),
        ("post_url", postURL)
    ]))
})
```

### 获取主机名

使用 `hostName()` 获取请求的主机名：

```cj
r.get("/host", { ctx =>
    let hostname = ctx.hostName()  // "example.com" 或 "localhost:8080"

    ctx.json(HashMap<String, String>([
        ("hostname", hostname)
    ]))
})
```

### 获取端口号

使用 `port()` 获取请求的端口号：

```cj
r.get("/port", { ctx =>
    let port = ctx.port()  // 80, 443, 或自定义端口（8080）

    ctx.json(HashMap<String, String>([
            ("port", "${port}")
        ]))
})
```

**注意**：
- HTTP 默认端口：80
- HTTPS 默认端口：443
- 如果 URL 中明确指定了端口号，返回指定的端口

> **💡 提示：URL 组成部分**
>
> ```
https://example.com:8080/path/to/resource?query=value#fragment
│       │          │    │                   │
│       │          │    └─ path()          └─ query (通过 query() 获取)
│       │          └─ port()
│       └─ hostName()
└─ baseURL()
```

`originalURL()` 返回完整的 URL（不包含 fragment）


## 客户端信息

### 获取客户端 IP

使用 `ip()` 获取客户端的 IP 地址：

```cj
r.get("/ip", { ctx =>
    let clientIP = ctx.ip()  // "192.168.1.100" 或 "127.0.0.1"

    ctx.json(HashMap<String, String>([
        ("ip", clientIP)
    ]))
})
```

**注意**：如果应用位于反向代理（如 Nginx）后面，`ip()` 返回的是代理服务器的 IP。

### 获取代理链 IP 列表

使用 `ips()` 获取 `X-Forwarded-For` 头中的所有 IP：

```cj
r.get("/ips", { ctx =>
    let allIPs = ctx.ips()  // ArrayList<String>

    // 如果经过多个代理：
    // ["client IP", "proxy1 IP", "proxy2 IP"]

    ctx.json(allIPs)
})
```

**使用场景**：处理反向代理场景：

```cj
func getClientIP(ctx: TangHttpContext): String {
    let forwarded = ctx.ips()

    if (forwarded.size > 0) {
        // X-Forwarded-For 的第一个 IP 是客户端 IP
        return forwarded[0]
    } else {
        // 没有代理，直接返回 remote address
        return ctx.ip()
    }
}

r.get("/client-info", { ctx =>
    let clientIP = getClientIP(ctx)

    ctx.json(HashMap<String, String>([
        ("client_ip", clientIP)
    ]))
})
```

### 检查 HTTPS 连接

使用 `secure()` 检查请求是否为 HTTPS：

```cj
r.get("/check-secure", { ctx =>
    let isSecure = ctx.secure()  // true 或 false

    if (!isSecure) {
        ctx.jsonWithCode(400u16,
            HashMap<String, String>([
            ("error", "HTTPS required")
        ])
        )
        return
    }

    ctx.json(HashMap<String, String>([
            ("message", "Connection is secure")
        ]))
})
```

**使用场景**：强制 HTTPS：

```cj
// 全局中间件：强制 HTTPS
func enforceHTTPS(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (!ctx.secure()) {
                // 重定向到 HTTPS
                let httpsURL = "https://${ctx.hostName()}${ctx.path()}"
                ctx.redirectWithStatus(httpsURL, 301u16)
                return
            }
            next(ctx)
        }
    }
}

r.use([enforceHTTPS()])
```

## 协议信息

### 获取 HTTP 协议版本

使用 `protocolVersion()` 获取 HTTP 协议版本：

```cj
r.get("/version", { ctx =>
    let version = ctx.protocolVersion()  // Protocol 枚举

    // Protocol 可选值：
    // - Protocol.Http10
    // - Protocol.Http11
    // - Protocol.Http2
    // - Protocol.Http3

    ctx.json(HashMap<String, String>([
            ("protocol", "${version}")
        ]))
})
```

**使用场景**：根据协议版本调整行为：

```cj
r.get("/data", { ctx =>
    let version = ctx.protocolVersion()

    if (version == Protocol.Http2 || version == Protocol.Http3) {
        // HTTP/2 和 HTTP/3 支持服务器推送等高级特性
        ctx.set("X-HTTP-Version", "2+")
    } else {
        // HTTP/1.1 使用传统方式
        ctx.set("X-HTTP-Version", "1.1")
    }

    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

## 内容类型

### 获取 Content-Type

使用 `contentType()` 获取请求的 Content-Type 头：

```cj
r.post("/data", { ctx =>
    let ct = ctx.contentType()  // ?String

    match (ct) {
        case Some(contentType) =>
ctx.json(HashMap<String, String>([
            ("message", "Content-Type is ${contentType}")
        ]))
        case None =>
ctx.json(HashMap<String, String>([
            ("message", "No Content-Type header")
        ]))
    }
})
```

### 检查内容类型

使用 `is()` 或 `isType()` 检查请求是否为指定内容类型：

```cj
r.post("/json-only", { ctx =>
    // 检查是否为 JSON
    if (!ctx.is("application/json")) {
        ctx.jsonWithCode(415u16,
            HashMap<String, String>([
            ("error", "Content-Type must be application/json")
        ])
        )
        return
    }

    // 处理 JSON 请求...
    let data = ctx.bindJson<HashMap<String, String>>()
    // ...
})
```

**常用检查**：

```cj
// 检查 JSON
if (ctx.is("application/json")) { /* ... */ }

// 检查表单
if (ctx.is("application/x-www-form-urlencoded")) { /* ... */ }

// 检查文件上传
if (ctx.is("multipart/form-data")) { /* ... */ }

// 检查文本
if (ctx.is("text/*")) { /* ... */ }
```

## 自定义存储

### 存储和读取数据

使用 `kvSet()` 和 `kvGet<T>()` 在请求上下文中存储和读取数据：

```cj
// 认证中间件：存储用户信息
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let token = ctx.cookie("token")

            match (token) {
                case Some(t) =>
if (validateToken(t)) {
                        let user = getUserFromToken(t)

                        // 存储到 context
                        ctx.kvSet("user", user)
                        ctx.kvSet("user_id", user.id)
                        ctx.kvSet("is_admin", user.isAdmin)

                        next(ctx)
                    } else {
                        ctx.jsonWithCode(401u16,
                            HashMap<String, String>([
            ("error", "Invalid token")
        ])
                        )
                    }
                case None =>
ctx.jsonWithCode(401u16,
                        HashMap<String, String>([
            ("error", "Missing token")
        ])
                    )
            }
        }
    }
}

// 在 Handler 中读取
r.get("/profile", { ctx =>
    let user = ctx.kvGet<User>("user")

    match (user) {
        case Some(u) =>
ctx.json(HashMap<String, String>([
                ("username", u.username),
                ("email", u.email)
            ]))
        case None =>
ctx.jsonWithCode(401u16,
                HashMap<String, String>([
            ("error", "Not authenticated")
        ])
            )
    }
})
```

**泛型支持**：

```cj
// 存储不同类型的数据
ctx.kvSet("request_id", generateID())           // String
ctx.kvSet("timestamp", DateTime.now())          // DateTime
ctx.kvSet("count", 42)                          // Int64
ctx.kvSet("user", user)                        // 自定义类型

// 读取时指定类型
let id = ctx.kvGet<String>("request_id")
let time = ctx.kvGet<DateTime>("timestamp")
let count = ctx.kvGet<Int64>("count")
let user = ctx.kvGet<User>("user")
```

> **💡 提示：`kvGet<T>()` vs `param()` 的区别**
>
> - **`kvGet<T>()`**：泛型方法，读取中间件存储的任意类型数据
> - **`param()`**：读取 URL 路径参数（String 类型）
>
> **`kvGet<T>()` vs 全局变量**：
> - **`kvGet<T>()`**：请求级别的数据，每个请求独立
> - **全局变量**：进程级别的数据，所有请求共享（线程安全问题）


## 请求头

### 获取请求头

使用 `getHeader()` 获取指定名称的请求头：

```cj
r.get("/headers", { ctx =>
    let userAgent = ctx.getHeader("User-Agent")
    let accept = ctx.getHeader("Accept")
    let auth = ctx.getHeader("Authorization")

    ctx.json(HashMap<String, String>([
        ("User-Agent", userAgent ?? ""),
        ("Accept", accept ?? ""),
        ("Authorization", auth ?? "")
    ]))
})
```

### 获取所有请求头

直接访问 `ctx.request.headers`：

```cj
r.get("/all-headers", { ctx =>
    let headers = HashMap<String, String>()

    for ((name, values) in ctx.request.headers) {
        // values 是 Collection<String>
        if (values.size > 0) {
            headers[name] = values[0]
        }
    }

    ctx.json(headers)
})
```

## 完整示例

### 请求信息调试端点

```cj
r.get("/debug/request", { ctx =>
    let info = HashMap<String, Any>()

    // 请求信息
    info["method"] = ctx.method()
    info["path"] = ctx.path()
    info["originalURL"] = ctx.originalURL()

    // URL 信息
    info["baseURL"] = ctx.baseURL()
    info["hostname"] = ctx.hostName()
    info["port"] = ctx.port()

    // 客户端信息
    info["ip"] = ctx.ip()
    info["ips"] = ctx.ips().toArray()
    info["secure"] = ctx.secure()

    // 协议信息
    info["protocol"] = "${ctx.protocolVersion()}"

    // 内容类型
    info["contentType"] = ctx.contentType() ?? ""

    // 请求头
    let headers = HashMap<String, String>()
    for ((name, values) in ctx.request.headers) {
        if (values.size > 0) {
            headers[name] = values[0]
        }
    }
    info["headers"] = headers

    ctx.json(info)
})
```

### IP 限制中间件

```cj
func ipWhitelist(allowedIPs: Array<String>): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let clientIP = ctx.ip()

            if (!allowedIPs.contains(clientIP)) {
                ctx.jsonWithCode(403u16,
                    HashMap<String, String>([
            ("error", "IP not allowed")
        ])
                )
                return
            }

            next(ctx)
        }
    }
}

// 使用 IP 白名单
let adminRoutes = r.group("/admin")
adminRoutes.use([ipWhitelist(["192.168.1.100", "10.0.0.1"])])

adminRoutes.get("/settings", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Admin settings")
        ]))
})
```

### 请求日志中间件

```cj
func requestLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let startTime = DateTime.now()

            // 存储开始时间
            ctx.kvSet("start_time", startTime)

            // 生成请求 ID
            let requestID = generateUUID()
            ctx.kvSet("request_id", requestID)

            // 打印请求信息
            println("[${requestID}] ${ctx.method()} ${ctx.path()} from ${ctx.ip()}")

            next(ctx)

            // 计算耗时
            let endTime = DateTime.now()
            let duration = endTime.toUnixTimeStamp() - startTime.toUnixTimeStamp()

            println("[${requestID}] Completed in ${duration}ms")
        }
    }
}
```

## API 参考

### 请求信息

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `method()` | `String` | 获取 HTTP 方法 |
| `path()` | `String` | 获取请求路径（考虑重写） |
| `originalURL()` | `String` | 获取完整原始 URL |

### URL 信息

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `baseURL()` | `String` | 获取基础 URL（协议 + 域名） |
| `hostName()` | `String` | 获取主机名 |
| `port()` | `UInt16` | 获取端口号 |

### 客户端信息

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `ip()` | `String` | 获取客户端 IP |
| `ips()` | `ArrayList<String>` | 获取代理链 IP 列表 |
| `secure()` | `Bool` | 检查是否为 HTTPS |

### 协议信息

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `protocolVersion()` | `Protocol` | 获取 HTTP 协议版本 |

### 内容类型

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `contentType()` | `?String` | 获取 Content-Type 头 |
| `is(contentType: String)` | `Bool` | 检查是否为指定内容类型 |
| `isType(contentType: String)` | `Bool` | 同 `is()` |

### 自定义存储

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `kvGet<T>(key: String)` | `?T` | 读取存储的数据 |
| `kvSet(key: String, value: Any)` | `Unit` | 存储数据 |

### 请求头

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `getHeader(key: String)` | `?String` | 获取指定请求头 |

## 注意事项

### 1. IP 地址欺骗

在反向代理场景下，`ip()` 可能不准确：

```cj
// ❌ 不安全：可能被伪造的 IP
let clientIP = ctx.ip()

// ✅ 安全：从 X-Forwarded-For 读取
let forwardedIPs = ctx.ips()
let clientIP = if (forwardedIPs.size > 0) {
    forwardedIPs[0]
} else {
    ctx.ip()
}
```

### 2. 类型转换

`kvGet<T>()` 需要正确的类型：

```cj
// 存储
ctx.kvSet("count", 42)  // Int64

// ❌ 错误：类型不匹配
let count = ctx.kvGet<String>("count")  // None

// ✅ 正确：使用正确的类型
let count = ctx.kvGet<Int64>("count")  // Some(42)
```

### 3. 大小写敏感

请求头名称大小写不敏感，但建议使用标准格式：

```cj
// ✅ 推荐：使用标准格式（每个单词首字母大写）
ctx.getHeader("User-Agent")
ctx.getHeader("Content-Type")

// 也可以使用小写（内部会自动匹配）
ctx.getHeader("user-agent")  // ✅ 有效

// ❌ 避免使用其他格式
ctx.getHeader("USER-AGENT")  // 虽然有效，但不推荐
```

## 相关链接

- **[请求处理](request.md)** - 读取请求参数和体
- **[响应操作](response.md)** - 发送响应
- **[Cookie 操作](cookie.md)** - Cookie 读写
- **[源码](../../src/context_request.cj)** - 辅助方法源代码
