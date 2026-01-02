# Session - 会话管理

## 概述

- **功能**：管理用户会话，在多个请求之间存储用户数据
- **分类**：会话与Cookie
- **文件**：`src/middleware/session/session.cj`

Session 中间件提供了完整的会话管理功能，包括内存存储、Cookie 自动管理、会话数据接口等。支持存储任意键值对数据，自动处理会话 ID 生成和过期。

## 签名

```cj
public func session(): MiddlewareFunc
public func session(opts: Array<SessionOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withExpiration()` | `Int64` | `86400`（24小时） | 会话过期时间（秒） |
| `withCookieName()` | `String` | `"session"` | Session Cookie 名称 |

## 快速开始

### 基础用法

```cj
import tang.middleware.session.session

let r = Router()

// 应用 Session 中间件
r.use(session())

// 登录：创建会话
r.post("/login", { ctx =>
    let username = ctx.fromValue("username") ?? ""

    // 创建会话数据
    let sessionData = HashMap<String, String>()
    sessionData["userId"] = "12345"
    sessionData["username"] = username
    sessionData["role"] = "user"

    // 保存会话
    ctx.kvSet("session", sessionData)

    ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})

// 受保护的路由：读取会话
r.get("/profile", { ctx =>
    let session = ctx.kvGet<HashMap<String, String>>("session")

    match (session) {
        case Some(s) =>
            ctx.json(HashMap<String, String>([
                ("userId", s.getOrDefault("userId", "")),
                ("username", s.getOrDefault("username", "")),
                ("role", s.getOrDefault("role", ""))
            ]))
        case None =>
            ctx.jsonWithCode(401u16,
                HashMap<String, String>([
            ("error", "Not authenticated")
        ])
            )
    }
})

// 登出：清除会话
r.post("/logout", { ctx =>
    ctx.kvSet("session", HashMap<String, String>())
    ctx.clearCookie("session")
    ctx.json(HashMap<String, String>([
            ("message", "Logout successful")
        ]))
})
```

## 完整示例

### 示例 1：用户认证系统

```cj
import tang.*
import tang.middleware.session.{session, withExpiration}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder
import std.collection.HashMap

main() {
    let r = Router()

    r.use(logger())
    r.use(session([
        withExpiration(7200)  // 2 小时过期
    ]))

    // 登录
    r.post("/login", { ctx =>
        let username = ctx.fromValue("username") ?? ""
        let password = ctx.fromValue("password") ?? ""

        // 验证用户
        if (authenticate(username, password)) {
            let user = getUserByUsername(username)

            // 创建会话
            let sessionData = HashMap<String, String>()
            sessionData["userId"] = user.id
            sessionData["username"] = user.username
            sessionData["role"] = user.role
            sessionData["loginTime"] = "${DateTime.now()}"

            ctx.kvSet("session", sessionData)

            ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
        } else {
            ctx.jsonWithCode(401u16,
                HashMap<String, String>([
            ("error", "Invalid credentials")
        ])
            )
        }
    })

    // 查看个人资料（需要登录）
    r.get("/profile", { ctx =>
        let session = ctx.kvGet<HashMap<String, String>>("session")

        match (session) {
            case Some(s) =>
                let userId = s.getOrDefault("userId", "")
                let user = getUserById(userId)

                ctx.json(HashMap<String, String>([
                    ("id", user.id),
                    ("username", user.username),
                    ("email", user.email),
                    ("role", s.getOrDefault("role", ""))
                ]))
            case None =>
                ctx.jsonWithCode(401u16,
                    HashMap<String, String>([
            ("error", "Please login first")
        ])
                )
        }
    })

    // 登出
    r.post("/logout", { ctx =>
        let session = ctx.kvGet<HashMap<String, String>>("session")

        match (session) {
            case Some(s) =>
                println("User ${s.getOrDefault("username", "")} logged out")
            case None => ()
        }

        // 清除会话
        ctx.kvSet("session", HashMap<String, String>())
        ctx.clearCookie("session")

        ctx.json(HashMap<String, String>([
            ("message", "Logout successful")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}

func authenticate(username: String, password: String): Bool {
    // 实际应用中应该查询数据库
    username == "admin" && password == "secret"
}

func getUserByUsername(username: String): User {
    User(
        id = "1",
        username = username,
        email = "${username}@example.com",
        role = "admin"
    )
}

func getUserById(id: String): User {
    User(
        id = id,
        username = "admin",
        email = "admin@example.com",
        role = "admin"
    )
}

class User {
    let id: String
    let username: String
    let email: String
    let role: String

    public init(id: String, username: String, email: String, role: String) {
        this.id = id
        this.username = username
        this.email = email
        this.role = role
    }
}
```

