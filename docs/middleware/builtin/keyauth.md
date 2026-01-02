# KeyAuth - API 密钥认证

## 概述

- **功能**：基于 API Key 的简单认证机制
- **分类**：认证与授权
- **文件**：`src/middleware/keyauth/keyauth.cj`

KeyAuth 中间件提供基于 API Key 的简单认证，支持从多个位置（Header、Query、Cookie）获取密钥，支持自定义验证器和查找函数。

> **💡 提示：KeyAuth vs BasicAuth**
>
> **KeyAuth（推荐用于 API）**：
> - 使用 API Key 认证
> - 适合服务间调用、API 访问
> - 简单、灵活、易于实现
> - 不传输用户名密码
>
> **BasicAuth（适合简单场景）**：
> - 使用用户名密码认证
> - 适合管理后台、内部系统
> - 浏览器原生支持
> - 需要传输凭证（Base64 编码）
>
> **建议**：
> - 对外 API：使用 KeyAuth 或 JWT
> - 管理后台：使用 BasicAuth 或 Session
> - 微服务：使用 KeyAuth 或 mTLS

## 签名

```cj
public func keyAuth(): MiddlewareFunc
public func keyAuth(opts: Array<KeyAuthOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withKey()` | `String` | 必填 | 添加允许的 API Key |
| `withKeys()` | `Array<String>` | 必填 | 添加多个允许的 API Keys |
| `withValidator()` | `(String) -> Bool` | - | 自定义验证器函数 |
| `withLookup()` | `String` | 多位置查找 | Key 查找位置（"header:X-API-Key"） |
| `withCustomLookup()` | `(TangHttpContext) -> ?String` | - | 自定义查找函数 |
| `withErrorResponse()` | `String` | `"Unauthorized\n"` | 认证失败时的响应 |
| `withExposeErrorCode()` | - | `false` | 是否暴露错误原因（安全考虑） |

## 默认 Key 查找顺序

默认情况下，KeyAuth 会按以下顺序查找 API Key：

1. **Header**：`X-API-Key`
2. **Header**：`Authorization`（支持 "Bearer {key}" 或 "Key {key}" 格式）
3. **Query**：`api_key`
4. **Query**：`token`
5. **Query**：`key`
6. **Cookie**：`api_key`
7. **Cookie**：`token`

## 快速开始

### 基础用法（单个 API Key）

```cj
import tang.middleware.keyauth.{keyAuth, withKey}

let r = Router()

// 应用 KeyAuth 中间件
r.use(keyAuth([
    withKey("your-secret-api-key-12345")
]))

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Authenticated!")
        ]))
})
```

**请求示例**：
```bash
# 方式 1：通过 X-API-Key header
curl -H "X-API-Key: your-secret-api-key-12345" \
  http://localhost:8080/api/data

# 方式 2：通过 Authorization header（Bearer 格式）
curl -H "Authorization: Bearer your-secret-api-key-12345" \
  http://localhost:8080/api/data

# 方式 3：通过 query 参数
curl http://localhost:8080/api/data?api_key=your-secret-api-key-12345
```

### 多个 API Keys

```cj
import tang.middleware.keyauth.{keyAuth, withKeys}

let r = Router()

// 多个客户端使用不同的 API Keys
r.use(keyAuth([
    withKeys([
        "client-key-1",
        "client-key-2",
        "client-key-3"
    ])
]))
```

## 完整示例

### 示例 1：从特定位置获取 Key

```cj
import tang.middleware.keyauth.{keyAuth, withKey, withLookup}

let r = Router()

// 仅从 X-API-Key header 获取
r.use(keyAuth([
    withKey("secret-key-123"),
    withLookup("header:X-API-Key")  // 强制只从 header 获取
]))

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Success")
        ]))
})
```

**支持的查找格式**：
```cj
withLookup("header:X-API-Key")      // 从 header 获取
withLookup("query:api_key")         // 从 query 参数获取
withLookup("cookie:token")          // 从 cookie 获取
```

### 示例 2：自定义验证器

```cj
import tang.middleware.keyauth.{keyAuth, withValidator}

let r = Router()

// 使用自定义验证逻辑
r.use(keyAuth([
    withValidator({ key =>
        // 示例 1：Key 必须以 "prod-" 开头且长度 > 10
        key.startsWith("prod-") && key.size > 10
    })
]))

// 或更复杂的验证
r.use(keyAuth([
    withValidator({ key =>
        // 示例 2：从数据库验证
        isValidAPIKey(key)
    })
]))
```

### 示例 3：API 路由级别认证

