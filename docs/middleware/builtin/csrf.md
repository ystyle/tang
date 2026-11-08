# CSRF - 跨站请求伪造保护

> **本分支变更**：该中间件已移到扩展成员 `tang_ext_crypto` 以保持核心零 stdx。
> import 从 `tang.middleware.csrf.*` 改为 `tang_ext_crypto.csrf.*`，
> 并需要在 `cjpm.toml` 里加 `tang_ext_crypto` 依赖（含 `CANGJIE_STDX_PATH` 环境）。
> 详见 [迁移指南](../../MIGRATION.md)。

## 概述

- **功能**：防止跨站请求伪造（Cross-Site Request Forgery）攻击
- **分类**：安全类
- **文件**：`src/middleware/csrf/csrf.cj`

CSRF 中间件通过生成和验证 CSRF Token 来防止跨站请求伪造攻击。这是处理状态改变操作（POST、PUT、DELETE）时的重要安全措施。

## 签名

```cj
public func csrf(): MiddlewareFunc
public func csrf(opts: Array<CSRFOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withSecretKey()` | `String` | 随机生成的密钥 | HMAC 签名密钥 |
| `withExpiration()` | `Int64` | `86400`（24小时） | Token 过期时间（秒） |
| `withTokenLookup()` | `String` | `"header:X-CSRF-Token"` | Token 查找位置 |
| `withExcludePath()` | `Array<String>` | `[]` | 排除的路径（不验证 CSRF） |

## 快速开始

### 基础用法

```cj
import tang.middleware.csrf.{csrf, withTokenLookup}

let r = Router()

// 配置 CSRF 中间件
r.use(csrf([
    withTokenLookup("header:X-CSRF-Token")  // 从请求头获取 Token
]))

// 1. 提供 Token 的端点
r.get("/api/csrf/token", { ctx =>
    let token = ctx.csrfToken().getOrThrow()
    ctx.json(HashMap<String, String>([
            ("token", token)
        ]))
})

// 2. 受保护的端点（需要验证 CSRF Token）
r.post("/api/users", { ctx =>
    // CSRF 中间件已自动验证 Token
    ctx.json(HashMap<String, String>([
            ("message", "User created")
        ]))
})

// 3. 公开端点（不需要 CSRF 验证）
r.get("/api/public", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Public endpoint")
        ]))
})
```

### 完整的前后端集成

**后端（Tang）**：
```cj
import tang.middleware.csrf.{csrf, withSecretKey, withExpiration, withTokenLookup}

let r = Router()

r.use(csrf([
    withSecretKey("your-secret-key-change-in-production"),
    withExpiration(3600),  // 1 小时
    withTokenLookup("header:X-CSRF-Token")
]))

r.get("/api/csrf/token", { ctx =>
    let token = ctx.csrfToken().getOrThrow()
    ctx.json(HashMap<String, String>([
            ("headerName", "X-CSRF-Token")
        ]))
})

r.post("/api/forms", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Form submitted successfully")
        ]))
})
```

**前端（JavaScript）**：
```javascript
// 1. 获取 CSRF Token
async function getCSRFToken() {
    const response = await fetch('/api/csrf/token');
    const data = await response.json();
    return data.token;
}

// 2. 提交表单时带上 Token
async function submitForm(formData) {
    const token = await getCSRFToken();

    const response = await fetch('/api/forms', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': token  // 添加 CSRF Token
        },
        body: JSON.stringify(formData)
    });

    return response.json();
}

// 使用
submitForm({ name: 'Test' })
    .then(data => console.log(data))
    .catch(error => console.error('Error:', error));
```

## 完整示例

### 示例 1：表单提交保护

