# Timeout - 请求超时控制

## 概述

- **功能**：记录请求开始时间，支持超时检查
- **分类**：路由与请求控制
- **文件**：`src/middleware/timeout/timeout.cj`

Timeout 中间件记录请求开始时间，提供超时检查功能，用于防止慢请求占用资源。

> **💡 提示：同步执行模型的限制**
>
> **仓颉的同步执行**：
> - 代码是同步执行的（不支持异步/await）
> - 超时不能强制中断正在执行的代码
> - 只能在代码执行点检查超时
>
> **实际应用**：
> - 在长时间循环中检查超时
> - 在数据库操作前检查超时
> - 在外部 API 调用前检查超时
>
> **建议**：
> - 对于数据库操作，使用数据库驱动的超时配置
> - 对于 HTTP 请求，使用 HTTP 客户端的超时配置
> - 对于循环操作，定期检查超时

## 签名

```cj
public func timeout(): MiddlewareFunc
public func timeout(opts: Array<TimeoutOption>): MiddlewareFunc

// 辅助函数
public func isTimeout(ctx: TangHttpContext): Bool
public func getElapsedMs(ctx: TangHttpContext): Int64
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withTimeout()` | `Int64` | `30000`（30秒） | 超时时间（毫秒） |
| `withTimeoutCallback()` | `(TangHttpContext) -> Unit` | - | 超时回调函数 |

## 快速开始

### 基础用法

```cj
import tang.middleware.timeout.{timeout, withTimeout, isTimeout}

let r = Router()

// 设置 5 秒超时
r.use(timeout([withTimeout(5000)]))

r.get("/slow", { ctx =>
    // 在长时间操作前检查超时
    if (isTimeout(ctx)) {
        ctx.responseBuilder.status(504u16).body("Gateway Timeout")
        return
    }

    // 执行长时间操作
    processLargeDataset()

    ctx.json(HashMap<String, String>([
            ("status", "completed")
        ]))
})
```

### 在循环中检查超时

```cj
import tang.middleware.timeout.{timeout, withTimeout, isTimeout}

let r = Router()

r.use(timeout([withTimeout(5000)]))

r.get("/process", { ctx =>
    let dataset = getLargeDataset()

    for (item in dataset) {
        // 每次循环前检查超时
        if (isTimeout(ctx)) {
            ctx.responseBuilder.status(504u16).body("Timeout")
            return
        }

        // 处理 item
        processItem(item)
    }

    ctx.json(HashMap<String, String>([
            ("status", "completed")
        ]))
})
```

## 完整示例

### 示例 1：不同路由不同超时

```cj
import tang.*
import tang.middleware.timeout.{timeout, withTimeout, isTimeout, getElapsedMs}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 快速路由：5 秒超时
    let fastRoutes = r.group("/api/fast")
    fastRoutes.use(timeout([withTimeout(5000)]))

    fastRoutes.get("/data", { ctx =>
        if (isTimeout(ctx)) {
            ctx.jsonWithCode(504u16,
                HashMap<String, String>([
            ("error", "Timeout")
        ])
            )
            return
        }

        ctx.json(HashMap<String, String>([
            ("data", "fast response")
        ]))
    })

    // 慢速路由：60 秒超时
    let slowRoutes = r.group("/api/slow")
    slowRoutes.use(timeout([withTimeout(60000)]))

    slowRoutes.get("/report", { ctx =>
        if (isTimeout(ctx)) {
            ctx.jsonWithCode(504u16,
                HashMap<String, String>([
            ("error", "Timeout")
        ])
            )
            return
        }

        // 生成报表（可能需要较长时间）
        let report = generateReport()
        ctx.json(report)
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：超时回调（日志记录）

```cj
import tang.middleware.timeout.{timeout, withTimeout, withTimeoutCallback}

let r = Router()

r.use(timeout([
    withTimeout(10000),  // 10 秒超时
    withTimeoutCallback({ ctx =>
        // 记录超时请求
        let ip = ctx.ip()
        let path = ctx.path()
        let method = ctx.method()
        let elapsed = getElapsedMs(ctx)

        println("[TIMEOUT] ${ip} - ${method} ${path} - ${elapsed}ms")
    })
]))