```cj
import tang.*
import tang.middleware.keyauth.{keyAuth, withKeys}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 公开端点（无需认证）
    r.get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Welcome to Public API")
        ]))
    })

    // API 路由组（需要认证）
    let api = r.group("/api")

    // 为 API 组添加 KeyAuth
    api.use(keyAuth([
        withKeys([
            "client-1-key",
            "client-2-key",
            "admin-key"
        ])
    ]))

    // 受保护的 API 端点
    api.get("/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("data", "users list")
        ]))
    })

    api.get("/products", { ctx =>
        ctx.json(HashMap<String, String>([
            ("data", "products list")
        ]))
    })

    api.post("/orders", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Order created")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 4：不同客户端不同 Key

```cj
import tang.middleware.keyauth.{keyAuth, withCustomLookup}

let r = Router()

// 从不同位置查找不同客户端的 Key
r.use(keyAuth([
    withCustomLookup({ ctx =>
        // 客户端 A：从 header 获取
        let keyA = ctx.request.headers.getFirst("X-Client-A-Key")
        if (let Some(k) <- keyA) {
            return Some(k)
        }

        // 客户端 B：从 query 获取
        let keyB = ctx.query("client_b_key")
        if (let Some(k) <- keyB) {
            return Some(k)
        }

        // 客户端 C：从 cookie 获取
        let cookies = ctx.cookies()
        let keyC = cookies.get("client_c_key")
        keyC
    }),
    withValidator({ key =>
        // 验证所有客户端的 Key
        key.startsWith("client-a-") ||
        key.startsWith("client-b-") ||
        key.startsWith("client-c-")
    })
]))
```

### 示例 5：自定义错误响应

```cj
import tang.middleware.keyauth.{keyAuth, withKey, withErrorResponse, withExposeErrorCode}

let r = Router()

r.use(keyAuth([
    withKey("secret"),
    withErrorResponse("{\"error\":\"Authentication required\",\"code\":401}\n"),
    withExposeErrorCode()  // 暴露详细错误信息
]))

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**认证失败响应**：
```http
HTTP/1.1 401 Unauthorized
Content-Type: text/plain; charset=utf-8
X-Auth-Error: Invalid API Key

{"error":"Authentication required","code":401}
```

### 示例 6：结合数据库验证

```cj
import tang.middleware.keyauth.{keyAuth, withValidator}
import std.collection.HashMap

// 模拟数据库
var apiKeysDB = HashMap<String, APIKey>()

class APIKey {
    let key: String
    let userId: String
    let scopes: ArrayList<String>
    let isActive: Bool

    public init(key: String, userId: String, scopes: ArrayList<String>, isActive: Bool) {
        this.key = key
        this.userId = userId
        this.scopes = scopes
        this.isActive = isActive
    }
}

// 初始化数据库
func initDatabase() {
    apiKeysDB["key-1"] = APIKey(
        key = "key-1",
        userId = "user-1",
        scopes = ArrayList<String>(["read", "write"]),
        isActive = true
    )
    apiKeysDB["key-2"] = APIKey(
        key = "key-2",
        userId = "user-2",
        scopes = ArrayList<String>(["read"]),
        isActive = true
    )
    apiKeysDB["key-3"] = APIKey(
        key = "key-3",
        userId = "user-3",
        scopes = ArrayList<String>(["read", "write", "delete"]),
        isActive = false  // 已禁用
    )
}

// 数据库验证器
func validateKeyFromDB(key: String): Bool {
    let apiKey = apiKeysDB.get(key)
    match (apiKey) {
        case Some(k) => k.isActive  // 检查 key 是否存在且激活
        case None => false
    }
}

main() {
    initDatabase()

    let r = Router()

    // 使用数据库验证
    r.use(keyAuth([
        withValidator({ key => validateKeyFromDB(key) })
    ]))

    r.get("/api/data", { ctx =>
        // 可以从数据库获取用户信息
        let apiKey = ctx.request.headers.getFirst("X-API-Key").getOrThrow()
        let userId = apiKeysDB.get(apiKey).getOrThrow().userId

        ctx.json(HashMap<String, String>([
            ("data", "protected data")
        ]))
    })

    // 运行服务器...
}
```

## 测试

### 测试 Header 认证

```bash
# 使用 X-API-Key header
curl -H "X-API-Key: secret-key-123" \
  http://localhost:8080/api/data

# 使用 Authorization header（Bearer 格式）
curl -H "Authorization: Bearer secret-key-123" \
  http://localhost:8080/api/data

# 使用 Authorization header（Key 格式）
curl -H "Authorization: Key secret-key-123" \
  http://localhost:8080/api/data
```

### 测试 Query 认证

```bash
# 使用 api_key 参数
curl http://localhost:8080/api/data?api_key=secret-key-123

# 使用 token 参数
curl http://localhost:8080/api/data?token=secret-key-123

# 使用 key 参数
curl http://localhost:8080/api/data?key=secret-key-123
```

