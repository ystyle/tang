

> **本分支说明**：Cookie 类型已换成 tang.Cookie（与 stdx 同形），setCookie/setSimpleCookie 用法不变。

# Cookie 操作

## 概述

TangHttpContext 提供了完整的 Cookie 操作方法，支持读取请求中的 Cookie 和设置响应中的 Cookie。使用仓颉原生的 `stdx.net.http.Cookie` 类型。

**核心功能**：
- **读取 Cookie**：从请求头中解析 Cookie
- **设置 Cookie**：向响应中添加 Set-Cookie 头
- **清除 Cookie**：通过设置过期时间清除 Cookie
- **链式调用**：所有设置方法都支持链式调用

> **💡 提示：Cookie 的基本概念**
>
> - **Cookie**：服务器发送到浏览器的小段数据
> - **Set-Cookie 响应头**：服务器告诉浏览器保存 Cookie
> - **Cookie 请求头**：浏览器发送 Cookie 到服务器
> - **属性**：name, value, domain, path, expires, max-age, secure, httpOnly, sameSite


## 读取 Cookie

### 获取单个 Cookie

使用 `cookie()` 方法获取指定名称的 Cookie 值：

```cj
r.get("/profile", { ctx =>
    let token = ctx.cookie("token")

    match (token) {
        case Some(t) =>
            // 验证 token 并返回用户信息
            ctx.json(HashMap<String, String>([
                ("message", "Authenticated")
            ]))
        case None => 
            // 没有 token，返回 401
            ctx.jsonWithCode(401u16,
                HashMap<String, String>([
                    ("error", "Authentication required")
                ])
            )
    }
})
```

### 获取所有 Cookies

使用 `cookies()` 方法获取所有 Cookie（返回 `HashMap<String, String>`）：

```cj
r.get("/debug/cookies", { ctx =>
    let allCookies = ctx.cookies()

    // allCookies = {
    //   "token": "abc123",
    //   "theme": "dark",
    //   "language": "zh-CN"
    // }

    ctx.json(allCookies)
})
```

## 设置 Cookie

### 快捷方法：设置简单 Cookie

使用 `setSimpleCookie()` 快速设置简单的 Cookie（链式调用）：

```cj
r.post("/login", { ctx =>
    // 验证用户...
    let userToken = generateToken()

    ctx.status(200u16)
        .setSimpleCookie("token", userToken)
        .json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})
```

### 完整方法：设置自定义 Cookie

使用仓颉原生的 `Cookie` 类型设置完整属性的 Cookie（链式调用）：

```cj
import stdx.net.http.Cookie

r.post("/login", { ctx =>
    let token = generateToken()

    // 创建 Cookie 对象
    let cookie = Cookie(
        name: "token",
        value: token,
        domain: Some("example.com"),    // Cookie 所属域
        path: Some("/"),                 // Cookie 有效路径
        maxAge: Some(3600),              // 有效期（秒）= 1 小时
        secure: true,                    // 仅 HTTPS
        httpOnly: true,                  // 禁止 JavaScript 访问
        sameSite: Some(CookieSameSite.Strict)  // SameSite 策略
    )

    ctx.status(200u16)
        .setCookie(cookie)
        .json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})
```

### Cookie 属性说明

#### `domain` - 所属域

指定 Cookie 有效的域：

```cj
let cookie = Cookie(
    name: "session",
    value: "abc123",
    domain: Some(".example.com")  // example.com 和所有子域名
)

// 子域名也会发送 Cookie
// www.example.com ✅
// api.example.com ✅
// other.com ❌
```

#### `path` - 有效路径

指定 Cookie 有效的路径：

```cj
let cookie = Cookie(
    name: "token",
    value: "xyz",
    path: Some("/api")  // 仅在 /api 路径下有效
)

// 以下请求会发送 Cookie：
// GET /api/users ✅
// POST /api/posts ✅
// GET /home ❌
```

#### `maxAge` - 最大有效期

指定 Cookie 的有效期（秒）：

