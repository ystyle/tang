# BasicAuth - HTTP 基本认证

## 概述

- **功能**：HTTP 基本认证（Basic Authentication）
- **分类**：认证与授权
- **文件**：`src/middleware/basicauth/basic_auth.cj`

BasicAuth 中间件实现 HTTP 基本认证，通过用户名和密码保护路由。浏览器会自动弹出认证对话框，无需额外的前端代码。

> **💡 提示：BasicAuth 工作原理**
>
> **认证流程**：
> 1. 客户端访问受保护的资源
> 2. 服务器返回 401 Unauthorized + WWW-Authenticate: Basic realm="..."
> 3. 浏览器弹出用户名/密码对话框
> 4. 用户输入凭证，浏览器发送 Authorization: Basic base64(username:password)
> 5. 服务器验证凭证，返回资源或 401
>
> **优缺点**：
> - ✅ 优点：简单、浏览器原生支持、无需前端代码
> - ❌ 缺点：凭证需要每次请求传输（虽然 Base64 编码，但明文可解）、无法主动注销
>
> **建议**：
> - 适合管理后台、内部系统
> - 必须配合 HTTPS 使用
> - 对外 API 建议使用 KeyAuth 或 JWT

## 签名

```cj
public func newBasicAuth(check: BasicAuthCheckFunc): MiddlewareFunc
public func newBasicAuth(check: BasicAuthCheckFunc, opts: Array<WithBasicAuthRealmOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withBasicAuthRealm()` | `String` | `"Restricted"` | 认证领域（Realm） |

## 类型定义

```cj
// 认证检查函数类型
public type BasicAuthCheckFunc = (TangHttpContext) -> Bool

// 用户信息（从 stdx.encoding.url 导入）
UserInfo {
    username: String
    password: String
}
```

## 快速开始

### 基础用法

```cj
import tang.middleware.basicauth.{newBasicAuth}

let r = Router()

// 应用 BasicAuth 中间件
r.use(newBasicAuth({ ctx =>
    // 从 Authorization header 提取凭证
    let auth = ctx.basicAuth()

    match (auth) {
        case Some(userInfo) =>
            // 验证用户名和密码
            userInfo.username == "admin" && userInfo.password == "secret123"
        case None => false
    }
}))

r.get("/admin", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Welcome, Admin!")
        ]))
})
```

**访问流程**：
1. 浏览器访问 `http://localhost:8080/admin`
2. 弹出认证对话框（用户名/密码）
3. 输入 `admin` / `secret123`
4. 认证成功，显示欢迎消息

### 自定义认证领域

```cj
import tang.middleware.basicauth.{newBasicAuth, withBasicAuthRealm}

let r = Router()

r.use(newBasicAuth(
    { ctx =>
        let auth = ctx.basicAuth()
        match (auth) {
            case Some(userInfo) => validateUser(userInfo)
            case None => false
        }
    },
    [withBasicAuthRealm("Admin Panel")]  // 自定义 realm
}))
```

**浏览器对话框显示**：```
Authentication Required
Realm: Admin Panel
Username: [____]
Password: [____]
```

## 完整示例

### 示例 1：管理后台认证

```cj
import tang.*
import tang.middleware.basicauth.{newBasicAuth, withBasicAuthRealm}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())

    // 管理后台路由组
    let admin = r.group("/admin")

    // 应用 BasicAuth
    admin.use(newBasicAuth(
        { ctx =>
            let auth = ctx.basicAuth()
            match (auth) {
                case Some(userInfo) =>
                    // 验证管理员账户
                    userInfo.username == "admin" && userInfo.password == "admin123"
                case None => false
            }
        },
        [withBasicAuthRealm("Admin Panel")]
    ))

    // 管理后台页面
    admin.get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Welcome to Admin Panel"),
            ("user", "admin")
        ]))
    })

    admin.get("/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("users", "[\")
        ]))
    })

    admin.get("/settings", { ctx =>
        ctx.json(HashMap<String, String>([
            ("setting", "Admin settings")
        ]))
    })

    // 公开端点（无需认证）
    r.get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Public Homepage")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：多用户认证

```cj
import std.collection.HashMap

// 用户数据库
var usersDB = HashMap<String, String>()

func initUsers() {
    usersDB["admin"] = "admin123"
    usersDB["editor"] = "editor456"
    usersDB["viewer"] = "viewer789"
}

// 验证函数
func validateUser(userInfo: UserInfo): Bool {
    let storedPassword = usersDB.get(userInfo.username)
    match (storedPassword) {
        case Some(password) => password == userInfo.password
        case None => false
    }
}