### 测试 Cookie 认证

```bash
# 使用 cookie
curl -b "api_key=secret-key-123" \
  http://localhost:8080/api/data

# 使用 token cookie
curl -b "token=secret-key-123" \
  http://localhost:8080/api/data
```

### 测试认证失败

```bash
# 不提供 API Key
curl -i http://localhost:8080/api/data
# HTTP/1.1 401 Unauthorized
# X-Auth-Error: Missing API Key（如果启用了 withExposeErrorCode）

# 提供错误的 API Key
curl -i -H "X-API-Key: wrong-key" \
  http://localhost:8080/api/data
# HTTP/1.1 401 Unauthorized
# X-Auth-Error: Invalid API Key（如果启用了 withExposeErrorCode）
```

## 工作原理

### 认证流程

```
1. 客户端发送请求（携带 API Key）
   ↓
2. KeyAuth 中间件提取 API Key
   - 从 header / query / cookie
   - 使用自定义查找函数
   ↓
3. 验证 API Key
   - 检查是否在允许列表中
   - 或使用自定义验证器
   ↓
4a. 验证成功 → 继续处理请求
4b. 验证失败 → 返回 401 Unauthorized
```

### Key 提取优先级

**默认查找顺序**：
```cj
1. header: X-API-Key
2. header: Authorization (Bearer/Key)
3. query: api_key
4. query: token
5. query: key
6. cookie: api_key
7. cookie: token
```

**自定义查找**：
```cj
withLookup("header:X-Custom-Key")  // 只从指定位置查找
```

## 安全最佳实践

### 1. API Key 生成

```cj
import stdx.crypto.random.SecureRandom
import stdx.encoding.base64.{encode}

func generateAPIKey(): String {
    let random = SecureRandom()
    let bytes = Array<UInt8>(32, repeat: 0)
    random.nextBytes(bytes)
    return encode(bytes)  // 生成 43 字符的 Base64 字符串
}

// 示例：prod-AbCdEf123456...
let key = "prod-${generateAPIKey()}"
```

### 2. API Key 轮换

```cj
var currentKeys = ArrayList<String>(["key-v1"])
var deprecatedKeys = ArrayList<String>()

// 轮换 API Key
func rotateKeys() {
    let newKey = generateAPIKey()
    deprecatedKeys.clear()
    deprecatedKeys.append(currentKeys[0])

    currentKeys.clear()
    currentKeys.add(newKey)

    println("New key: ${newKey}")
    println("Deprecated key still valid for transition period")
}

// 验证：接受当前和废弃的 Key
func validateKey(key: String): Bool {
    currentKeys.contains(key) || deprecatedKeys.contains(key)
}
```

### 3. Key 作用域（Scopes）

```cj
class APIKey {
    let key: String
    let scopes: ArrayList<String>  // read, write, delete
    let rateLimit: Int64
}

// 验证 Key 权限
func checkScope(apiKey: APIKey, requiredScope: String): Bool {
    apiKey.scopes.contains(requiredScope)
}

r.get("/api/users", { ctx =>
    let apiKey = getAPIKey(ctx)
    if (!checkScope(apiKey, "read")) {
        ctx.jsonWithCode(403u16,
            HashMap<String, String>([
            ("error", "Insufficient permissions")
        ])
        )
        return
    }
    ctx.json(usersData)
})

r.post("/api/users", { ctx =>
    let apiKey = getAPIKey(ctx)
    if (!checkScope(apiKey, "write")) {
        ctx.jsonWithCode(403u16,
            HashMap<String, String>([
            ("error", "Insufficient permissions")
        ])
        )
        return
    }
    createUser(ctx)
})
```

### 4. 不暴露错误原因

```cj
// ❌ 错误：暴露错误原因（安全风险）
r.use(keyAuth([
    withExposeErrorCode()  // 会告诉攻击者 Key 格式是否正确
]))

// ✅ 正确：不暴露错误原因
r.use(keyAuth([
    // 默认不暴露，只返回 401
]))
```

**原因**：防止攻击者通过错误消息枚举有效的 API Keys。

### 5. 使用 HTTPS

API Key 应该只通过 HTTPS 传输：

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
r.use(keyAuth([withKey("secret")]))
```

### 6. 记录认证失败

```cj
import tang.middleware.log.logger

func logFailedAuth(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let startTime = DateTime.now()

            next(ctx)

            let statusCode = ctx.responseBuilder.statusCode
            if (statusCode == 401u16) {
                let ip = ctx.ip()
                let path = ctx.path()
                println("[AUTH FAILED] ${ip} - ${path} - ${startTime}")
            }
        }
    }
}

