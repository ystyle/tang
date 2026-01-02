# Idempotency - 幂等性控制

## 概述

- **功能**：防止重复提交，确保相同请求只处理一次
- **分类**：高级功能
- **文件**：`src/middleware/idempotency/idempotency.cj`

Idempotency 中间件通过缓存响应来防止重复提交。客户端提供幂等 Key（Idempotency Key），服务器使用该 Key 缓存响应，后续相同 Key 的请求直接返回缓存结果。

> **💡 提示：什么是幂等性？**
>
> **幂等性（Idempotency）定义**：
> - 相同操作执行多次，结果与执行一次相同
> - f(x) = f(f(x))
>
> **现实场景**：
> - **支付接口**：用户点击"支付"按钮多次，只扣款一次
> - **订单创建**：网络超时重试，不创建重复订单
> - **库存扣减**：重复请求不会重复扣减库存
>
> **HTTP 方法幂等性**：
> - **GET, HEAD**：天然幂等（只读取）
> - **PUT, DELETE**：设计为幂等（更新/删除同一资源）
> - **POST**：非幂等（每次创建新资源）⚠️
>
> **建议**：
> - 对 POST 操作（支付、订单、创建资源）使用幂等性控制
> - 对 GET 操作无需使用（已天然幂等）

## 签名

```cj
public func idempotency(): MiddlewareFunc
public func idempotency(opts: Array<IdempotencyOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withKeyHeader()` | `String` | `"X-Idempotency-Key"` | 幂等 Key 的 Header 名称 |
| `withLifetime()` | `Int64` | `3600`（1小时） | 缓存生命周期（秒） |
| `withExcludePath()` | `String` | - | 添加排除的路径 |
| `withExcludedPaths()` | `Array<String>` | - | 批量添加排除路径 |
| `withExcludedMethods()` | `Array<String>` | `["GET", "HEAD", "OPTIONS"]` | 排除的 HTTP 方法 |
| `withKeyLookup()` | `String` | `"header:X-Idempotency-Key"` | Key 查找位置 |
| `withErrorHandler()` | `(TangHttpContext) -> Unit` | - | 自定义错误处理器 |

## 快速开始

### 基础用法

```cj
import tang.middleware.idempotency.idempotency

let r = Router()

// 应用幂等性中间件
r.use(idempotency())

r.post("/api/payment", { ctx =>
    // 处理支付逻辑（只会执行一次）
    processPayment()

    ctx.json(HashMap<String, String>([
            ("status", "success"),
            ("transactionId", "txn_12345")
        ]))
})
```

**客户端请求**：
```bash
# 第一次请求：执行支付
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{"amount":100,"currency":"USD"}'

# 响应：200 OK
# {"status":"success","transactionId":"txn_12345"}

# 第二次请求（相同 Key）：返回缓存的响应
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{"amount":100,"currency":"USD"}'

# 响应：200 OK（缓存的响应，不执行支付逻辑）
# {"status":"success","transactionId":"txn_12345"}
```

### 自定义配置

```cj
import tang.middleware.idempotency.{idempotency, withLifetime, withKeyHeader}

let r = Router()

r.use(idempotency([
    withKeyHeader("X-Unique-Key"),    // 自定义 Header 名称
    withLifetime(7200)                 // 2 小时过期
]))

r.post("/api/orders", { ctx =>
    createOrder()
    ctx.json(HashMap<String, String>([
            ("orderId", "order-123")
        ]))
})
```

## 完整示例

### 示例 1：支付接口幂等性

```cj
import tang.*
import tang.middleware.idempotency.{idempotency, withLifetime}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())

    // 应用幂等性中间件
    r.use(idempotency([
        withLifetime(3600)  // 缓存 1 小时
    ]))

    // 支付接口
    r.post("/api/payment", { ctx =>
        let amount = ctx.fromValue("amount") ?? "0"

        // 模拟支付处理
        println("Processing payment: ${amount} USD")

        // 生成交易 ID
        let transactionId = "txn_${DateTime.now().toUnixTimeStamp()}"

        ctx.json(HashMap<String, String>([
            ("status", "success"),
            ("currency", "USD")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**测试**：
```bash
# 生成幂等 Key（UUID）
IDEMPOTENCY_KEY=$(uuidgen)

# 第一次请求：执行支付
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
  -d '{"amount":100}'

# 第二次请求：返回缓存（不执行支付）
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
  -d '{"amount":100}'
```

### 示例 2：排除某些路径

```cj
import tang.middleware.idempotency.{idempotency, withExcludedPaths}

