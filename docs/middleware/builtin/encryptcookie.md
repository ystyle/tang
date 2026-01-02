# EncryptCookie - Cookie 加密

## 概述

- **功能**：自动加密和解密 Cookie，防止篡改和读取
- **分类**：会话与Cookie
- **文件**：`src/middleware/encryptcookie/encryptcookie.cj`

EncryptCookie 中间件使用 SM4-CBC 加密和 HMAC-SHA256 签名保护 Cookie，防止客户端篡改或读取敏感数据。

> **💡 提示：为什么需要 Cookie 加密？**
>
> **安全问题**：
> 1. **篡改**：客户端可以修改 Cookie 值（如角色、权限）
> 2. **读取**：Cookie 默认是明文，可以被 JavaScript 读取
> 3. **伪造**：攻击者可以伪造 Cookie 冒充用户
>
> **EncryptCookie 解决方案**：
> - **加密**：SM4-CBC 加密，防止读取
> - **签名**：HMAC-SHA256 签名，防止篡改
> - **完整性**：验证签名，确保数据未被修改
>
> **建议**：
> - 敏感数据（Session ID、用户 ID、权限）：必须加密
> - 非敏感数据（偏好设置）：可选择加密

## 签名

```cj
public func encryptCookie(encryptionKey: Array<UInt8>, signKey: Array<UInt8>): MiddlewareFunc
public func encryptCookie(encryptionKey: Array<UInt8>, signKey: Array<UInt8>, opts: Array<EncryptCookieOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withExcludeCookie()` | `String` | - | 排除指定 Cookie（不加密） |
| `withExcludeCookies()` | `Array<String>` | - | 批量排除 Cookies |

## 加密格式

```
原始值: "user_id=123"
加密后: base64(iv+encrypted).hex(signature)
格式:   <encrypted_base64>.<signature_hex>
```

**组成部分**：
1. **IV（16 字节）**：随机初始化向量
2. **加密数据**：SM4-CBC 加密
3. **签名（HMAC-SHA256）**：验证完整性

## 快速开始

### 基础用法

```cj
import tang.middleware.encryptcookie.encryptCookie

let r = Router()

// 生成密钥（生产环境应从安全配置加载）
let encryptionKey = Array<UInt8>(16, i => i)  // 16 字节加密密钥
let signKey = Array<UInt8>(32, i => i)         // 32 字节签名密钥

// 应用 EncryptCookie 中间件
r.use(encryptCookie(encryptionKey, signKey))

// 设置 Cookie（自动加密）
r.get("/login", { ctx =>
    ctx.setSimpleCookie("user_id", "12345")
    ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})

// 读取 Cookie（自动解密）
r.get("/profile", { ctx =>
    let userId = ctx.cookie("user_id")

    match (userId) {
        case Some(id) => ctx.json(HashMap<String, String>([
            ("userId", id)
        ]))
        case None => ctx.json(HashMap<String, String>([
            ("error", "Not logged in")
        ]))
    }
})
```

**客户端 Cookie**：
```
user_id=YWJjZGVmZ2hpams...a3b4c5d6
```

## 完整示例

### 示例 1：生成安全密钥

```cj
import stdx.crypto.crypto.SecureRandom
import stdx.encoding.hex.toHexString

func generateKey(size: Int64): Array<UInt8> {
    let random = SecureRandom()
    let bytes = Array<UInt8>(size, repeat: 0)
    random.nextBytes(bytes)
    return bytes
}

main() {
    // 生成加密密钥（16 字节）
    let encryptionKey = generateKey(16)

    // 生成签名密钥（32 字节）
    let signKey = generateKey(32)

    // 打印密钥（保存到安全配置）
    println("Encryption Key: ${toHexString(encryptionKey)}")
    println("Sign Key: ${toHexString(signKey)}")

    let r = Router()
    r.use(encryptCookie(encryptionKey, signKey))

    // ... 路由配置
}
```

**生产环境**：从环境变量或配置文件加载

```cj
import std.env.Env

func loadKeyFromEnv(varName: String): Array<UInt8> {
    let hexKey = Env.get(varName).getOrThrow()
    fromHexString(hexKey)
}

let encryptionKey = loadKeyFromEnv("ENCRYPTION_KEY")
let signKey = loadKeyFromEnv("SIGN_KEY")
```

### 示例 2：排除某些 Cookie

