# Tang Chainable API 使用指南

本文档展示了 Tang 框架中新增的 Fiber 风格链式 API 的使用方法。

## 概述

Tang 现在支持 Fiber 风格的链式 API，同时保持原有的方法不变。这些新 API 使用 Cangjie 的 `extend` 语法实现，分布在多个文件中：

- `src/context_response.cj` - 响应操作 API
- `src/context_request.cj` - 请求信息增强 API
- `src/context_cookie.cj` - Cookie 操作 API

## 1. 响应操作 (Response Operations)

### 1.1 设置状态码和响应头（链式调用）

```cj
import tang.*

main() {
    let app = Tang()

    app.get("/chain") { ctx =>
        // 链式调用示例
        ctx.status(200)
           .set("Content-Type", "application/json")
           .set("X-Custom-Header", "value")
           .writeString("{\"message\":\"Hello\"}")
    }

    app.start(8080)
}
```

### 1.2 设置 Content-Type

```cj
app.get("/json") { ctx =>
    ctx.contentType("application/json")
       .writeString("{\"data\":123}")
}

app.get("/html") { ctx =>
    ctx.type("text/html")  // type 是 contentType 的别名
       .writeString("<h1>Hello</h1>")
}
```

### 1.3 发送状态码

```cj
app.get("/unauthorized") { ctx =>
    ctx.sendStatus(401)  // 终结方法，返回空响应体
}

app.get("/not-found") { ctx =>
    ctx.sendStatus(404)
}
```

### 1.4 重定向

```cj
app.get("/redirect") { ctx =>
    ctx.redirect("https://example.com")  // 默认 302 状态码
}

app.get("/moved") { ctx =>
    ctx.redirectWithStatus("/new-location", 301)  // 指定状态码
}
```

### 1.5 附件下载

```cj
app.get("/download") { ctx =>
    ctx.attachment("report.pdf")
       .set("Content-Type", "application/pdf")
       .write(fileBytes)
}
```

### 1.6 完整链式调用示例

```cj
app.post("/api/users") { ctx =>
    ctx.status(201)
       .set("Content-Type", "application/json")
       .set("X-Response-Time", "10ms")
       .writeString("{\"id\":123,\"name\":\"John\"}")
}
```

## 2. 请求信息增强 (Request Information)

### 2.1 获取请求方法、路径和协议

```cj
app.all("/info") { ctx =>
    let method = ctx.method()        // "GET", "POST", etc.
    let path = ctx.path()            // "/info"
    let protocol = ctx.protocolVersion()  // Protocol.HTTP1_1

    println("Method: ${method}")
    println("Path: ${path}")
    println("Protocol: ${protocol}")

    ctx.writeString("Request: ${method} ${path}")
}
```

### 2.2 获取端口号

```cj
app.get("/port") { ctx =>
    let port = ctx.port()  // 自动从 URL 或协议获取默认端口
    ctx.writeString("Port: ${port}")
}
```

### 2.3 检查内容类型

```cj
app.post("/data") { ctx =>
    if (ctx.is("application/json")) {
        // 处理 JSON 数据
        let data = ctx.bindJson<MyData>()
        // ...
    } else if (ctx.isType("text/plain")) {
        // 处理纯文本
        let text = String.fromUtf8(ctx.bodyRaw())
        // ...
    }
}
```

### 2.4 检查 HTTPS

```cj
app.get("/secure-check") { ctx =>
    if (ctx.secure()) {
        ctx.writeString("This is a secure HTTPS connection")
    } else {
        ctx.writeString("This is NOT secure")
    }
}
```

### 2.5 获取原始 URL

```cj
app.all("/") { ctx =>
    let originalURL = ctx.originalURL()
    // 例如: "https://example.com/path?query=value"
    ctx.writeString("Original URL: ${originalURL}")
}
```

## 3. Cookie 操作 (Cookie Operations)

Tang 使用 Cangjie 原生的 `stdx.net.http.Cookie` 类，无需自定义实现。

### 3.1 获取 Cookie

```cj
app.get("/get-cookie") { ctx =>
    if (let Some(value) <- ctx.cookie("username")) {
        ctx.writeString("Username: ${value}")
    } else {
        ctx.writeString("Cookie not found")
    }
}
```

### 3.2 设置 Cookie（使用原生 Cookie）

```cj
import stdx.net.http.Cookie

app.post("/set-cookie") { ctx =>
    // 使用原生 Cookie 类
    let cookie = Cookie(
        "username",
        "john",
        maxAge: Some(3600),
        path: "/",
        secure: true,
        httpOnly: true
    )
    ctx.setCookie(cookie)
       .writeString("Cookie set successfully")
}
```

### 3.3 快捷设置简单 Cookie

```cj
app.get("/simple-cookie") { ctx =>
    ctx.setSimpleCookie("session", "abc123")
       .writeString("Session cookie set")
}
```

### 3.4 清除 Cookie

```cq
app.get("/clear-cookie") { ctx =>
    ctx.clearCookie("username")
       .writeString("Cookie cleared")
}
```

### 3.5 获取所有 Cookies

```cj
app.get("/cookies") { ctx =>
    let allCookies = ctx.cookies()

    var output = "Cookies:\n"
    for ((name, value) in allCookies) {
        output += "  ${name} = ${value}\n"
    }

    ctx.writeString(output)
}
```

## 4. 综合示例：用户登录 API