main() {
    initUsers()

    let r = Router()

    r.use(newBasicAuth({ ctx =>
        let auth = ctx.basicAuth()
        match (auth) {
            case Some(userInfo) => validateUser(userInfo)
            case None => false
        }
    }))

    r.get("/api/data", { ctx =>
        // 获取当前用户
        let userInfo = ctx.basicAuth().getOrThrow()
        ctx.json(HashMap<String, String>([
            ("message", "Hello, ${userInfo.username}!")
        ])
        ))
    })

    // 运行服务器...
}
```

### 示例 3：基于数据库的认证

```cj
import std.collection.HashMap

class User {
    let id: Int64
    let username: String
    let passwordHash: String  // 实际应该存储哈希，不是明文
    let role: String

    public init(id: Int64, username: String, passwordHash: String, role: String) {
        this.id = id
        this.username = username
        this.passwordHash = passwordHash
        this.role = role
    }
}

var usersDB = HashMap<String, User>()

func initDatabase() {
    usersDB["admin"] = User(
        id = 1,
        username = "admin",
        passwordHash = "hash_admin123",
        role = "admin"
    )
    usersDB["user"] = User(
        id = 2,
        username = "user",
        passwordHash = "hash_user456",
        role = "user"
    )
}

func authenticate(userInfo: UserInfo): Bool {
    let user = usersDB.get(userInfo.username)
    match (user) {
        case Some(u) =>
            // 实际应用中应该使用 bcrypt/scrypt 等哈希算法验证
            u.passwordHash == "hash_${userInfo.password}"
        case None => false
    }
}

func getUserRole(username: String): String {
    let user = usersDB.get(username)
    match (user) {
        case Some(u) => u.role
        case None => "guest"
    }
}

main() {
    initDatabase()

    let r = Router()

    r.use(newBasicAuth({ ctx =>
        let auth = ctx.basicAuth()
        match (auth) {
            case Some(userInfo) => authenticate(userInfo)
            case None => false
        }
    }))

    r.get("/api/profile", { ctx =>
        let userInfo = ctx.basicAuth().getOrThrow()
        let user = usersDB.get(userInfo.username).getOrThrow()

        ctx.json(HashMap<String, String>([
            ("id", "${user.id}")
        ]))
    })

    // 运行服务器...
}
```

### 示例 4：条件认证（开发环境跳过）

```cj
import std.env.Env

func createAuth(): MiddlewareFunc {
    let env = Env.get("ENV") ?? "development"

    if (env == "development") {
        // 开发环境：不启用认证
        return { next => return { ctx => next(ctx) } }
    } else {
        // 生产环境：启用认证
        return newBasicAuth({ ctx =>
            let auth = ctx.basicAuth()
            match (auth) {
                case Some(userInfo) => validateUser(userInfo)
                case None => false
            }
        })
    }
}

let r = Router()
r.use(createAuth())

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

### 示例 5：提取认证用户信息

```cj
let r = Router()

// 认证中间件
func authMiddleware(): MiddlewareFunc {
    return newBasicAuth({ ctx =>
        let auth = ctx.basicAuth()
        match (auth) {
            case Some(userInfo) =>
                // 验证凭证
                if (validateUser(userInfo)) {
                    // 验证成功，保存用户信息到 context
                    ctx.kvSet("username", userInfo.username)
                    ctx.kvSet("role", getUserRole(userInfo.username))
                    true
                } else {
                    false
                }
            case None => false
        }
    })
}

r.use(authMiddleware())

r.get("/api/profile", { ctx =>
    // 从 context 获取用户信息
    let username = ctx.kvGet<String>("username").getOrThrow()
    let role = ctx.kvGet<String>("role").getOrThrow()

    ctx.json(HashMap<String, String>([
        ("username", username),
        ("role", role)
    ]))
})

r.post("/api/data", { ctx =>
    // 检查权限
    let role = ctx.kvGet<String>("role").getOrThrow()
    if (role != "admin") {
        ctx.jsonWithCode(403u16,
            HashMap<String, String>([
            ("error", "Forbidden: Admin only")
        ])
        )
        return
    }

    // 管理员操作
    ctx.json(HashMap<String, String>([
            ("message", "Data created")
        ]))
})
```

## 测试

### 测试认证成功

```bash
# 使用 curl 的 -u 参数（自动处理 Basic Auth）
curl -u admin:secret123 http://localhost:8080/admin

# 或手动构建 Authorization header
curl -H "Authorization: Basic YWRtaW46c2VjcmV0MTIz" \
  http://localhost:8080/admin

# YWRtaW46c2VjcmV0MTIz 是 "admin:secret123" 的 Base64 编码
```

### 测试认证失败