r.get("/api/data", { ctx =>
    // 处理请求
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**超时日志示例**：
```
[TIMEOUT] 127.0.0.1 - GET /api/data - 10523ms
```

### 示例 3：分批处理超时检查

```cj
import tang.middleware.timeout.{timeout, withTimeout, isTimeout}

let r = Router()

r.use(timeout([withTimeout(30000)]))  // 30 秒

r.get("/api/batch-process", { ctx =>
    let items = getAllItems()  // 假设有 1000 个项目
    let batchSize = 100
    var processed = 0

    while (processed < items.size) {
        // 检查超时
        if (isTimeout(ctx)) {
            ctx.json(HashMap<String, String>([
            ("status", "timeout"),
            ("processed", "${processed}/${items.size}")
        ]))
            return
        }

        // 处理一批数据
        let end = (processed + batchSize).min(items.size)
        for (i in processed..end) {
            processItem(items[i])
        }

        processed = end
    }

    ctx.json(HashMap<String, String>([
            ("status", "completed"),
            ("processed", "${processed}")
        ]))
})
```

### 示例 4：数据库操作超时保护

```cj
func queryWithTimeout(ctx: TangHttpContext, sql: String): ?ResultSet {
    // 查询前检查超时
    if (isTimeout(ctx)) {
        println("Query timeout before execution")
        return None
    }

    // 执行查询
    let resultSet = database.query(sql)

    // 检查查询是否超时
    if (isTimeout(ctx)) {
        println("Query timeout after execution")
        return None
    }

    resultSet
}

let r = Router()
r.use(timeout([withTimeout(5000)]))

r.get("/api/users", { ctx =>
    let resultSet = queryWithTimeout(ctx, "SELECT * FROM users")

    match (resultSet) {
        case Some(results) => ctx.json(results)
        case None => ctx.jsonWithCode(504u16,
            HashMap<String, String>([
            ("error", "Query timeout")
        ])
        )
    }
})
```

### 示例 5：API 代理超时控制

```cj
import tang.middleware.timeout.{timeout, withTimeout, isTimeout}

func proxyRequest(ctx: TangHttpContext, url: String): ?String {
    // 代理前检查超时
    if (isTimeout(ctx)) {
        return None
    }

    // 发送代理请求（应该使用 HTTP 客户端的超时配置）
    let response = httpClient.get(url)

    // 检查代理是否超时
    if (isTimeout(ctx)) {
        return None
    }

    response.body
}

let r = Router()

r.use(timeout([withTimeout(10000)]))  // 10 秒

r.get("/api/proxy", { ctx =>
    let targetURL = ctx.query("url").getOrThrow()

    let result = proxyRequest(ctx, targetURL)

    match (result) {
        case Some(body) => ctx.writeString(body)
        case None => ctx.jsonWithCode(504u16,
            HashMap<String, String>([
            ("error", "Proxy timeout")
        ])
        )
    }
})
```

## 工作原理

### 超时检查机制

```cj
// 1. 中间件记录开始时间
let startTime = DateTime.now()
ctx.request.headers.add("X-Timeout-Start", "${startTime.toUnixTimeStamp().toMilliseconds()}")
ctx.request.headers.add("X-Timeout-Ms", "${timeoutMs}")

// 2. 业务代码检查超时
public func isTimeout(ctx: TangHttpContext): Bool {
    let startTimeMs = Int64.parse(ctx.request.headers.getFirst("X-Timeout-Start"))
    let timeoutMs = Int64.parse(ctx.request.headers.getFirst("X-Timeout-Ms"))

    let currentTimeMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let elapsedMs = currentTimeMs - startTimeMs

    return elapsedMs > timeoutMs
}

// 3. 超时后执行回调
if (durationMs > config.timeoutMs) {
    if (let Some(callback) <- config.onTimeout) {
        callback(ctx)
    }
}
```

## 辅助函数

### isTimeout()

检查请求是否已超时：

```cj
r.get("/data", timeout([withTimeout(5000)]), { ctx =>
    if (isTimeout(ctx)) {
        ctx.status(504u16).body("Timeout")
        return
    }

    // 正常处理
})
```

### getElapsedMs()

获取请求已处理时间（毫秒）：

```cj
r.get("/stats", { ctx =>
    let elapsed = getElapsedMs(ctx)

    ctx.json(HashMap<String, Int64>([
        ("elapsedMs", elapsed)
    ]))
})
```

## 测试

### 测试超时

```bash
# 模拟慢请求（超过 5 秒）
curl -i http://localhost:8080/slow

# 响应：
# HTTP/1.1 504 Gateway Timeout
# Timeout
```

### 测试正常请求

```bash
# 快速请求（< 5 秒）
curl -i http://localhost:8080/fast

# 响应：
# HTTP/1.1 200 OK
# {"data":"fast response"}
```

### 查看已用时间

```bash
curl http://localhost:8080/stats

# {"elapsedMs":123}
```

## 最佳实践

### 1. 合理设置超时时间

```cj
// ❌ 错误：超时时间太短（正常请求也会超时）
r.use(timeout([withTimeout(100)]))  // 100 毫秒

// ❌ 错误：超时时间太长（失去保护作用）
r.use(timeout([withTimeout(300000)]))  // 5 分钟

// ✅ 正确：根据业务设置合理超时
r.use(timeout([withTimeout(5000)]))  // 5 秒
```

**建议超时时间**：
- 快速 API：5-10 秒
- 复杂查询：30-60 秒
- 文件处理：2-5 分钟
- 报表生成：5-10 分钟

### 2. 关键点检查超时

```cj
// ✅ 正确：在关键操作前检查超时
if (isTimeout(ctx)) {
    return  // 提前退出
}

// 数据库查询
database.query(sql)

// 再次检查
if (isTimeout(ctx)) {
    return
}

// 处理结果
processData(result)
```

### 3. 提供有意义的超时响应

```cj
// ❌ 错误：不提供详细信息
if (isTimeout(ctx)) {
    ctx.status(504u16).body("Timeout")
}

// ✅ 正确：提供详细信息
if (isTimeout(ctx)) {
    let elapsed = getElapsedMs(ctx)
    ctx.jsonWithCode(504u16, HashMap<String, String>([
            ("error", "Request timeout"),
            ("timeout", "5000ms"),
            ("elapsed", "${elapsed}ms")
        ]))
}
```

### 4. 结合其他超时机制

```cj
// 数据库驱动超时（推荐）
let dbConfig = DatabaseConfig(
    host = "localhost",
    port = 3306,
    timeout = 5000  // 数据库查询超时 5 秒
)

// HTTP 客户端超时（推荐）
let httpClient = HttpClient(
    connectTimeout = 3000,   // 连接超时 3 秒
    readTimeout = 10000      // 读取超时 10 秒
)

// 中间件超时（额外保护）
r.use(timeout([withTimeout(15000)]))  // 15 秒
```

## 注意事项

### 1. 不能强制中断执行

由于仓颉的同步执行模型，超时不能强制中断正在执行的代码：

```cj
// ❌ 问题：数据库查询耗时 20 秒，无法在 5 秒时中断
r.use(timeout([withTimeout(5000)]))

r.get("/api/data", { ctx =>
    if (isTimeout(ctx)) {  // 这里的检查可能在查询完成后才执行
        return
    }

    // 查询可能需要 20 秒，无法中断
    let data = database.query("SELECT * FROM huge_table")
    ctx.json(data)
})
```

**解决方案**：使用数据库驱动的超时配置

### 2. 超时检查频率

```cj
// ✅ 正确：在循环中频繁检查
for (item in largeDataset) {
    if (isTimeout(ctx)) { return }  // 每次迭代都检查
    processItem(item)
}

// ⚠️ 注意：检查频率要权衡（太频繁影响性能）
```

### 3. 超时后的状态

```cj
// 超时后，Context 的状态不会自动改变
r.use(timeout([withTimeout(5000)]))

r.get("/api/data", { ctx =>
    if (isTimeout(ctx)) {
        // 即使超时，仍然需要手动设置响应
        ctx.status(504u16).body("Timeout")
        return
    }

    // 正常处理
})
```

## 常见问题

### 问题 1：为什么超时没有生效？

**原因**：没有在代码中调用 `isTimeout()`

**解决**：
```cj
// ❌ 错误：只设置超时，不检查
r.use(timeout([withTimeout(5000)]))
r.get("/slow", { ctx =>
    // 长时间操作，没有检查超时
    sleep(10000)  // 10 秒
})

// ✅ 正确：定期检查超时
r.use(timeout([withTimeout(5000)]))
r.get("/slow", { ctx =>
    if (isTimeout(ctx)) {
        ctx.status(504u16).body("Timeout")
        return
    }
    sleep(10000)
})
```

### 问题 2：超时时间如何设置？

**建议**：
- 根据业务需求设置
- 考虑 P95/P99 响应时间
- 留出一些缓冲时间
- 不同路由设置不同超时

### 问题 3：超时后如何清理资源？

```cj
r.get("/api/process", { ctx =>
    let resource = acquireResource()

    if (isTimeout(ctx)) {
        // 超时后释放资源
        releaseResource(resource)
        ctx.status(504u16).body("Timeout")
        return
    }

    // 正常处理
    processWithResource(resource)

    // 处理完成后释放资源
    releaseResource(resource)
})
```

## 相关链接

- **[源码](../../../src/middleware/timeout/timeout.cj)** - Timeout 源代码