let r = Router()

r.use(idempotency([
    withExcludedPaths([
        "/api/test/*",      // 测试路径不使用幂等性
        "/api/webhook/"     // Webhook 不使用幂等性
    ])
]))

// 需要幂等性
r.post("/api/payment", { ctx =>
    processPayment()
    ctx.json(HashMap<String, String>([
            ("status", "success")
        ]))
})

// 不需要幂等性（已排除）
r.post("/api/webhook/stripe", { ctx =>
    // 每次 webhook 回调都会执行
    handleWebhook()
    ctx.json(HashMap<String, String>([
            ("received", "ok")
        ]))
})
```

### 示例 3：自定义错误处理

```cj
import tang.middleware.idempotency.{idempotency, withErrorHandler}

let r = Router()

r.use(idempotency([
    withErrorHandler({ ctx =>
        // 自定义错误响应
        ctx.responseBuilder.status(400u16)
        ctx.responseBuilder.header("Content-Type", "application/json")
        ctx.responseBuilder.body(
            "{" +
            "\"error\":\"Missing idempotency key\"," +
            "\"message\":\"Please provide X-Idempotency-Key header\"" +
            "}"
        )
    })
]))

r.post("/api/orders", { ctx =>
    createOrder()
    ctx.json(HashMap<String, String>([
            ("orderId", "order-123")
        ]))
})
```

**缺少幂等 Key 时的响应**：
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Missing idempotency key",
  "message": "Please provide X-Idempotency-Key header"
}
```

### 示例 4：从 Query 参数获取 Key

```cj
import tang.middleware.idempotency.{idempotency, withKeyLookup}

let r = Router()

r.use(idempotency([
    withKeyLookup("query:idempotency_key")  // 从 query 参数获取
]))

r.post("/api/payment", { ctx =>
    processPayment()
    ctx.json(HashMap<String, String>([
            ("status", "success")
        ]))
})
```

**客户端请求**：
```bash
# 使用 query 参数传递幂等 Key
curl -X POST "http://localhost:8080/api/payment?idempotency_key=unique-key-123" \
  -d '{"amount":100}'
```

### 示例 5：结合认证使用

```cj
import tang.middleware.idempotency.{idempotency, withKeyHeader}
import tang.middleware.keyauth.{keyAuth, withKey}

let r = Router()

// 先认证，再幂等性检查
r.use(keyAuth([withKey("secret-api-key")]))
r.use(idempotency([withKeyHeader("X-Idempotency-Key")]))

r.post("/api/payment", { ctx =>
    // 获取认证用户
    let apiKey = ctx.request.headers.getFirst("X-API-Key").getOrThrow()

    // 获取幂等 Key
    let idempotencyKey = ctx.request.headers.getFirst("X-Idempotency-Key").getOrThrow()

    println("Processing payment for API key: ${apiKey}, idempotency: ${idempotencyKey}")

    processPayment()

    ctx.json(HashMap<String, String>([
            ("status", "success"),
            ("transactionId", "txn_12345")
        ]))
})
```

## 工作原理

### 幂等性流程

```
1. 客户端发送请求（带幂等 Key）
   POST /api/payment
   X-Idempotency-Key: unique-key-123
   ↓
2. 服务器检查缓存
   let cached = store.get("unique-key-123")
   ↓
3a. 缓存存在 → 返回缓存响应（不执行业务逻辑）
    HTTP/1.1 200 OK
    {"status":"success","transactionId":"txn_12345"}

3b. 缓存不存在 → 执行业务逻辑 + 缓存响应
    执行支付逻辑
    store.set("unique-key-123", response)
    HTTP/1.1 200 OK
    {"status":"success","transactionId":"txn_12345"}
```

### Key 生成

**方式 1：客户端提供（推荐）**

```bash
# 客户端生成唯一 Key（UUID、时间戳等）
curl -H "X-Idempotency-Key: $(uuidgen)" -X POST http://localhost/api/payment
```

**方式 2：服务器自动生成**

```cj
// 基于：method + path + query + sessionID + body 生成 SHA256 哈希
let key = config.generateKey(ctx, None)
// 例如："a3f5b8c9d2e1f4a6..."
```

### 缓存存储

```cj
class CachedResponse {
    var statusCode: UInt16
    var body: String
    var timestamp: Int64  // Unix 时间戳
}

class IdempotencyStore {
    var cache: HashMap<String, CachedResponse>  // 内存存储
    var mutex: Mutex  // 并发安全
    var lifetime: Int64  // 过期时间
}
```