```cj
let cookie1 = Cookie(
    name: "session",
    value: "abc",
    maxAge: Some(3600)  // 1 小时后过期
)

let cookie2 = Cookie(
    name: "permanent",
    value: "xyz",
    maxAge: Some(31536000)  // 1 年后过期
)

let cookie3 = Cookie(
    name: "temporary",
    value: "temp",
    maxAge: None  // 会话 Cookie，浏览器关闭后过期
)
```

#### `expires` - 过期时间

使用 `DateTime` 指定具体过期时间（替代 `maxAge`）：

```cj
import std.time.DateTime

let expirationTime = DateTime.now().addDays(7)  // 7 天后

let cookie = Cookie(
    name: "remember",
    value: "yes",
    expires: Some(expirationTime)  // 7 天后过期
)
```

#### `secure` - 安全标志

指定 Cookie 仅通过 HTTPS 传输：

```cj
let secureCookie = Cookie(
    name: "token",
    value: "sensitive-data",
    secure: true  // 仅 HTTPS 传输
)
```

**安全建议**：包含敏感信息的 Cookie（如 token、session）必须设置 `secure: true`。

#### `httpOnly` - HTTP Only 标志

禁止 JavaScript 访问 Cookie（防止 XSS 攻击）：

```cj
let httpOnlyCookie = Cookie(
    name: "session",
    value: "session-id",
    httpOnly: true  // document.cookie 无法访问
)
```

**安全建议**：认证相关的 Cookie 必须设置 `httpOnly: true`。

#### `sameSite` - SameSite 策略

控制跨站请求时是否发送 Cookie（防止 CSRF 攻击）：

```cj
import stdx.net.http.{Cookie, CookieSameSite}

let strictCookie = Cookie(
    name: "token",
    value: "abc",
    sameSite: Some(CookieSameSite.Strict)  // 仅同站请求
)

let laxCookie = Cookie(
    name: "theme",
    value: "dark",
    sameSite: Some(CookieSameSite.Lax)  // 同站 + 顶级导航
)

let noneCookie = Cookie(
    name: "tracking",
    value: "id",
    sameSite: Some(CookieSameSite.None),  // 总是发送（需要 secure: true）
    secure: true  // SameSite=None 必须配合 secure
)
```

**SameSite 策略对比**：

| 策略 | 描述 | 使用场景 |
|------|------|----------|
| `Strict` | 仅同站请求发送 Cookie | 高安全要求（银行、支付） |
| `Lax` | 同站请求 + 顶级导航发送 | 默认推荐值 |
| `None` | 跨站请求也发送 Cookie | 跨站集成（需要 secure: true） |

> **💡 提示：Cookie 安全最佳实践**
>
> **1. 敏感 Cookie**（session, token）：
> - `httpOnly: true`（防止 XSS）
> - `secure: true`（仅 HTTPS）
> - `sameSite: Strict` 或 `Lax`（防止 CSRF）
> - 短 `maxAge`（1-2 小时）
>
> **2. 非敏感 Cookie**（theme, language）：
> - 可省略 `httpOnly`（允许 JS 访问）
> - 长 `maxAge`（1 年）
> - `sameSite: Lax`


## 清除 Cookie

### 清除指定 Cookie

使用 `clearCookie()` 方法清除 Cookie（链式调用）：

```cj
r.post("/logout", { ctx =>
    // 清除 session Cookie
    ctx.status(200u16)
        .clearCookie("session")
        .clearCookie("token")
        .json(HashMap<String, String>([
            ("message", "Logout successful")
        ]))
})
```

**原理**：`clearCookie()` 设置 `maxAge=0`，使 Cookie 立即过期。

### 手动清除 Cookie（自定义）

如果需要清除特定域/路径的 Cookie，手动创建过期 Cookie：

```cj
import stdx.net.http.Cookie

r.post("/logout", { ctx =>
    let expiredCookie = Cookie(
        name: "session",
        value: "",
        maxAge: Some(0),        // 立即过期
        path: Some("/"),        // 必须匹配原 Cookie 的 path
        domain: Some(".example.com")  // 必须匹配原 Cookie 的 domain
    )

    ctx.status(200u16)
        .setCookie(expiredCookie)
        .json(HashMap<String, String>([
            ("message", "Logged out")
        ]))
})
```