```cj
import tang.middleware.encryptcookie.{encryptCookie, withExcludeCookies}

let r = Router()

let encryptionKey = Array<UInt8>(16, i => i)
let signKey = Array<UInt8>(32, i => i)

r.use(encryptCookie(encryptionKey, signKey, [
    // 排除不需要加密的 Cookie
    withExcludeCookies([
        "theme",        // 主题偏好（非敏感）
        "language",     // 语言设置（非敏感）
        "analytics_id"  // 分析 ID（非敏感）
    ])
]))

// 敏感 Cookie（会加密）
r.get("/login", { ctx =>
    ctx.setSimpleCookie("user_id", "12345")
    ctx.setSimpleCookie("role", "admin")

    // 非敏感 Cookie（不加密）
    ctx.setSimpleCookie("theme", "dark")
    ctx.setSimpleCookie("language", "zh-CN")

    ctx.json(HashMap<String, String>([
            ("message", "Login successful")
        ]))
})
```

### 示例 3：用户认证

```cj
import tang.middleware.encryptcookie.encryptCookie

let r = Router()

let encryptionKey = generateKey(16)
let signKey = generateKey(32)

r.use(encryptCookie(encryptionKey, signKey))

// 登录
r.post("/login", { ctx =>
    let username = ctx.fromValue("username") ?? ""
    let password = ctx.fromValue("password") ?? ""

    if (authenticate(username, password)) {
        let user = getUser(username)

        // 加密存储敏感信息
        ctx.setSimpleCookie("user_id", user.id)
        ctx.setSimpleCookie("role", user.role)
        ctx.setSimpleCookie("token", generateToken())

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

// 验证身份
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let userId = ctx.cookie("user_id")
            let role = ctx.cookie("role")

            match (userId) {
                case Some(id) =>
                    // Cookie 已自动解密
                    ctx.kvSet("user_id", id)
                    if (let Some(r) <- role) {
                        ctx.kvSet("role", r)
                    }
                    next(ctx)
                case None =>
                    ctx.jsonWithCode(401u16,
                        HashMap<String, String>([
            ("error", "Not authenticated")
        ])
                    )
                }
            }
        }
    }
}

// 受保护的路由
let protected = r.group("/api")
protected.use([authMiddleware()])

protected.get("/users", { ctx =>
    let userId = ctx.kvGet<String>("user_id").getOrThrow()
    let role = ctx.kvGet<String>("role").getOrThrow()

    ctx.json(HashMap<String, String>([
            ("userId", userId),
            ("role", role)
        ]))
})
```

### 示例 4：Cookie 篡改检测

```cj
let r = Router()

r.use(encryptCookie(encryptionKey, signKey))

// 设置 Cookie
r.get("/set", { ctx =>
    // 原始值：user_id=123
    // 加密后：YWJjZGVm...a3b4c5d6（签名保护）
    ctx.setSimpleCookie("user_id", "123")

    ctx.json(HashMap<String, String>([
            ("message", "Cookie set")
        ]))
})

// 读取 Cookie
r.get("/get", { ctx =>
    let userId = ctx.cookie("user_id")

    match (userId) {
        case Some(id) =>
            // 签名验证成功，自动解密
            ctx.json(HashMap<String, String>([
            ("status", "valid")
        ]))
        case None =>
            // 签名验证失败（Cookie 被篡改）
            ctx.json(HashMap<String, String>([
            ("error", "Invalid cookie (tampered or corrupted)
        ])"
            ))
        }
    }
})
```

**篡改场景**：
```bash
# 1. 服务器设置 Cookie
Set-Cookie: user_id=YWJjZGVm...a3b4c5d6

# 2. 客户端修改 Cookie（篡改）
user_id=modified_value

# 3. 下次请求，服务器验证签名失败
# 结果：ctx.cookie("user_id") 返回 None
```

## 测试

### 测试加密 Cookie

```bash
# 1. 登录（设置加密 Cookie）
curl -c /tmp/cookies.txt \
  -X POST http://localhost:8080/login \
  -d '{"username":"admin","password":"secret"}'

# 查看 Cookie
cat /tmp/cookies.txt
# user_id="YWJjZGVm...a3b4c5d6"  ← 加密的值

# 2. 访问受保护的资源（自动解密）
curl -b /tmp/cookies.txt http://localhost:8080/api/profile

# 响应：
# {"userId":"123","role":"admin"}
```

### 测试篡改检测

```bash
# 1. 获取加密 Cookie
curl -c /tmp/cookies.txt http://localhost:8080/set

# 2. 手动修改 Cookie（篡改）
echo "user_id=corrupted_value" > /tmp/cookies.txt

# 3. 发送篡改的 Cookie
curl -b /tmp/cookies.txt http://localhost:8080/get

# 响应：
# {"error":"Invalid cookie (tampered or corrupted)"}
```

## 工作原理

### 加密流程

```
原始值: "user_id=123"
   ↓
1. 生成随机 IV（16 字节）
   ↓
2. SM4-CBC 加密（使用 encryptionKey）
   encrypted = SM4-CBC.encrypt("user_id=123", key, iv)
   ↓
3. 拼接 IV + 加密数据
   combined = iv + encrypted
   ↓
4. Base64 编码
   encryptedBase64 = base64(combined)
   ↓
5. 生成签名
   signature = HMAC-SHA256(signKey, encryptedBase64)
   ↓
6. 返回：encryptedBase64.signature
```