### 示例 2：购物车功能

```cj
import tang.middleware.session.session
import std.collection.ArrayList

let r = Router()
r.use(session())

// 添加商品到购物车
r.post("/cart/add", { ctx =>
    let session = ctx.kvGet<HashMap<String, String>>("session")
    let productId = ctx.fromValue("product_id") ?? ""
    let quantity = ctx.fromValue("quantity") ?? "1"

    match (session) {
        case Some(s) =>
            let userId = s.getOrDefault("userId", "")

            // 获取或创建购物车
            var cart = ctx.kvGet<ArrayList<HashMap<String, String>>>("cart_${userId}")

            if (cart == None) {
                cart = Some(ArrayList<HashMap<String, String>>())
            }

            if (let Some(c) <- cart) {
                let item = HashMap<String, String>([
            ("productId", productId),
            ("quantity", quantity)
        ])
                c.add(item)
                ctx.kvSet("cart_${userId}", c)
            }

            ctx.json(HashMap<String, String>([
            ("message", "Item added to cart")
        ]))
        case None =>
            ctx.jsonWithCode(401u16,
                HashMap<String, String>([
            ("error", "Please login first")
        ])
            )
    }
})

// 查看购物车
r.get("/cart", { ctx =>
    let session = ctx.kvGet<HashMap<String, String>>("session")

    match (session) {
        case Some(s) =>
            let userId = s.getOrDefault("userId", "")
            let cart = ctx.kvGet<ArrayList<HashMap<String, String>>>("cart_${userId}")

            match (cart) {
                case Some(c) => ctx.json(c)
                case None => ctx.json(ArrayList<HashMap<String, String>>())
            }
        case None =>
            ctx.jsonWithCode(401u16,
                HashMap<String, String>([
            ("error", "Please login first")
        ])
            )
    }
})
```

### 示例 3：认证中间件

```cj
import tang.middleware.session.session

func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let session = ctx.kvGet<HashMap<String, String>>("session")

            match (session) {
                case Some(s) =>
                    // 会话存在,将用户信息存入 context
                    ctx.kvSet("user_id", s.getOrDefault("userId", ""))
                    ctx.kvSet("username", s.getOrDefault("username", ""))
                    ctx.kvSet("role", s.getOrDefault("role", ""))

                    next(ctx)
                case None =>
                    // 会话不存在，返回 401
                    ctx.jsonWithCode(401u16,
                        HashMap<String, String>([
            ("error", "Authentication required")
        ])
                    )
            }
        }
    }
}

// 使用认证中间件
let r = Router()
r.use(session())

// 公开端点
r.post("/login", { ctx =>
    let sessionData = HashMap<String, String>()
    sessionData["userId"] = "123"
    sessionData["username"] = "testuser"
    ctx.kvSet("session", sessionData)

    ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})

// 受保护的路由组
let protected = r.group("/api")
protected.use([authMiddleware()])

protected.get("/users", { ctx =>
    let userId = ctx.kvGet<String>("user_id").getOrThrow()
    ctx.json(HashMap<String, String>([
            ("message", "User data for ${userId}")
        ]))
})

protected.post("/data", { ctx =>
    let username = ctx.kvGet<String>("username").getOrThrow()
    ctx.json(HashMap<String, String>([
            ("message", "Hello, ${username}")
        ]))
})
```