**存储结构**：
```
Key: "unique-key-123"
Value: {
    statusCode: 200,
    body: "{\"status\":\"success\",\"transactionId\":\"txn_12345\"}",
    timestamp: 1704067200
}
```

## 测试

### 测试幂等性

```bash
# 生成唯一 Key
KEY="test-key-$(date +%s)"

# 第一次请求：执行逻辑
curl -i -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $KEY" \
  -d '{"amount":100}'

# 响应：200 OK
# {"status":"success","transactionId":"txn_12345"}

# 第二次请求：返回缓存
curl -i -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $KEY" \
  -d '{"amount":200}'

# 响应：200 OK（相同的响应，amount 仍然是 100）
# {"status":"success","transactionId":"txn_12345"}
```

### 测试缓存过期

```bash
# 发送请求（缓存 5 秒过期）
KEY="test-key-$(date +%s)"
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $KEY" \
  -d '{"amount":100}'

# 等待 6 秒（缓存过期）
sleep 6

# 再次请求：执行新逻辑（缓存已过期）
curl -X POST http://localhost:8080/api/payment \
  -H "X-Idempotency-Key: $KEY" \
  -d '{"amount":100}'
```

### 测试缺少 Key

```bash
# 不提供幂等 Key
curl -i -X POST http://localhost:8080/api/payment \
  -d '{"amount":100}'

# 响应：400 Bad Request
# {"error":"Missing or invalid idempotency key"}
```

## 客户端实现

### JavaScript/TypeScript

```typescript
// 幂等性 Key 生成
function generateIdempotencyKey(): string {
  return `idemp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// 支付请求
async function createPayment(amount: number) {
  const idempotencyKey = generateIdempotencyKey();

  try {
    const response = await fetch('http://localhost:8080/api/payment', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Idempotency-Key': idempotencyKey,
      },
      body: JSON.stringify({ amount }),
    });

    const data = await response.json();

    // 保存幂等 Key（用于重试）
    localStorage.setItem('last_payment_key', idempotencyKey);

    return data;
  } catch (error) {
    // 网络错误：使用相同的 Key 重试
    const lastKey = localStorage.getItem('last_payment_key');
    if (lastKey) {
      return createPaymentWithKey(lastKey, amount);
    }
    throw error;
  }
}

// 使用指定 Key 发送请求
async function createPaymentWithKey(key: string, amount: number) {
  const response = await fetch('http://localhost:8080/api/payment', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Idempotency-Key': key,
    },
    body: JSON.stringify({ amount }),
  });

  return response.json();
}
```

### Python

```python
import uuid
import requests

def create_payment(amount: float):
    # 生成幂等性 Key
    idempotency_key = str(uuid.uuid4())

    headers = {
        'Content-Type': 'application/json',
        'X-Idempotency-Key': idempotency_key,
    }

    data = {'amount': amount}

    try:
        response = requests.post(
            'http://localhost:8080/api/payment',
            headers=headers,
            json=data,
            timeout=10
        )

        response.raise_for_status()
        return response.json()

    except requests.exceptions.RequestException as e:
        # 网络错误：使用相同的 Key 重试
        print(f"Request failed: {e}, retrying with same key...")
        return create_payment_with_key(idempotency_key, amount)

def create_payment_with_key(key: str, amount: float):
    headers = {
        'Content-Type': 'application/json',
        'X-Idempotency-Key': key,
    }

    response = requests.post(
        'http://localhost:8080/api/payment',
        headers=headers,
        json={'amount': amount}
    )

    response.raise_for_status()
    return response.json()

# 使用
result = create_payment(100.0)
print(result)
```

## 最佳实践

### 1. Key 生成策略

```cj
// ✅ 推荐：客户端生成唯一 Key
// - UUID
// - timestamp + random
// - 用户ID + timestamp + random

// ❌ 不推荐：服务器自动生成
// - 可能导致相同请求生成不同 Key
// - 无法跨服务共享 Key
```

**客户端生成 Key 的优势**：
- 客户端可以保存 Key，用于重试
- 可以跨多个服务共享 Key
- 确保相同请求使用相同 Key

### 2. 缓存生命周期

```cj
// 支付：1 小时
r.post("/api/payment", { ctx =>
    // ...
})
r.use(idempotency([withLifetime(3600)]))

// 订单创建：24 小时
r.post("/api/orders", { ctx =>
    // ...
})
r.use(idempotency([withLifetime(86400)]))

