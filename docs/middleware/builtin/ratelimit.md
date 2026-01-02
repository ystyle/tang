# RateLimit - 请求速率限制

## 概述

- **功能**：限制客户端的请求速率，防止接口滥用
- **分类**：流量控制
- **文件**：`src/middleware/ratelimit/ratelimit.cj`

RateLimit 中间件使用滑动窗口算法限制客户端的请求速率，防止 API 被滥用、DDoS 攻击或资源耗尽。

## 签名

```cj
public func ratelimit(): MiddlewareFunc
public func ratelimit(opts: Array<RateLimitOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withMaxRequests()` | `Int32` | `100` | 时间窗口内允许的最大请求数 |
| `withWindowMs()` | `Int64` | `60000` | 时间窗口大小（毫秒，默认60秒） |
| `withClientID()` | `(TangHttpContext) -> String` | IP 地址 | 客户端标识函数 |

## 快速开始

### 基础用法（基于 IP 限流）

```cj
import tang.middleware.ratelimit.ratelimit

let r = Router()

// 每分钟最多 100 个请求（基于 IP）
r.use(ratelimit())

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello!")
        ]))
})
```

**响应**：
- 正常请求：`200 OK`
- 超出限制：`429 Too Many Requests`
  ```json
  {
    "error": "Rate limit exceeded",
    "message": "Too many requests. Please try again later."
  }
  ```

### 带配置的用法

```cj
import tang.middleware.ratelimit.{ratelimit, withMaxRequests, withWindowMs}

let r = Router()

// 每秒最多 10 个请求
r.use(ratelimit([
    withMaxRequests(10),
    withWindowMs(1000)  // 1 秒窗口
]))

r.get("/api/search", { ctx =>
    ctx.json(HashMap<String, String>([
            ("results", "[]")
        ]))
})
```

### 自定义客户端标识