### 解密流程

```
加密值: "YWJjZGVm...a3b4c5d6"
   ↓
1. 分割：encryptedBase64.signature
   ↓
2. 验证签名
   expectedSignature = HMAC-SHA256(signKey, encryptedBase64)
   if (signature != expectedSignature) → 返回 None
   ↓
3. Base64 解码
   combined = base64.decode(encryptedBase64)
   ↓
4. 分离 IV 和加密数据
   iv = combined[0..16]
   encrypted = combined[16..]
   ↓
5. SM4-CBC 解密
   decrypted = SM4-CBC.decrypt(encrypted, key, iv)
   ↓
6. 返回解密后的值
```

## 安全最佳实践

### 1. 密钥管理

```cj
// ❌ 错误：硬编码密钥
let encryptionKey = Array<UInt8>(16, i => i)  // 不安全！

// ❌ 错误：密钥太简单
let encryptionKey = "1234567890123456".toArray()  // 可预测！

// ✅ 正确：从环境变量加载
let encryptionKey = loadKeyFromEnv("ENCRYPTION_KEY")
let signKey = loadKeyFromEnv("SIGN_KEY")

// ✅ 正确：使用密钥管理服务（KMS）
let encryptionKey = kms.getEncryptionKey()
```

### 2. 密钥长度

```cj
// SM4 密钥：16 字节（128 位）
let encryptionKey = generateKey(16)

// HMAC-SHA256 签名密钥：32 字节（256 位）
let signKey = generateKey(32)
```

### 3. 密钥轮换

```cj
// 生产环境应该定期轮换密钥
var keyVersion = 1
var keys = HashMap<Int64, Array<UInt8>>()

func getCurrentKey(): Array<UInt8> {
    keys.get(keyVersion).getOrThrow()
}

func rotateKey() {
    keyVersion++
    keys[keyVersion] = generateKey(32)
    println("Key rotated to version ${keyVersion}")
}
```

### 4. 与 HttpOnly 配合

```cj
import stdx.net.http.Cookie

// 设置加密 Cookie（同时使用 HttpOnly）
let cookie = Cookie(
    name: "user_id",
    value: "12345",  // 中间件会自动加密
    path: Some("/"),
    httpOnly: true,   // 防止 JavaScript 读取
    secure: true,     // 只通过 HTTPS 传输
    sameSite: Some(CookieSameSite.Strict)
)

ctx.setCookie(cookie)
```

## 注意事项

### 1. Cookie 大小限制

```
加密后的 Cookie 会更大：
- 原始值："user_id=123"（11 字节）
- 加密后："YWJjZGVm...a3b4c5d6"（约 80-100 字节）
```

**建议**：
- 不要在 Cookie 中存储大量数据
- Cookie 大小限制：通常 4KB

### 2. 性能影响

```cj
// 加密/解密会增加约 1-5ms 延迟
// 对于大多数应用，这个延迟可以接受
```

### 3. 排除非敏感 Cookie

```cj
// ✅ 正确：只加密敏感 Cookie
r.use(encryptCookie(encryptionKey, signKey, [
    withExcludeCookies([
        "theme",      // 偏好设置
        "language",   // 语言
        "analytics"   // 分析 ID
    ])
]))
```

## 常见问题

### 问题 1：为什么 Cookie 读取失败？

**原因**：
1. Cookie 被篡改（签名验证失败）
2. Cookie 已过期
3. 密钥不匹配

**排查**：
```cj
let userId = ctx.cookie("user_id")
match (userId) {
    case Some(id) =>
        println("Decrypted user ID: ${id}")
    case None =>
        println("Cookie decryption failed (tampered or invalid)")
    }
}
```

### 问题 2：如何验证 Cookie 是否被加密？

```bash
# 设置 Cookie 后，查看值
curl -c /tmp/cookies.txt http://localhost:8080/login
cat /tmp/cookies.txt

# 加密的 Cookie 特征：
# - 较长（60-100 字符）
# - 包含点号（.）分隔符
# - Base64 字符（A-Z, a-z, 0-9, +, /, =）
```

### 问题 3：密钥泄露怎么办？

**应急措施**：
1. 立即轮换密钥
2. 清除所有现有 Session
3. 要求用户重新登录
4. 审查访问日志，检测异常

## 相关链接

- **[Session 中间件](session.md)** - 会话管理
- **[CSRF 中间件](csrf.md)** - CSRF 保护
- **[源码](../../../src/middleware/encryptcookie/encryptcookie.cj)** - EncryptCookie 源代码