```bash
# 错误的用户名或密码
curl -i -u admin:wrong-password http://localhost:8080/admin

# 响应：
# HTTP/1.1 401 Unauthorized
# WWW-Authenticate: basic realm="Restricted"
# Unauthorized
```

### 测试浏览器访问

直接在浏览器访问 `http://localhost:8080/admin`，会自动弹出认证对话框。

### Base64 编码示例

```bash
# 编码用户名:密码
echo -n "admin:secret123" | base64
# 输出：YWRtaW46c2VjcmV0MTIz=

# 使用编码后的凭证
curl -H "Authorization: Basic YWRtaW46c2VjcmV0MTIz" \
  http://localhost:8080/admin
```

## 工作原理

### HTTP Basic Auth 流程

```
1. 客户端请求受保护的资源
   GET /admin HTTP/1.1
   Host: localhost:8080
   ↓
2. 服务器返回 401 + WWW-Authenticate 头
   HTTP/1.1 401 Unauthorized
   WWW-Authenticate: Basic realm="Restricted"
   ↓
3. 浏览器弹出认证对话框
   ↓
4. 用户输入用户名和密码
   ↓
5. 浏览器重新请求（带 Authorization 头）
   GET /admin HTTP/1.1
   Host: localhost:8080
   Authorization: Basic YWRtaW46c2VjcmV0MTIz
   ↓
6. 服务器解码并验证凭证
   ↓
7a. 验证成功 → 返回 200 + 资源
7b. 验证失败 → 返回 401
```

### 凭证解码

BasicAuth 使用 Base64 编码传输凭证：

```
原始凭证：admin:secret123
Base64 编码：YWRtaW46c2VjcmV0MTIz=
Authorization 头：Authorization: Basic YWRtaW46c2VjcmV0MTIz=
```

**解码过程**：
```cj
// 1. 提取 Authorization 头
let authHeader = "Basic YWRtaW46c2VjcmV0MTIz="

// 2. 移除 "Basic " 前缀
let base64Credentials = "YWRtaW46c2VjcmV0MTIz="

// 3. Base64 解码
let credentials = fromBase64String(base64Credentials)  // "admin:secret123"

// 4. 分割用户名和密码
let parts = credentials.split(":")
let username = parts[0]  // "admin"
let password = parts[1]  // "secret123"
```

## 安全最佳实践

### 1. 必须使用 HTTPS

```cj
func enforceHTTPS(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (!ctx.secure()) {
                ctx.jsonWithCode(403u16,
                    HashMap<String, String>([
            ("error", "HTTPS required")
        ])
                )
                return
            }
            next(ctx)
        }
    }
}

let r = Router()
r.use(enforceHTTPS())
r.use(newBasicAuth({ ctx => validateAuth(ctx) }))
```

**原因**：BasicAuth 的凭证是 Base64 编码（明文），不加密传输容易被窃听。

### 2. 密码哈希存储

```cj
import stdx.crypto.digest.SHA256

// ❌ 错误：存储明文密码
usersDB["admin"] = "admin123"

// ✅ 正确：存储密码哈希
func hashPassword(password: String): String {
    let sha256 = SHA256()
    sha256.write(password.toArray())
    let hash = sha256.finish()
    return toHexString(hash)
}

func verifyPassword(password: String, hash: String): Bool {
    hashPassword(password) == hash
}

// 注册时存储哈希
usersDB["admin"] = hashPassword("admin123")

// 验证时比较哈希
func authenticate(userInfo: UserInfo): Bool {
    let storedHash = usersDB.get(userInfo.username)
    match (storedHash) {
        case Some(hash) => verifyPassword(userInfo.password, hash)
        case None => false
    }
}
```

### 3. 限制登录尝试

```cj
var failedAttempts = HashMap<String, Int64>()
var blockedIPs = HashSet<String>()

func rateLimitAuth(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let ip = ctx.ip()

            // 检查 IP 是否被封锁
            if (blockedIPs.contains(ip)) {
                ctx.jsonWithCode(429u16,
                    HashMap<String, String>([
            ("error", "Too many failed attempts")
        ])
                )
                return
            }

            // 记录失败次数
            let auth = ctx.basicAuth()
            if (auth == None || !validateAuth(auth.getOrThrow())) {
                let attempts = failedAttempts.get(ip) ?? 0
                failedAttempts[ip] = attempts + 1

                // 超过 5 次失败，封锁 IP
                if (attempts + 1 >= 5) {
                    blockedIPs.add(ip)
                }
                return
            }

            // 认证成功，清除失败记录
            failedAttempts.remove(ip)

            next(ctx)
        }
    }
}

let r = Router()
r.use(rateLimitAuth())
r.use(newBasicAuth({ ctx => validateAuth(ctx) }))
```