let r = Router()
r.use(logFailedAuth())
r.use(keyAuth([withKey("secret")]))
```

## 注意事项

### 1. 不要在 URL 中传输敏感 Key

```bash
# ❌ 危险：API Key 在 URL 中（会被记录到访问日志）
curl http://localhost:8080/api/data?api_key=secret-key-123

# ✅ 安全：API Key 在 Header 中
curl -H "X-API-Key: secret-key-123" \
  http://localhost:8080/api/data
```

**原因**：
- URL 会被记录到服务器访问日志
- URL 会被浏览器历史记录保存
- URL 可能被 Referer 头泄露

### 2. API Key 轮换

```cj
// ❌ 错误：永不过期的 API Key
let permanentKey = "secret-key-123"

// ✅ 正确：定期轮换 API Key
var keys = HashMap<String, DateTime>()
keys["key-v1"] = DateTime.now()  // 记录生成时间

func isExpired(key: String): Bool {
    let created = keys.get(key)
    match (created) {
        case Some(date) =>
            let age = DateTime.now().toUnixTimeStamp() - date.toUnixTimeStamp()
            age > 2592000  // 30 天过期
        case None => true
    }
}
```

### 3. 与 Rate Limit 配合

```cj
import tang.middleware.ratelimit.{ratelimit, withMaxRequests, withWindowMs}

// 基于 API Key 的限流
func keyBasedRateLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let apiKey = ctx.request.headers.getFirst("X-API-Key")
            match (apiKey) {
                case Some(key) =>
                    // 检查该 Key 的使用次数
                    let count = getUsageCount(key)

                    if (count > 1000) {  // 每小时 1000 次
                        ctx.jsonWithCode(429u16,
                            HashMap<String, String>([
            ("error", "Rate limit exceeded")
        ])
                        )
                        return
                    }

                    incrementUsage(key)
                    next(ctx)
                }
                case None => next(ctx)
            }
        }
    }
}

let r = Router()
r.use(keyAuth([withKey("secret")]))
r.use(keyBasedRateLimit())
```

### 4. 不同的 Key 不同的权限

```cj
// Key 类型
enum KeyType {
    | ReadOnly
    | ReadWrite
    | Admin
}

class KeyInfo {
    let key: String
    let type: KeyType
}

var keysDB = HashMap<String, KeyType>()

func checkPermission(key: String, requiredType: KeyType): Bool {
    let keyType = keysDB.get(key)
    match (keyType) {
        case Some(t) =>
            match (requiredType) {
                case KeyType.ReadOnly => true  // 所有 Key 都可以读
                case KeyType.ReadWrite => t != KeyType.ReadOnly
                case KeyType.Admin => t == KeyType.Admin
            }
        case None => false
    }
}

r.get("/api/users", { ctx =>
    let key = ctx.request.headers.getFirst("X-API-Key").getOrThrow()
    if (!checkPermission(key, KeyType.ReadOnly)) {
        ctx.jsonWithCode(403u16,
            HashMap<String, String>([
            ("error", "Forbidden")
        ])
        )
        return
    }
    ctx.json(usersData)
})

r.post("/api/users", { ctx =>
    let key = ctx.request.headers.getFirst("X-API-Key").getOrThrow()
    if (!checkPermission(key, KeyType.ReadWrite)) {
        ctx.jsonWithCode(403u16,
            HashMap<String, String>([
            ("error", "Forbidden")
        ])
        )
        return
    }
    createUser(ctx)
})
```

## 常见问题

### 问题 1：认证总是失败

**原因**：
1. API Key 未正确传递
2. 查找位置配置错误
3. Key 格式不匹配

**排查**：
```cj
// 临时启用详细错误信息
r.use(keyAuth([
    withKey("secret"),
    withExposeErrorCode()  // 显示具体错误
]))
```

### 问题 2：多个 Key 查找位置冲突

**场景**：同时从 header 和 query 传递了不同的 Key

**解决**：使用固定的查找位置

```cj
r.use(keyAuth([
    withKey("secret"),
    withLookup("header:X-API-Key")  // 只从 header 获取
]))
```

### 问题 3：Authorization header 格式错误

```bash
# ❌ 错误：缺少空格
curl -H "Authorization:Bearer secret" http://localhost:8080/api

# ❌ 错误：小写 bearer
curl -H "Authorization: bearer secret" http://localhost:8080/api

# ✅ 正确：Bearer + 空格
curl -H "Authorization: Bearer secret" http://localhost:8080/api

# ✅ 正确：Key + 空格
curl -H "Authorization: Key secret" http://localhost:8080/api
```

## 相关链接

- **[BasicAuth 中间件](basicauth.md)** - HTTP 基本认证
- **[Session 中间件](session.md)** - 会话认证
- **[源码](../../../src/middleware/keyauth/keyauth.cj)** - KeyAuth 源代码
