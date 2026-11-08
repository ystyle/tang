

> **本分支说明**：HttpStatusCode.* 现在是 UInt16 常量（原来来自 stdx），可直接传给 status(...)。

> **本分支变更**：`ctx.json(v)` 的编码实现不再内置，需要先注册 JSON codec
> （如 `useSeaJson()`，见 `tang_ext_json_seajson`）。核心保持零 stdx。
> 未注册时调用会抛异常并提示。

# 响应操作

## 概述

TangHttpContext 提供了 Fiber 风格的链式 API 用于设置 HTTP 响应，包括状态码、响应头、JSON、字符串、文件下载等功能。

**核心特性**：
- **链式调用**：所有方法都返回 `TangHttpContext`，支持流畅的链式调用
- **类型化响应**：内置 JSON、字符串、文件下载等常用响应类型
- **状态码管理**：快捷方法设置常用 HTTP 状态码
- **重定向支持**：内置 301/302/303/307/308 重定向

## 链式调用

Tang 的响应 API 支持链式调用，让代码更简洁优雅：

```cj
r.get("/users", { ctx =>
    ctx.status(200)
        .set("Content-Type", "application/json")
        .set("X-Custom-Header", "value")
        .json(HashMap<String, String>([
            ("message", "Success")
        ]))
})
```

> **💡 提示：链式调用原理**
>
> 每个方法都返回 `TangHttpContext` 自身，允许连续调用多个方法：
>
> ```cj
> public func status(code: UInt16): TangHttpContext {
>     this.responseBuilder.status(code)
>     return this  // 返回自身
> }
> ```
>
> **终结方法**：`json()`, `sendStatus()`, `redirect()`, `writeString()` 会结束响应


## 状态码

### 设置状态码

使用 `status()` 方法设置 HTTP 状态码（链式调用）：

```cj
r.get("/ok", { ctx =>
    ctx.status(200u16).json(HashMap<String, String>([
        ("message", "OK")
    ]))
})

r.get("/not-found", { ctx =>
    ctx.status(404u16).json(HashMap<String, String>([
        ("error", "Not Found")
    ]))
})

r.get("/server-error", { ctx =>
    ctx.status(500u16).json(HashMap<String, String>([
        ("error", "Internal Server Error")
    ]))
})
```

### 快捷方法：发送状态码

使用 `sendStatus()` 快速发送状态码（终结方法）：

```cj
r.get("/no-content", { ctx =>
    ctx.sendStatus(204u16)  // 204 No Content
})

r.get("/bad-request", { ctx =>
    ctx.sendStatus(400u16)  // 400 Bad Request
})
```

### 常用状态码常量

Tang 提供了 `HttpStatusCode` 类中的标准状态码：

```cj
import stdx.net.http.HttpStatusCode

r.get("/created", { ctx =>
    ctx.status(HttpStatusCode.STATUS_CREATED).json(...)
})

r.get("/unauthorized", { ctx =>
    ctx.status(HttpStatusCode.STATUS_UNAUTHORIZED).json(...)
})

r.get("/forbidden", { ctx =>
    ctx.status(HttpStatusCode.STATUS_FORBIDDEN).json(...)
})

r.get("/not-found", { ctx =>
    ctx.status(HttpStatusCode.STATUS_NOT_FOUND).json(...)
})
```

**常用状态码**：

| 状态码 | 常量 | 描述 |
|--------|------|------|
| 200 | `STATUS_OK` | 请求成功 |
| 201 | `STATUS_CREATED` | 资源创建成功 |
| 204 | `STATUS_NO_CONTENT` | 请求成功，无返回内容 |
| 301 | `STATUS_MOVED_PERMANENTLY` | 永久重定向 |
| 302 | `STATUS_FOUND` | 临时重定向 |
| 304 | `STATUS_NOT_MODIFIED` | 资源未修改 |
| 400 | `STATUS_BAD_REQUEST` | 请求错误 |
| 401 | `STATUS_UNAUTHORIZED` | 未授权 |
| 403 | `STATUS_FORBIDDEN` | 禁止访问 |
| 404 | `STATUS_NOT_FOUND` | 资源未找到 |
| 500 | `STATUS_INTERNAL_SERVER_ERROR` | 服务器内部错误 |