**重要**：清除 Cookie 时必须使用相同的 `name`、`domain` 和 `path`。

## 完整示例

### 登录系统

```cj
import stdx.net.http.{Cookie, CookieSameSite}

main() {
    let r = Router()

    // 登录（设置 Cookie）
    r.post("/login", { ctx =>
        let creds = ctx.bindJson<Credentials>()

        match (creds) {
            case Some(c) =>
                if (authenticate(c.username, c.password)) {
                    let token = generateToken(c.username)

                    // 创建安全 Cookie
                    let sessionCookie = Cookie(
                        name: "session",
                        value: token,
                        path: Some("/"),
                        maxAge: Some(7200),  // 2 小时
                        secure: true,
                        httpOnly: true,
                        sameSite: Some(CookieSameSite.Strict)
                    )

                    ctx.status(200u16)
                        .setCookie(sessionCookie)
                        .json(HashMap<String, String>([
                            ("message", "Login successful")
                        ]))
                } else {
                    ctx.jsonWithCode(401u16,
                        HashMap<String, String>([
                            ("error", "Invalid credentials")
                        ])
                    )
                }
            case None => 
                ctx.jsonWithCode(400u16,
                    HashMap<String, String>([
                        ("error", "Invalid JSON")
                    ])
                )
        }
    })

    // 受保护的路由（需要 Cookie）
    r.get("/profile", { ctx =>
        let session = ctx.cookie("session")

        match (session) {
            case Some(token) =>
                if (validateToken(token)) {
                    let username = getUsernameFromToken(token)
                    ctx.json(HashMap<String, String>([
                        ("message", "Welcome to your profile")
                    ]))
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
                        ("error", "Not authenticated")
                    ])
            }
        }
    })

    // 登出（清除 Cookie）
    r.post("/logout", { ctx =>
        ctx.status(200u16)
            .clearCookie("session")
            .json(HashMap<String, String>([
                ("message", "Logout successful")
            ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 用户偏好设置

```cj
import stdx.net.http.Cookie

// 保存用户偏好（非敏感 Cookie）
r.post("/preferences", { ctx =>
    let theme = ctx.query("theme") ?? "light"
    let language = ctx.query("language") ?? "en"

    // 设置非敏感 Cookie（允许 JS 访问）
    ctx.status(200u16)
        .setSimpleCookie("theme", theme)
        .setSimpleCookie("language", language)
        .json(HashMap<String, String>([
            ("message", "Preferences saved")
        ]))
})

// 读取用户偏好
r.get("/home", { ctx =>
    let theme = ctx.cookie("theme") ?? "light"
    let language = ctx.cookie("language") ?? "en"

    // 返回个性化内容
    ctx.json(HashMap<String, String>([
            ("theme", theme),
            ("language", language)
        ]))
})
```

### 跨域 Cookie 设置

```cj
import stdx.net.http.{Cookie, CookieSameSite}

// 主域名设置 Cookie
r.post("/login", { ctx =>
    let token = generateToken()

    // 跨子域名共享 Cookie
    let cookie = Cookie(
        name: "session",
        value: token,
        domain: Some(".example.com"),  // 所有子域名共享
        path: Some("/"),
        maxAge: Some(3600),
        secure: true,
        httpOnly: true,
        sameSite: Some(CookieSameSite.Lax)  // 允许跨站导航
    )

    ctx.status(200u16)
        .setCookie(cookie)
        .json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})