// 临时操作：5 分钟
r.post("/api/verification", { ctx =>
    // ...
})
r.use(idempotency([withLifetime(300)]))
```

**选择建议**：
- 短期操作（验证码）：5-15 分钟
- 业务操作（支付、订单）：1-24 小时
- 长期资源（创建资源）：24-48 小时

### 3. 结合数据库事务

```cj
r.post("/api/payment", { ctx =>
    let idempotencyKey = ctx.kvGet<String>("idempotency_key").getOrThrow()

    // 检查数据库是否已处理
    let existingPayment = getPaymentByIdempotencyKey(idempotencyKey)
    match (existingPayment) {
        case Some(payment) =>
            // 已处理，返回原有结果
            ctx.json(HashMap<String, String>([
            ("status", "success")
        ]))
            return
        case None => ()
    }

    // 执行支付逻辑（事务）
    let transactionId = processPayment()

    // 保存幂等 Key 和结果
    savePayment(idempotencyKey, transactionId)

    ctx.json(HashMap<String, String>([
            ("status", "success")
        ]))
})
```

### 4. 外部存储（Redis）

```cj
// 生产环境建议使用 Redis 存储幂等性缓存
class RedisIdempotencyStore {
    let redis: RedisClient

    public func get(key: String): ?CachedResponse {
        let data = redis.get("idempotency:${key}")
        match (data) {
            case Some(json) => Some(parseJSON(json))
            case None => None
        }
    }

    public func set(key: String, response: CachedResponse, lifetime: Int64) {
        redis.setex("idempotency:${key}", lifetime, response.toJSON())
    }
}

func redisIdempotencyStore(lifetime: Int64): RedisIdempotencyStore {
    RedisIdempotencyStore(redis, lifetime)
}
```

## 注意事项

### 1. GET 请求默认排除

```cj
// GET、HEAD、OPTIONS 默认排除（无需幂等性）
// 原因：这些方法是安全的、天然的幂等

r.get("/api/users", { ctx =>
    // GET 不会使用幂等性检查
    ctx.json(usersData)
})
```

### 2. 响应缓存限制

当前实现只缓存**状态码和响应体**，不缓存 Headers：

```cj
class CachedResponse {
    var statusCode: UInt16
    var body: String
    // ❌ 不包含 headers
}
```

**建议**：确保响应不依赖动态 Headers（如 Set-Cookie）

### 3. 并发请求

```cj
// 场景：多个并发请求使用相同幂等 Key
// 结果：只有一个请求会执行，其他返回缓存

// 客户端：3 个并发请求
let promises = [
    fetch("/api/payment", { headers: { "X-Idempotency-Key": "same-key" }}),
    fetch("/api/payment", { headers: { "X-Idempotency-Key": "same-key" }}),
    fetch("/api/payment", { headers: { "X-Idempotency-Key": "same-key" }})
]

// 服务器：只执行一次，其他返回缓存
```

**保护机制**：IdempotencyStore 使用 Mutex 保证并发安全

### 4. 内存限制

```cj
// ❌ 问题：大量幂等 Key 占用内存
let store = IdempotencyStore(3600)  // 1 小时
// 100 万个请求 ≈ 数百 MB 内存

// ✅ 解决方案 1：使用 Redis
// ✅ 解决方案 2：定期清理过期缓存
func cleanupTask() {
    while (true) {
        sleep(60000)  // 每分钟
        store.cleanup()
    }
}

spawn { cleanupTask() }
```

## 常见问题

### 问题 1：为什么相同请求返回不同结果

**原因**：
1. 没有提供幂等 Key
2. 每次请求使用不同的 Key
3. 缓存已过期

**排查**：
```cj
r.post("/api/test", { ctx =>
    let key = ctx.request.headers.getFirst("X-Idempotency-Key")
    println("Idempotency Key: ${key}")

    // 检查是否缓存
    let cached = ctx.kvGet<IdempotencyStore>("idempotency_store")
    match (cached) {
        case Some(store) =>
            let response = store.get(key.getOrThrow())
            println("Cached: ${response}")
        case None => ()
    }

    ctx.json(HashMap<String, String>([
            ("data", "test")
        ]))
})
```

### 问题 2：缓存多久过期？

**默认**：1 小时（3600 秒）

**自定义**：
```cj
idempotency([withLifetime(86400)])  // 24 小时
```

### 问题 3：如何手动清除缓存？

```cj
// 访问内部 store
let store = config.store

// 手动删除
store.cache.remove("specific-key")

// 或调用清理方法（删除所有过期）
store.cleanup()
```

## 相关链接

- **[源码](../../../src/middleware/idempotency/idempotency.cj)** - Idempotency 源代码