```cj
import tang.*
import tang.middleware.csrf.{csrf, withSecretKey, withExpiration}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())
    r.use(csrf([
        withSecretKey("your-secret-key"),
        withExpiration(7200)  // 2 小时
    ]))

    // 获取 Token
    r.get("/csrf/token", { ctx =>
        let token = ctx.csrfToken().getOrThrow()
        ctx.json(HashMap<String, String>([
            ("headerName", "X-CSRF-Token")
        ]))
    })

    // 登录表单
    r.post("/login", { ctx =>
        let username = ctx.fromValue("username") ?? ""
        let password = ctx.fromValue("password") ?? ""

        // CSRF 已验证，处理登录逻辑
        if (authenticate(username, password)) {
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

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**HTML 表单示例**：
```html
<!DOCTYPE html>
<html>
<head>
    <title>登录</title>
</head>
<body>
    <form id="loginForm">
        <input type="text" name="username" placeholder="用户名">
        <input type="password" name="password" placeholder="密码">
        <button type="submit">登录</button>
    </form>

    <script>
        // 页面加载时获取 Token
        fetch('/csrf/token')
            .then(res => res.json())
            .then(data => {
                window.csrfToken = data.token;
            });

        // 表单提交时带上 Token
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData);

            const response = await fetch('/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': window.csrfToken
                },
                body: JSON.stringify(data)
            });

            const result = await response.json();
            console.log(result);
        });
    </script>
</body>
</html>
```

### 示例 2：排除特定路径

```cj
import tang.middleware.csrf.{csrf, withExcludePath}

let r = Router()

r.use(csrf([
    withExcludePath([
        "/api/public",       // 不验证此路径
        "/api/webhook/*",    // 不验证 webhook 路径
        "/api/health"        // 健康检查不需要 CSRF
    ])
]))

// 公开端点（不需要 CSRF Token）
r.post("/api/webhook/payment", { ctx =>
    // 处理第三方支付平台的通知
    ctx.json(HashMap<String, String>([
            ("status", "received")
        ]))
})

// 受保护的端点（需要 CSRF Token）
r.post("/api/transfer", { ctx =>
    // CSRF 中间件已验证 Token
    ctx.json(HashMap<String, String>([
            ("message", "Transfer completed")
        ]))
})
```

### 示例 3：从多个位置查找 Token

```cj
import tang.middleware.csrf.{csrf, withTokenLookup}

let r = Router()

// 配置多个 Token 查找位置（优先级从高到低）
r.use(csrf([
    withTokenLookup("header:X-CSRF-Token"),        // 1. 优先从请求头
    withTokenLookup("query:csrf_token"),           // 2. 其次从查询参数
    withTokenLookup("form:_csrf_token")            // 3. 最后从表单字段
]))

r.post("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Success")
        ]))
})
```

### 示例 4：AJAX 和传统表单混合使用

```cj
import tang.middleware.csrf.{csrf, withTokenLookup}

let r = Router()

r.use(csrf([
    // 支持多种 Token 传递方式
    withTokenLookup("header:X-CSRF-Token"),
    withTokenLookup("form:csrf_token")
]))

// 1. AJAX 端点（从请求头获取 Token）
r.post("/api/ajax-action", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "AJAX action completed")
        ]))
})

// 2. 传统表单端点（从表单字段获取 Token）
r.post("/api/form-action", { ctx =>
    let csrfToken = ctx.fromValue("csrf_token")
    // CSRF 已验证
    ctx.json(HashMap<String, String>([
            ("message", "Form submitted")
        ]))
})

// 提供 Token 的端点
r.get("/csrf/token", { ctx =>
    let token = ctx.csrfToken().getOrThrow()

    // 返回 Token 和表单字段名
    ctx.json(HashMap<String, String>([
            ("headerName", "X-CSRF-Token"),
            ("formFieldName", "csrf_token")
        ]))
})
```

## 测试

### 测试 Token 生成

```bash
# 获取 CSRF Token
curl http://localhost:8080/csrf/token

# 响应：
# {
#   "token": "abc123.signature.1234567890",
#   "headerName": "X-CSRF-Token"
# }
```

### 测试受保护的端点

```bash
# ❌ 无 Token：请求被拒绝
curl -X POST http://localhost:8080/api/users
# HTTP 403 Forbidden
# {
#   "error": "CSRF token validation failed"
# }