```cj
import stdx.net.http.{HttpStatusCode, Cookie}
import stdx.crypto.hash.sha256

main() {
    let app = Tang()

    // 用户登录
    app.post("/api/login") { ctx =>
        // 检查内容类型
        if (!ctx.is("application/json")) {
            ctx.status(400)
               .sendStatus(HttpStatusCode.STATUS_BAD_REQUEST)
            return
        }

        // 获取请求数据
        let path = ctx.path()
        let method = ctx.method()

        // 解析 JSON
        if (let Some(data) <- ctx.bindJson<LoginRequest>()) {
            // 验证用户（示例）
            if (data.username == "admin" && data.password == "password") {
                // 设置 Cookie
                let sessionCookie = Cookie(
                    "session",
                    generateSessionId(),
                    maxAge: Some(3600),
                    path: "/",
                    httpOnly: true,
                    secure: ctx.secure()
                )

                ctx.status(200)
                   .set("Content-Type", "application/json")
                   .setCookie(sessionCookie)
                   .writeString("{\"success\":true,\"message\":\"Login successful\"}")
            } else {
                ctx.status(401)
                   .sendStatus(HttpStatusCode.STATUS_UNAUTHORIZED)
            }
        }
    }

    // 用户登出
    app.post("/api/logout") { ctx =>
        ctx.clearCookie("session")
           .status(200)
           .contentType("application/json")
           .writeString("{\"success\":true,\"message\":\"Logged out\"}")
    }

    // 获取用户信息
    app.get("/api/user") { ctx =>
        if (let Some(session) <- ctx.cookie("session")) {
            // 验证 session 并返回用户信息
            ctx.status(200)
               .type("application/json")
               .writeString("{\"user\":\"admin\",\"role\":\"administrator\"}")
        } else {
            ctx.status(401)
               .sendStatus(HttpStatusCode.STATUS_UNAUTHORIZED)
        }
    }

    app.start(8080)
}

class LoginRequest {
    var username: String = ""
    var password: String = ""
}

func generateSessionId(): String {
    // 生成随机 session ID（示例）
    return "session_" + DateTime.now().toMilliSeconds().toString()
}
```

## 5. API 参考

### 5.1 响应操作 API

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `status(code: UInt16)` | `TangHttpContext` | 设置 HTTP 状态码（链式） |
| `set(key: String, value: String)` | `TangHttpContext` | 设置响应头（链式） |
| `append(key: String, value: String)` | `TangHttpContext` | 追加响应头（链式） |
| `contentType(contentType: String)` | `TangHttpContext` | 设置 Content-Type（链式） |
| `type(contentType: String)` | `TangHttpContext` | Content-Type 的别名（链式） |
| `sendStatus(code: UInt16)` | `Unit` | 发送状态码响应（终结） |
| `redirect(location: String)` | `Unit` | 重定向（默认 302，终结） |
| `redirectWithStatus(location: String, code: UInt16)` | `Unit` | 重定向并指定状态码（终结） |
| `attachment(filename: String)` | `TangHttpContext` | 设置附件下载响应头（链式） |

### 5.2 请求信息 API

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `method()` | `String` | 获取 HTTP 方法（如 "GET"） |
| `path()` | `String` | 获取请求路径 |
| `protocolVersion()` | `Protocol` | 获取协议版本枚举 |
| `port()` | `UInt16` | 获取端口号 |
| `isType(contentType: String)` | `Bool` | 检查是否是指定内容类型 |
| `is(contentType: String)` | `Bool` | `isType` 的别名 |
| `secure()` | `Bool` | 检查是否是 HTTPS |
| `originalURL()` | `String` | 获取完整原始 URL |

### 5.3 Cookie 操作 API

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `cookie(name: String)` | `?String` | 获取指定 Cookie 的值 |
| `setCookie(cookie: Cookie)` | `TangHttpContext` | 设置 Cookie（使用原生 Cookie） |
| `setSimpleCookie(name: String, value: String)` | `TangHttpContext` | 快捷设置简单 Cookie |
| `clearCookie(name: String)` | `TangHttpContext` | 清除指定 Cookie |
| `cookies()` | `HashMap<String, String>` | 获取所有 Cookies |

## 6. 设计说明

### 6.1 混合模式

Tang 采用混合模式设计：
- **保留原有方法**：如 `json()`、`writeString()` 等返回 `Unit` 的方法保持不变
- **新增链式方法**：如 `status()`、`set()` 等返回 `TangHttpContext` 的方法支持链式调用
- **兼容性**：两种方式可以自由混用

### 6.2 使用原生类型

- 使用 Cangjie 原生的 `stdx.net.http.Cookie` 类，无需重新实现
- `protocolVersion()` 返回 `Protocol` 枚举类型，而非字符串
- 所有方法都与 Cangjie 标准库深度集成

### 6.3 extend 语法

使用 `extend` 语法将功能分散到多个文件中，提高代码可维护性：

```cj
// src/context_response.cj
extend TangHttpContext {
    // 响应相关方法
}

// src/context_request.cj
extend TangHttpContext {
    // 请求相关方法
}

// src/context_cookie.cj
extend TangHttpContext {
    // Cookie 相关方法
}
```

## 7. 注意事项

1. **关键字冲突**：`type` 和 `is` 是 Cangjie 关键字，使用反引号包裹：`` `type`() `` 和 `` `is`() ``
2. **链式调用**：只有返回 `TangHttpContext` 的方法才能继续链式调用
3. **终结方法**：返回 `Unit` 的方法（如 `sendStatus()`、`redirect()`）会结束响应处理
4. **Cookie 安全**：生产环境建议设置 `secure: true` 和 `httpOnly: true`