## 响应头

### 设置响应头

使用 `set()` 方法设置响应头（链式调用）：

```cj
r.get("/custom", { ctx =>
    ctx.status(200u16)
        .set("Content-Type", "application/json")
        .set("X-Custom-Header", "custom-value")
        .set("X-Request-ID", "123456")
        .json(HashMap<String, String>([
            ("message", "Headers set")
        ]))
})
```

### 追加响应头

使用 `append()` 方法追加响应头（链式调用）：

```cj
r.get("/multiple", { ctx =>
    ctx.status(200u16)
        .append("Set-Cookie", "token=abc123; Path=/; HttpOnly")
        .append("Set-Cookie", "theme=dark; Path=/")
        .json(HashMap<String, String>([
            ("message", "Cookies set")
        ]))
})
```

### 设置 Content-Type

使用 `contentType()` 快捷方法设置 Content-Type（链式调用）：

```cj
r.get("/html", { ctx =>
    ctx.status(200u16)
        .contentType("text/html; charset=utf-8")
        .writeString("<h1>Hello, World!</h1>")
})

r.get("/data", { ctx =>
    ctx.status(200u16)
        .contentType("application/json")
        .json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

> **💡 提示：`set()` vs `append()` 的区别**
>
> - **`set()`**：覆盖已存在的同名 header（如 `Content-Type`）
> - **`append()`**：添加多个同名 header（如 `Set-Cookie`）
>
> **示例**：对于同一个 header 名称：
```cj
.set("X-Custom", "value1")     // 只有一个 X-Custom: value1
.set("X-Custom", "value2")     // 被覆盖为 value2

.append("Set-Cookie", "a=1")   // Set-Cookie: a=1
.append("Set-Cookie", "b=2")   // Set-Cookie: b=2  (两个 cookie)
```


## JSON 响应

### 发送 JSON

使用 `json()` 方法发送 JSON 响应（默认 200 状态码，终结方法）：

```cj
r.get("/user", { ctx =>
    ctx.json(HashMap<String, String>([
        ("id", "1"),
        ("name", "Alice"),
        ("email", "alice@example.com")
    ]))
})

r.get("/users", { ctx =>
    let users = ArrayList<HashMap<String, String>>()
    users.add(HashMap<String, String>([
        ("id", "1"),
        ("name", "Alice")
    ]))
    users.add(HashMap<String, String>([
        ("id", "2"),
        ("name", "Bob")
    ]))

    ctx.json(users)
})
```

### 发送带状态码的 JSON

使用 `jsonWithCode()` 发送带自定义状态码的 JSON（终结方法）：

```cj
r.post("/users", { ctx =>
    // 创建用户逻辑...

    ctx.jsonWithCode(201u16, HashMap<String, String>([
        ("message", "User created"),
        ("userId", "123")
    ]))
})

r.get("/not-found", { ctx =>
    ctx.jsonWithCode(404u16, HashMap<String, String>([
        ("error", "Resource not found")
    ]))
})
```

### JSON 序列化

Tang 使用仓颉的 `JsonSerializable` 接口自动序列化对象：

```cj
import stdx.encoding.json.stream.JsonSerializable

class User <: JsonSerializable {
    let id: String
    let name: String
    let email: String

    public init(id: String, name: String, email: String) {
        this.id = id
        this.name = name
        this.email = email
    }

    public func toJson(writer: JsonWriter): Unit {
        writer.writeObjectStart()
        writer.writeStringKey("id")
        writer.writeString(this.id)
        writer.writeStringKey("name")
        writer.writeString(this.name)
        writer.writeStringKey("email")
        writer.writeString(this.email)
        writer.writeObjectEnd()
    }
}