### 示例 4：会话过期处理

```cj
import tang.middleware.session.{session, withExpiration}

let r = Router()

r.use(session([
    withExpiration(1800)  // 30 分钟过期
]))

r.get("/api/check", { ctx =>
    let session = ctx.kvGet<HashMap<String, String>>("session")

    match (session) {
        case Some(s) =>
            let loginTime = s.getOrDefault("loginTime", "")
            let username = s.getOrDefault("username", "")

            ctx.json(HashMap<String, String>([
            ("status", "authenticated")
        ]))
        case None =>
            ctx.json(HashMap<String, String>([
            ("status", "not_authenticated"),
            ("message", "Session expired or not found")
        ]))
    }
})
```

## 测试

### 测试登录流程

```bash
# 1. 登录
curl -c /tmp/cookies.txt \
     -X POST http://localhost:8080/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"secret"}'
# {"message":"Login successful"}

# 2. 访问受保护的路由（使用 Cookie）
curl -b /tmp/cookies.txt http://localhost:8080/profile
# {"userId":"12345","username":"admin","role":"admin"}

# 3. 登出
curl -b /tmp/cookies.txt -X POST http://localhost:8080/logout
# {"message":"Logout successful"}
```

### 测试会话过期

```bash
# 1. 登录
curl -c /tmp/cookies.txt -X POST http://localhost:8080/login \
  -d '{"username":"admin","password":"secret"}'

# 2. 立即访问（有效）
curl -b /tmp/cookies.txt http://localhost:8080/profile
# 返回用户数据

# 3. 等待会话过期后访问（无效）
sleep 1800  # 等待 30 分钟
curl -b /tmp/cookies.txt http://localhost:8080/profile
# {"error":"Please login first"}
```

## 工作原理

### 会话 ID 生成

Session 中间件使用 `SecureRandom` 生成唯一的会话 ID：

```cj
public func generateSessionID(): String {
    let bytes = Array<UInt8>(32, repeat: 0)
    random.nextBytes(bytes)
    return base64Encode(bytes)  // 生成 43 字符的 Base64 字符串
}
```

### 会话数据结构

```cj
// 会话数据存储在 HashMap 中
HashMap<String, String>([
    ("userId", "12345"),
    ("username", "testuser"),
    ("role", "user"),
    ("loginTime", "2025-01-02 10:30:00")
])
// 可以存储任意键值对
```

### 会话生命周期

```
1. 用户登录 → 创建会话数据 → 生成 Session ID
2. Session ID 通过 Cookie 返回给客户端
3. 客户端后续请求携带 Cookie
4. 服务器从 Cookie 读取 Session ID
5. 从内存中查找会话数据
6. 如果找到且未过期，恢复会话
7. 如果未找到或已过期，返回未认证
```

> **💡 提示：Session vs JWT**
>
> **Session**：
> - 数据存储在服务器（内存、Redis）
> - 客户端只存储 Session ID
> - 服务器可以主动废除会话
> - 适合传统 Web 应用
>
> **JWT (JSON Web Token)**：
> - 数据存储在 Token 中（客户端）
> - 无状态，服务器不存储
> - 无法主动废除 Token（除非使用黑名单）
> - 适合微服务、移动应用
>
> **选择建议**：
> - 简单的 CRUD 应用：Session
> - 微服务架构：JWT
> - 需要实时控制权限：Session

## 注意事项

### 1. 内存存储限制

默认实现使用内存存储会话数据，有以下限制：

```cj
// ❌ 限制 1：应用重启会丢失所有会话
// ❌ 限制 2：多实例部署无法共享会话
// ❌ 限制 3：大量会话占用内存
```