### 4. 使用强密码

```cj
func validatePasswordStrength(password: String): Bool {
    // 至少 8 个字符
    if (password.size < 8) {
        return false
    }

    // 包含大小写字母、数字
    let hasUpper = password.any({ ch => ch.isUpper() })
    let hasLower = password.any({ ch => ch.isLower() })
    let hasDigit = password.any({ ch => ch.isDigit() })

    hasUpper && hasLower && hasDigit
}

func registerUser(username: String, password: String): Bool {
    if (!validatePasswordStrength(password)) {
        println("Password too weak")
        return false
    }

    // 存储哈希
    usersDB[username] = hashPassword(password)
    true
}
```

## 注意事项

### 1. 无法主动注销

BasicAuth 的凭证会被浏览器缓存，直到浏览器关闭。

**解决方案**：
- 告诉用户关闭浏览器窗口
- 或使用 Session/Token 认证（支持主动注销）

### 2. 浏览器缓存凭证

浏览器会自动保存 BasicAuth 凭证，后续请求自动添加 Authorization 头。

**清除凭证**：
```javascript
// 前端：发送无效的凭证清除缓存
fetch('/logout', {
  headers: {
    'Authorization': 'Basic ' + btoa('logout:logout')
  }
})
```

### 3. 凭证传输安全性

```cj
// ❌ 错误：HTTP 传输 BasicAuth
curl -u admin:password http://example.com/admin

// ✅ 正确：HTTPS 传输 BasicAuth
curl -u admin:password https://example.com/admin
```

Base64 编码**不是加密**，任何人都可以解码。

### 4. 与其他认证方式对比

| 特性 | BasicAuth | KeyAuth | Session | JWT |
|------|-----------|---------|---------|-----|
| 实现难度 | 简单 | 简单 | 中等 | 中等 |
| 浏览器支持 | 原生 | 需前端代码 | Cookie 自动 | 需前端代码 |
| 安全性 | 较低 | 中等 | 高 | 高 |
| 主动注销 | ❌ | ❌ | ✅ | ❌（除非黑名单）|
| 适用场景 | 管理后台 | API | Web 应用 | API、微服务 |

**选择建议**：
- 管理后台、内部系统：BasicAuth
- 对外 API：KeyAuth 或 JWT
- 传统 Web 应用：Session
- 微服务架构：KeyAuth 或 mTLS

## 常见问题

### 问题 1：浏览器总是弹出认证对话框

**原因**：认证函数返回 false，或没有正确处理凭证

**排查**：
```cj
r.use(newBasicAuth({ ctx =>
    println("Checking auth...")
    let auth = ctx.basicAuth()
    println("Auth: ${auth}")

    match (auth) {
        case Some(userInfo) =>
            println("Username: ${userInfo.username}")
            println("Password: ${userInfo.password}")

            let valid = userInfo.username == "admin" && userInfo.password == "secret123"
            println("Valid: ${valid}")
            valid
        case None =>
            println("No auth provided")
            false
    }
}))
```

### 问题 2：认证成功但无法访问资源

**原因**：认证函数返回 true 但逻辑继续执行，被其他中间件拦截

**解决**：确保认证中间件正确返回 true/false

```cj
// ❌ 错误：没有返回值
r.use(newBasicAuth({ ctx =>
    let auth = ctx.basicAuth()
    match (auth) {
        case Some(userInfo) => validateUser(userInfo)
        case None => ()  // 没有返回 false！
    }
}))

// ✅ 正确：明确返回布尔值
r.use(newBasicAuth({ ctx =>
    let auth = ctx.basicAuth()
    match (auth) {
        case Some(userInfo) => validateUser(userInfo)
        case None => false  // 明确返回 false
    }
}))
```

### 问题 3：不同路由需要不同的认证

**解决方案**：使用路由组

```cj
// 管理员路由
let admin = r.group("/admin")
admin.use(newBasicAuth({ ctx =>
    let auth = ctx.basicAuth()
    match (auth) {
        case Some(userInfo) => userInfo.username == "admin" && userInfo.password == "admin123"
        case None => false
    }
}))

// 编辑路由
let editor = r.group("/editor")
editor.use(newBasicAuth({ ctx =>
    let auth = ctx.basicAuth()
    match (auth) {
        case Some(userInfo) => userInfo.username == "editor" && userInfo.password == "editor456"
        case None => false
    }
}))
```

## 相关链接

- **[KeyAuth 中间件](keyauth.md)** - API 密钥认证
- **[Session 中间件](session.md)** - 会话认证
- **[源码](../../../src/middleware/basicauth/basic_auth.cj)** - BasicAuth 源代码