r.get("/user", { ctx =>
    let user = User("1", "Alice", "alice@example.com")
    ctx.json(user)
})
```

## 字符串响应

### 发送字符串

使用 `writeString()` 方法发送字符串响应（默认 200 状态码，终结方法）：

```cj
r.get("/text", { ctx =>
    ctx.writeString("Hello, World!")
})

r.get("/html", { ctx =>
    ctx.writeString("<h1>Hello, Tang!</h1><p>Welcome to the framework.</p>")
})
```

### 发送带状态码的字符串

使用 `writeStringWithCode()` 发送带自定义状态码的字符串（终结方法）：

```cj
r.get("/error", { ctx =>
    ctx.writeStringWithCode(500u16, "Internal Server Error")
})

r.get("/custom", { ctx =>
    ctx.writeStringWithCode(418u16, "I'm a teapot")
})
```

### 发送原始字节

使用 `write()` 方法发送字节数组：

```cj
r.get("/binary", { ctx =>
    let data = Array<UInt8>([0x48, 0x65, 0x6c, 0x6c, 0x6f])  // "Hello"
    ctx.write(data)
})
```

## 文件下载

### 下载文件

使用 `download()` 方法下载文件（终结方法）：

```cj
import std.fs.Path

r.get("/download/pdf", { ctx =>
    let filePath = Path("/path/to/document.pdf")
    ctx.download(filePath)
})

r.get("/download/image", { ctx =>
    let imagePath = Path("/var/www/images/photo.jpg")
    ctx.download(imagePath)
})
```

### 设置下载文件名

使用 `attachment()` 设置 Content-Disposition 响应头（链式调用）：

```cj
r.get("/export", { ctx =>
    let data = generateCSV()  // 假设生成 CSV 数据

    ctx.status(200u16)
        .attachment("export-data.csv")
        .contentType("text/csv")
        .writeString(data)
})
```

> **💡 提示：`download()` vs `attachment()` 的区别**
>
> - **`download()`**：读取文件并直接返回给客户端（终结方法）
> - **`attachment()`**：设置 `Content-Disposition: attachment` 响应头（链式方法）

`attachment()` 需要配合其他方法使用：
```cj
// 下载静态文件
ctx.download(Path("/files/report.pdf"))

// 生成文件并下载
ctx.attachment("report.pdf")
   .contentType("application/pdf")
   .writeString(generatedPDFContent)
```


## 重定向

### 基础重定向（302）

使用 `redirect()` 方法重定向到指定路径（默认 302 状态码，终结方法）：

```cj
r.get("/old-path", { ctx =>
    ctx.redirect("/new-path")  // 302 Found
})

r.get("/login", { ctx =>
    if (!isAuthenticated(ctx)) {
        ctx.redirect("/login-form")
        return
    }
    // 处理已认证的逻辑...
})
```

### 带状态码的重定向

使用 `redirectWithStatus()` 方法指定重定向状态码（终结方法）：

```cj
r.get("/moved-permanently", { ctx =>
    // 301 Moved Permanently（永久重定向）
    ctx.redirectWithStatus("/new-location", 301u16)
})

r.get("/see-other", { ctx =>
    // 303 See Other
    ctx.redirectWithStatus("/result", 303u16)
})