**解决方案**：使用 Redis 等外部存储

```cj
func redisSessionStore(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let sessionID = ctx.cookie("session")

            match (sessionID) {
                case Some(id) =>
                    // 从 Redis 获取会话
                    let sessionData = redis.hgetall("session:${id}")

                    if (sessionData.size > 0) {
                        ctx.kvSet("session", sessionData)

                        // 刷新过期时间
                        redis.expire("session:${id}", 7200)
                    }
                case None =>
                    // 创建新会话
                    let newSessionID = generateSessionID()
                    let sessionData = HashMap<String, String>()

                    // 存储到 Redis
                    redis.hset("session:${newSessionID}", sessionData)
                    redis.expire("session:${newSessionID}", 7200)

                    // 设置 Cookie
                    ctx.setSimpleCookie("session", newSessionID)
                    ctx.kvSet("session", sessionData)
            }

            next(ctx)
        }
    }
}
```

### 2. 会话数据大小

避免在会话中存储大量数据：

```cj
// ❌ 错误：存储大量数据
let sessionData = HashMap<String, String>()
sessionData["user"] = userData.toJSON()  // 可能很大
sessionData["cart"] = cart.toJSON()      // 购物车可能有上百个商品
ctx.kvSet("session", sessionData)

// ✅ 正确：只存储必要的标识
let sessionData = HashMap<String, String>()
sessionData["userId"] = user.id
sessionData["username"] = user.username
ctx.kvSet("session", sessionData)

// 需要时从数据库加载完整数据
let user = getUserFromDB(sessionData["userId"])
let cart = getCartFromDB(sessionData["userId"])
```

### 3. 敏感信息

不要在会话中存储敏感信息：

```cj
// ❌ 错误：存储密码
sessionData["password"] = user.password  // 危险！

// ❌ 错误：存储信用卡号
sessionData["creditCard"] = creditCardNumber  // 危险！

// ✅ 正确：只存储 ID 和必要的元数据
sessionData["userId"] = user.id
sessionData["username"] = user.username
```

### 4. 会话固定攻击

防止会话固定攻击（Session Fixation）：

```cj
r.post("/login", { ctx =>
    let username = ctx.fromValue("username") ?? ""
    let password = ctx.fromValue("password") ?? ""

    if (authenticate(username, password)) {
        // ✅ 登录成功后重新生成 Session ID
        let oldSessionID = ctx.cookie("session")

        // 创建新会话
        let newSessionID = generateSessionID()
        let sessionData = HashMap<String, String>()
        sessionData["userId"] = getUserByUsername(username).id

        // 存储新会话
        sessions[newSessionID] = sessionData

        // 删除旧会话
        if (let Some(oldID) <- oldSessionID) {
            sessions.remove(oldID)
        }

        // 设置新 Cookie
        ctx.setSimpleCookie("session", newSessionID)

        ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
    } else {
        ctx.jsonWithCode(401u16,
            HashMap<String, String>([
            ("error", "Invalid credentials")
        ])
        )
    }
})
```

### 5. 并发安全

Session 中间件使用 `Mutex` 保证并发安全：

```cj
class MemoryStore {
    let sessions: HashMap<String, HashMap<String, String>> = HashMap()
    let mu: Mutex = Mutex()

    public func get(id: String): ?HashMap<String, String> {
        synchronized(this.mu) {
            this.sessions.get(id)
        }
    }

    public func set(id: String, data: HashMap<String, String>): Unit {
        synchronized(this.mu) {
            this.sessions[id] = data
        }
    }
}
```

## 相关链接

- **[EncryptCookie 中间件](encryptcookie.md)** - Cookie 加密
- **[CSRF 中间件](csrf.md)** - CSRF 保护
- **[KeyAuth 中间件](keyauth.md)** - API 密钥认证
- **[源码](../../../src/middleware/session/session.cj)** - Session 源代码