# ✅ 有效 Token：请求成功
curl -X POST http://localhost:8080/api/users \
  -H "X-CSRF-Token: abc123.signature.1234567890" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test"}'
# HTTP 200 OK
# {"message":"User created"}
```

### 测试排除路径

```bash
# 公开端点：不需要 Token
curl -X POST http://localhost:8080/api/public/webhook
# HTTP 200 OK
# {"status":"received"}
```

## 工作原理

### Token 生成

CSRF Token 包含三个部分，用 `.` 分隔：

```
token.signature.timestamp
```

- **token**：随机生成的令牌（32 字节）
- **signature**：HMAC-SHA256 签名（用于验证 Token 有效性）
- **timestamp**：时间戳（用于检查 Token 是否过期）

### 签名过程

```cj
// 1. 生成随机 token
let token = generateRandomToken(32)

// 2. 获取当前时间戳
let timestamp = DateTime.now().toUnixTimeStamp()

// 3. 计算签名
let data = "${token}.${timestamp}"
let signature = hmac_sha256(secret_key, data)

// 4. 组合完整 Token
let csrfToken = "${token}.${signature}.${timestamp}"
```

### 验证过程

```cj
// 1. 解析 Token
let parts = csrfToken.split(".")
let token = parts[0]
let signature = parts[1]
let timestamp = parts[2]

// 2. 检查时间戳（是否过期）
if (DateTime.now().toUnixTimeStamp() - timestamp > expiration) {
    return None  // Token 过期
}

// 3. 重新计算签名并比对
let data = "${token}.${timestamp}"
let expectedSignature = hmac_sha256(secret_key, data)

if (signature != expectedSignature) {
    return None  // 签名不匹配，Token 无效
}

return Some(token)  // Token 有效
```

> **💡 提示：CSRF 攻击原理**
>
> **CSRF（Cross-Site Request Forgery）**：
> - 攻击者诱导用户在已登录的网站上执行非预期操作
> - 用户浏览器会自动携带 Cookie，服务器无法区分是用户主动操作还是被诱导
>
> **示例攻击场景**：
> ```
> 1. 用户登录了银行网站 bank.com（有 Cookie）
> 2. 用户访问了恶意网站 evil.com
> 3. evil.com 页面包含隐藏的表单：
>    <form action="https://bank.com/transfer" method="POST">
>      <input name="to" value="attacker">
>      <input name="amount" value="10000">
>    </form>
>    <script>document.forms[0].submit();</script>
> 4. 浏览器自动提交表单，携带 Cookie
> 5. 银行服务器认为是用户主动操作，执行转账
> ```
>
> **CSRF Token 防护**：
> - 服务器生成随机 Token，返回给客户端
> - 客户端提交表单时必须携带 Token
> - 恶意网站无法获取到 Token（跨域限制），无法伪造请求

## 注意事项

### 1. 密钥安全

生产环境必须使用强随机密钥，并定期更换：

```cj
// ❌ 错误：使用弱密钥
r.use(csrf([
    withSecretKey("secret")  // 太简单，容易被破解
]))

// ❌ 错误：硬编码密钥
r.use(csrf([
    withSecretKey("my-app-secret-key-12345")  // 暴露在代码中
]))

// ✅ 正确：从环境变量读取
let secretKey = Env.get("CSRF_SECRET_KEY") ?? generateRandomKey(64)
r.use(csrf([
    withSecretKey(secretKey)
]))
```

### 2. Token 过期时间

合理设置 Token 过期时间：

```cj
// ❌ 太短：用户体验差
r.use(csrf([withExpiration(60)]))  // 仅 1 分钟

// ❌ 太长：安全风险
r.use(csrf([withExpiration(8640000)]))  // 100 天