r.get("/temporary-redirect", { ctx =>
    // 307 Temporary Redirect
    ctx.redirectWithStatus("/temp", 307u16)
})
```

### 重定向状态码说明

| 状态码 | 常量 | 描述 | 使用场景 |
|--------|------|------|----------|
| 301 | `STATUS_MOVED_PERMANENTLY` | 永久重定向 | 资源永久移动 |
| 302 | `STATUS_FOUND` | 临时重定向 | 临时重定向（默认） |
| 303 | `STATUS_SEE_OTHER` | 查看其他 | POST 后重定向到 GET |
| 307 | `STATUS_TEMPORARY_REDIRECT` | 临时重定向（保持方法） | 重定向但保持 HTTP 方法 |
| 308 | `STATUS_PERMANENT_REDIRECT` | 永久重定向（保持方法） | 永久重定向但保持 HTTP 方法 |

**示例：POST-Redirect-GET 模式**：

```cj
r.post("/create", { ctx =>
    // 创建资源...

    // 303 重定向：浏览器会自动将 POST 改为 GET
    ctx.redirectWithStatus("/resources/123", 303u16)
})
```

## 完整示例

### REST API 响应

```cj
import stdx.net.http.HttpStatusCode

main() {
    let r = Router()

    // 成功响应
    r.get("/users", { ctx =>
        let users = fetchUsers()  // 假设从数据库获取
        ctx.status(HttpStatusCode.STATUS_OK)
            .json(users)
    })

    // 创建成功（201）
    r.post("/users", { ctx =>
        let user = createUser(ctx.bodyRaw())
        ctx.jsonWithCode(HttpStatusCode.STATUS_CREATED, user)
    })

    // 无内容（204）
    r.delete("/users/:id", { ctx =>
        deleteUser(ctx.param("id"))
        ctx.sendStatus(HttpStatusCode.STATUS_NO_CONTENT)
    })

    // 客户端错误（400）
    r.post("/invalid", { ctx =>
        ctx.jsonWithCode(HttpStatusCode.STATUS_BAD_REQUEST,
            HashMap<String, String>([
                ("error", "Invalid request data")
            ])
        )
    })

    // 未授权（401）
    r.get("/protected", { ctx =>
        ctx.jsonWithCode(HttpStatusCode.STATUS_UNAUTHORIZED,
            HashMap<String, String>([
                ("error", "Authentication required")
            ])
        )
    })

    // 未找到（404）
    r.get("/not-found", { ctx =>
        ctx.jsonWithCode(HttpStatusCode.STATUS_NOT_FOUND,
            HashMap<String, String>([
                ("error", "Resource not found")
            ])
        )
    })

    // 服务器错误（500）
    r.get("/error", { ctx =>
        ctx.jsonWithCode(HttpStatusCode.STATUS_INTERNAL_SERVER_ERROR,
            HashMap<String, String>([
                ("error", "Internal server error")
            ])
        )
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 链式调用示例

```cj
r.get("/complex", { ctx =>
    ctx.status(200u16)
        .set("Content-Type", "application/json")
        .set("X-API-Version", "1.0")
        .set("X-Request-ID", generateRequestID())
        .json(HashMap<String, String>([
            ("message", "Complex response"),
            ("data", "value")
        ]))
})
```

### 文件下载示例

```cj
import std.fs.Path

r.get("/downloads/:filename", { ctx =>
    let filename = ctx.param("filename")
    let filePath = Path("/var/www/downloads/${filename}")

    if (fileExists(filePath)) {
        ctx.status(200u16)
            .set("Content-Type", "application/octet-stream")
            .attachment(filename)
            .download(filePath)
    } else {
        ctx.jsonWithCode(404u16,
            HashMap<String, String>([
                ("error", "File not found")
            ])
        )
    }
})
```

### 重定向示例

```cj
// 简短域名重定向
r.get("/short/:code", { ctx =>
    let url = lookupURL(ctx.param("code"))

    match (url) {
        case Some(longUrl) =>
            // 301 永久重定向（SEO 友好）
            ctx.redirectWithStatus(longUrl, 301u16)
        case None =>
            ctx.jsonWithCode(404u16,
                HashMap<String, String>([
                    ("error", "Short URL not found")
                ])
            )
    }
})

// 登录后重定向
r.post("/login", { ctx =>
    let creds = ctx.bindJson<Credentials>()

    if (authenticate(creds)) {
        // 303 重定向：浏览器会自动将 POST 改为 GET
        ctx.redirectWithStatus("/dashboard", 303u16)
    } else {
        ctx.jsonWithCode(401u16,
            HashMap<String, String>([
            ("error", "Invalid credentials")
        ])
        )
    }
})
```

## API 参考

### 状态码方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `status(code: UInt16)` | `TangHttpContext` | 设置状态码（链式） |
| `sendStatus(code: UInt16)` | `Unit` | 发送状态码（终结） |

### 响应头方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `set(key: String, value: String)` | `TangHttpContext` | 设置响应头（链式） |
| `append(key: String, value: String)` | `TangHttpContext` | 追加响应头（链式） |
| `contentType(contentType: String)` | `TangHttpContext` | 设置 Content-Type（链式） |
| `attachment(filename: String)` | `TangHttpContext` | 设置下载文件名（链式） |

### JSON 方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `json<T>(value: T)` | `Unit` | 发送 JSON（200，终结） |
| `jsonWithCode<T>(code: UInt16, value: T)` | `Unit` | 发送 JSON（自定义状态码，终结） |

### 字符串方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `writeString<T>(value: T)` | `Unit` | 发送字符串（200，终结） |
| `writeStringWithCode<T>(code: UInt16, value: T)` | `Unit` | 发送字符串（自定义状态码，终结） |
| `write(bs: Array<Byte>)` | `Unit` | 发送字节数组（终结） |

### 重定向方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `redirect(location: String)` | `Unit` | 重定向（302，终结） |
| `redirectWithStatus(location: String, code: UInt16)` | `Unit` | 重定向（自定义状态码，终结） |

### 文件方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `download(path: Path)` | `Unit` | 下载文件（终结） |

## 注意事项

### 1. 链式调用 vs 终结方法

链式方法（返回 `TangHttpContext`）可以继续调用，终结方法（返回 `Unit`）会结束响应：

```cj
// ✅ 链式调用
ctx.status(200u16)
   .set("Content-Type", "application/json")
   .json(HashMap<String, String>([
            ("data", "value")
        ]))

// ❌ 错误：在终结方法后继续调用
ctx.json(data)
   .status(200u16)  // 编译错误！json() 已经返回 Unit
```

### 2. 只能发送一次响应

每个请求只能发送一次响应：

```cj
// ❌ 错误：多次发送响应
r.get("/error", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "First")
        ]))
    ctx.json(HashMap<String, String>([
            ("message", "Second")
        ]))  // 无效
})

// ✅ 正确：使用 return 或提前结束
r.get("/correct", { ctx =>
    if (!isValid()) {
        ctx.status(400u16).json(HashMap<String, String>([
            ("error", "Invalid")
        ]))
        return
    }
    ctx.json(HashMap<String, String>([
            ("message", "Success")
        ]))
})
```

### 3. Content-Type 自动设置

`json()` 方法会自动设置 `Content-Type: application/json`：

```cj
// json() 自动设置 Content-Type
ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
// Content-Type: application/json

// 如果需要自定义，手动设置
ctx.set("Content-Type", "application/vnd.api+json")
   .json(HashMap<String, String>([
            ("data", "value")
        ]))
```

### 4. 状态码类型

状态码必须使用 `u16` 类型（无符号 16 位整数）：

```cj
// ✅ 正确
ctx.status(200u16)
ctx.status(HttpStatusCode.STATUS_OK)  // HttpStatusCode 本身就是 UInt16

// ❌ 错误
ctx.status(200)  // 编译错误：类型不匹配
```

## 相关链接

- **[请求处理](request.md)** - 读取请求的方法
- **[Cookie 操作](cookie.md)** - Cookie 读写方法
- **[辅助方法](utils.md)** - 请求信息获取方法
- **[源码](../../src/context_response.cj)** - 响应操作源代码