```cj
import tang.middleware.ratelimit.{ratelimit, withClientID}

let r = Router()

// 基于 API Key 限流（而非 IP）
r.use(ratelimit([
    withClientID({ ctx =>
        // 优先使用 API Key，其次使用 IP
        let apiKey = ctx.getHeader("X-API-Key")
        match (apiKey) {
            case Some(key) => key
            case None => ctx.ip()
        }
    })
]))

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

## 完整示例

### 示例 1：API 分级限流

```cj
import tang.*
import tang.middleware.ratelimit.{ratelimit, withMaxRequests, withWindowMs}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 公开 API：宽松限制
    let publicAPI = r.group("/api/public")
    publicAPI.use(ratelimit([
        withMaxRequests(100),
        withWindowMs(60000)  // 每分钟 100 次
    ]))

    publicAPI.get("/search", { ctx =>
        ctx.json(ArrayList<String>())
    })

    // 免费 API：中等限制
    let freeAPI = r.group("/api/free")
    freeAPI.use(ratelimit([
        withMaxRequests(1000),
        withWindowMs(3600000)  // 每小时 1000 次
    ]))

    freeAPI.get("/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
    })

    // 付费 API：严格限制
    let paidAPI = r.group("/api/paid")
    paidAPI.use(ratelimit([
        withMaxRequests(10000),
        withWindowMs(3600000)  // 每小时 10000 次
    ]))

    paidAPI.get("/premium", { ctx =>
        ctx.json(HashMap<String, String>([
            ("premium", "data")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：基于用户的限流

```cj
import tang.middleware.ratelimit.{ratelimit, withClientID}

func userBasedRateLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 从 session 或 token 获取用户 ID
            let userID = ctx.kvGet<String>("user_id")

            let clientID = match (userID) {
                case Some(id) => id  // 已认证用户：基于用户 ID
                case None => ctx.ip()  // 未认证：基于 IP
            }

            // 应用限流
            let limiter = ratelimit([
                withMaxRequests(100),
                withWindowMs(60000),
                withClientID({ _ => clientID })  // 使用固定的 clientID
            ])

            // 执行限流中间件
            let limited = limiter(next)
            limited(ctx)
        }
    }
}

let r = Router()
r.use(authMiddleware())
r.use(userBasedRateLimit())
```

### 示例 3：自定义限流响应

```cj
import tang.middleware.ratelimit.{ratelimit, withMaxRequests, withWindowMs, withLimitHandler}

let r = Router()

r.use(ratelimit([
    withMaxRequests(10),
    withWindowMs(1000),
    withLimitHandler({ ctx =>
        // 自定义限流响应
        ctx.responseBuilder
            .status(429u16)
            .header("Content-Type", "application/json")
            .header("X-RateLimit-Limit", "10")
            .header("X-RateLimit-Remaining", "0")
            .header("X-RateLimit-Reset", "${DateTime.now().toUnixTimeStamp() + 60}")
            .body("""
                {
                    "error": "Rate limit exceeded",
                    "message": "Too many requests. Maximum 10 requests per second.",
                    "retry_after": 60
                }
                """)
    })
]))

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

### 示例 4：动态限流配置

```cj
import tang.middleware.ratelimit.{ratelimit, withMaxRequests, withWindowMs}

func dynamicRateLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 根据用户类型动态设置限流
            let userType = ctx.kvGet<String>("user_type")

            let (maxRequests, windowMs) = match (userType) {
                case Some(t) =>
                    if (t == "premium") {
                        (10000, 3600000)  // 付费用户：每小时 10000 次
                    } else if (t == "free") {
                        (1000, 3600000)   // 免费用户：每小时 1000 次
                    } else {
                        (100, 60000)     // 默认：每分钟 100 次
                    }
                case None => (100, 60000)
            }

            // 应用动态限流
            let limiter = ratelimit([
                withMaxRequests(maxRequests),
                withWindowMs(windowMs)
            ])

            limiter(next)(ctx)
        }
    }
}

let r = Router()
r.use(authMiddleware())
r.use(dynamicRateLimit())
```

## 测试

```bash
# 测试正常请求
for i in {1..10}; do
  curl http://localhost:8080/api/data
done
# 前 10 个请求应该成功

# 测试超出限制
curl http://localhost:8080/api/data
# HTTP 429 Too Many Requests
# {"error":"Rate limit exceeded"}
```

### 检查限流状态头

```bash
curl -I http://localhost:8080/api/data

# 响应头：
# X-RateLimit-Limit: 100
# X-RateLimit-Remaining: 95
# X-RateLimit-Reset: 1704234567
```

## 工作原理

### 滑动窗口算法

RateLimit 使用滑动窗口算法跟踪请求：

```
时间窗口（60秒）：
[━━━━━━━━━━━━━━━━━━━━━━━━━━] 当前时间
 ↑                    ↑
 起点                当前

统计当前窗口内的请求数：
- 如果请求数 < 最大值：允许请求
- 如果请求数 >= 最大值：拒绝请求
```

### 窗口滑动

```
窗口 1：[请求1, 请求2, ..., 请求100] → 100 个请求
时间流逝...

窗口 2：      [请求2, ..., 请求100, 请求101] → 100 个请求
           ↑ 旧请求过期，新请求加入

窗口 3：           [..., 请求100, 请求101, 请求102] → 100 个请求
```

> **💡 提示：滑动窗口 vs 固定窗口**
>
> **固定窗口**：
> - 时间被分割为固定间隔（如每分钟）
> - 在窗口边界可能出现"双倍流量"问题
> - 实现简单，但不够平滑
>
> **滑动窗口**（RateLimit 使用）：
> - 窗口随时间平滑滑动
> - 请求分布更均匀
> - 更精确的限流控制

## 注意事项

### 1. 限流粒度选择

根据业务需求选择合适的限流粒度：

```cj
// ❌ 太粗：基于整个应用限流
r.use(ratelimit([withMaxRequests(1000)]))  // 所有用户共享 1000 次

// ✅ 合理：基于单个客户端限流
r.use(ratelimit([
    withMaxRequests(100),
    withClientID({ ctx => ctx.ip() })  // 每个 IP 独立限流
]))

// ✅ 合理：基于用户限流
r.use(ratelimit([
    withMaxRequests(100),
    withClientID({ ctx =>
        ctx.kvGet<String>("user_id") ?? ctx.ip()
    })
]))
```

### 2. 限流参数合理设置

避免设置过严或过松：

```cj
// ❌ 太严：正常用户也会受影响
r.use(ratelimit([
    withMaxRequests(5),      // 每分钟仅 5 次
    withWindowMs(60000)
]))

// ❌ 太松：无法防止滥用
r.use(ratelimit([
    withMaxRequests(1000000),  // 每分钟 100 万次
    withWindowMs(60000)
]))

// ✅ 合理：根据实际业务量设置
r.use(ratelimit([
    withMaxRequests(100),   // 每分钟 100 次
    withWindowMs(60000)
]))
```

### 3. 重要 API 更严格的限流

对重要或资源密集型 API 设置更严格的限制：

```cj
// 普通 API
r.get("/api/list", { ctx => ... })
  .use(ratelimit([withMaxRequests(100), withWindowMs(60000)]))

// 重要 API：更严格
r.post("/api/export", { ctx => ... })
  .use(ratelimit([withMaxRequests(10), withWindowMs(3600000)]))  // 每小时 10 次
```

### 4. 限流状态监控

记录限流事件，监控异常：

```cj
func monitoredRateLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let limiter = ratelimit([
                withMaxRequests(100),
                withWindowMs(60000),
                withLimitHandler({ ctx =>
                    // 记录限流事件
                    println("[RATE_LIMIT] ${ctx.ip()} exceeded limit")

                    // 返回响应
                    ctx.status(429).json(HashMap<String, String>([
            ("error", "Rate limit exceeded")
        ]))
                })
            ])

            limiter(next)(ctx)
        }
    }
}
```

### 5. 与缓存配合使用

对于高并发场景，使用分布式缓存：

```cj
// 使用 Redis 存储计数（支持多实例部署）
func redisRateLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let clientID = ctx.ip()
            let key = "ratelimit:${clientID}"

            // 从 Redis 获取当前计数
            let count = redis.get(key)

            if (count >= 100) {
                ctx.status(429).json(HashMap<String, String>([
            ("error", "Rate limit exceeded")
        ]))
                return
            }

            // 增加计数
            redis.incr(key)
            redis.expire(key, 60)  // 60 秒过期

            next(ctx)
        }
    }
}
```

## 常见问题

### 问题 1：局域网多个用户被一起限流

**原因**：多个用户共享同一个公网 IP

**解决**：
```cj
// 基于 Cookie/Session 限流，而非 IP
r.use(ratelimit([
    withClientID({ ctx =>
        ctx.cookie("session_id") ?? ctx.ip()
    })
]))
```

### 问题 2：限流计数不准确

**原因**：未使用持久化存储，多实例部署时计数不共享

**解决**：使用 Redis 等分布式存储（参考上面的示例）

## 相关链接

- **[BodyLimit 中间件](bodylimit.md)** - 请求体大小限制
- **[Timeout 中间件](../builtin/timeout.md)** - 请求超时控制
- **[源码](../../../src/middleware/ratelimit/ratelimit.cj)** - RateLimit 源代码