// 子域名 api.example.com 也能读取 Cookie
r.get("/api/data", { ctx =>
    let session = ctx.cookie("session")  // 可以读取主域名的 Cookie

    match (session) {
        case Some(token) =>
            // 验证并返回数据
            ctx.json(HashMap<String, String>([
                ("data", "protected data")
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

### Cookie 中间件示例

```cj
import stdx.net.http.Cookie

// 创建认证中间件
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let session = ctx.cookie("session")

            match (session) {
                case Some(token) =>
                    if (validateToken(token)) {
                        // Token 有效，设置用户信息到 context
                        ctx.kvSet("user", getUserFromToken(token))
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
                            ("error", "Missing session")
                        ])
                    )
            }
        }
    }
}

// 使用中间件
r.group("/api")
    .use([authMiddleware()])
    .get("/users", { ctx =>
        // 已认证，可以安全访问
        let user = ctx.kvGet<User>("user").getOrThrow()
        ctx.json(HashMap<String, String>([
            ("username", user.username)
        ]))
    })
```

## API 参考

### 读取 Cookie

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `cookie(name: String)` | `?String` | 获取指定名称的 Cookie 值 |
| `cookies()` | `HashMap<String, String>` | 获取所有 Cookie |

### 设置 Cookie

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `setCookie(cookie: Cookie)` | `TangHttpContext` | 设置完整 Cookie（链式） |
| `setSimpleCookie(name: String, value: String)` | `TangHttpContext` | 设置简单 Cookie（链式） |

### 清除 Cookie

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `clearCookie(name: String)` | `TangHttpContext` | 清除指定 Cookie（链式） |

## 注意事项

### 1. Cookie 大小限制

浏览器通常限制 Cookie 大小为 **4KB**：

```cj
// ❌ 错误：Cookie 值太大
let hugeData = generateHugeData(5000)  // 5KB
ctx.setSimpleCookie("data", hugeData)  // 可能被浏览器拒绝

// ✅ 正确：只存储必要信息
ctx.setSimpleCookie("token", generateToken())  // 只有几十字节
```

### 2. Cookie 数量限制

浏览器通常限制每个域的 Cookie 数量为 **50 个**：

```cj
// ❌ 错误：创建太多 Cookie
for (i in 0..100) {
    ctx.setSimpleCookie("item${i}", "value${i}")  // 可能超出限制
}

// ✅ 正确：使用 HashMap 存储在服务器，Cookie 只存储 session ID
let sessionID = createSession(data)
ctx.setSimpleCookie("session", sessionID)
```

### 3. 清除 Cookie 必须匹配属性

清除 Cookie 时必须使用相同的 `name`、`domain` 和 `path`：

```cj
// 设置 Cookie
let cookie = Cookie(
    name: "session",
    value: "abc",
    domain: Some(".example.com"),
    path: Some("/api")
)
ctx.setCookie(cookie)

// ❌ 错误：路径不匹配，无法清除
ctx.clearCookie("session")  // 默认 path=/，无法清除 /api 的 Cookie

// ✅ 正确：使用相同的属性清除
let clearCookie = Cookie(
    name: "session",
    value: "",
    domain: Some(".example.com"),
    path: Some("/api"),
    maxAge: Some(0)
)
ctx.setCookie(clearCookie)
```

### 4. 安全性考虑

#### 防止 XSS 攻击

```cj
// ✅ 敏感 Cookie 设置 httpOnly: true
let secureCookie = Cookie(
    name: "session",
    value: token,
    httpOnly: true  // JavaScript 无法访问
)

// ⚠️ 非敏感 Cookie 可以省略 httpOnly
let themeCookie = Cookie(
    name: "theme",
    value: "dark",
    httpOnly: false  // 允许 JS 访问：document.cookie
)
```

#### 防止 CSRF 攻击

```cj
// ✅ 使用 SameSite 策略
let csrfProtected = Cookie(
    name: "session",
    value: token,
    sameSite: Some(CookieSameSite.Strict)  // 仅同站请求
)
```

#### 仅 HTTPS 传输

```cj
// ✅ 生产环境必须设置 secure: true
let productionCookie = Cookie(
    name: "session",
    value: token,
    secure: true  // 仅 HTTPS 传输
)
```

### 5. URL 编码

如果 Cookie 值包含特殊字符，需要 URL 编码：

```cj
import stdx.encoding.url.encode

let value = "hello world; with special=characters"
let encoded = encode(value)  // "hello%20world%3B%20with%20special%3Dcharacters"

ctx.setSimpleCookie("data", encoded)
```

## 相关链接

- **[请求处理](request.md)** - 读取请求的方法
- **[响应操作](response.md)** - 发送响应的方法
- **[辅助方法](utils.md)** - 请求信息获取方法
- **[Session 中间件](../../middleware/builtin/session.md)** - 会话管理中间件
- **[源码](../../src/context_cookie.cj)** - Cookie 操作源代码