// ✅ 合理：平衡安全性和用户体验
r.use(csrf([withExpiration(3600)]))  // 1 小时
```

### 3. GET 请求不需要 CSRF Token

CSRF 保护主要应用于状态改变的操作（POST、PUT、DELETE）：

```cj
// ✅ 正确：只保护状态改变的操作
r.get("/api/users", { ctx => ... })  // 读取数据，不需要 CSRF
r.post("/api/users", { ctx => ... }) // 创建数据，需要 CSRF

// ❌ 不必要：为 GET 请求启用 CSRF
r.use(csrf())  // 会影响所有请求，包括 GET
```

如果需要为所有方法启用 CSRF，应该在配置中排除安全的方法：

```cj
func conditionalCSRF(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // GET、HEAD、OPTIONS 不需要 CSRF
            if (ctx.method() == "GET" || ctx.method() == "HEAD" || ctx.method() == "OPTIONS") {
                next(ctx)
            } else {
                // 其他方法需要 CSRF 验证
                let csrfMiddleware = csrf()
                csrfMiddleware(next)(ctx)
            }
        }
    }
}
```

### 4. 与 CORS 配合使用

如果使用 CORS，需要正确配置：

```cj
import tang.middleware.cors.{cors, withOrigins, withCredentials}

r.use(cors([
    withOrigins(["https://example.com"]),
    withCredentials(true)  // 允许发送凭据
]))

r.use(csrf())  // CSRF 会验证 Origin
```

### 5. Token 存储

CSRF Token 需要在服务器端存储（通常是 Session 或内存）：

```cj
// CSRF 中间件自动将 Token 存储到 context
// 在 Token 生成端点读取并返回
r.get("/csrf/token", { ctx =>
    let token = ctx.csrfToken().getOrThrow()
    ctx.json(HashMap<String, String>([
            ("token", token)
        ]))
})
```

## 常见问题

### 问题 1：Token 验证失败

**原因**：
- Token 格式错误
- Token 已过期
- 签名不匹配（密钥不一致）

**解决**：
```cj
// 调试模式：打印详细信息
r.use(csrf([
    withSecretKey("your-secret-key"),
    withExpiration(3600),
    withDebugMode(true)  // 启用调试日志
]))
```

### 问题 2：每次请求都生成新 Token

**原因**：每次请求都调用了 `/csrf/token` 端点

**解决**：前端应该缓存 Token，在多个请求中复用

```javascript
// ❌ 错误：每次请求都获取新 Token
async function postData(data) {
    const token = await getCSRFToken();  // 每次都获取
    return fetch('/api/data', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: JSON.stringify(data)
    });
}

// ✅ 正确：缓存 Token
let csrfToken = null;

async function initCSRF() {
    if (!csrfToken) {
        const response = await fetch('/csrf/token');
        const data = await response.json();
        csrfToken = data.token;
    }
}

async function postData(data) {
    await initCSRF();  // 只获取一次
    return fetch('/api/data', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify(data)
    });
}
```

### 问题 3：多实例部署 Token 不一致

**原因**：每个实例生成不同的 Token

**解决**：使用共享存储（Redis、Memcached）存储 Token

```cj
func redisCSRF(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let tokenID = ctx.cookie("csrf_token_id")

            match (tokenID) {
                case Some(id) =>
                    // 从 Redis 获取 Token
                    let token = redis.get("csrf:${id}")

                    if (token != None) {
                        ctx.kvSet("csrf_token", token)
                    }
                }
                case None =>
                    // 生成新 Token 并存储到 Redis
                    let newToken = generateCSRFToken()
                    let tokenID = generateUUID()

                    redis.set("csrf:${tokenID}", newToken, ex: 3600)
                    ctx.setSimpleCookie("csrf_token_id", tokenID)
                    ctx.kvSet("csrf_token", newToken)
                }
            }

            next(ctx)
        }
    }
}
```

## 相关链接

- **[Session 中间件](session.md)** - 会话管理
- **[Security 中间件](security.md)** - 安全响应头
- **[CORS 中间件](cors.md)** - 跨域资源共享
- **[源码](../../../src/middleware/csrf/csrf.cj)** - CSRF 源代码
