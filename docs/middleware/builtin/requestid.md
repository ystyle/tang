# RequestID - 请求 ID 生成

> **本分支变更**：ID 格式从 sonyflake 改成 `<启动秒>-<自增序号>`（如 `1762570000-1024`）。
> 旧实现的 sonyflake 有全局 Mutex + 8bit 序列（每 10ms 只能出 256 个 ID，超出会 sleep 等时钟片），
> 单线程实测只有 **2.49 万 ID/秒**，等于把整个服务端吞吐封顶在 2.5 万 req/s。
> 现在是无锁原子自增，并会沿用客户端传入的 `X-Request-ID`（便于跨服务串联）。

## 概述

- **功能**：为每个请求生成唯一的 ID，用于追踪和日志关联
- **分类**：日志与监控
- **文件**：`src/middleware/requestid/requestid.cj`

RequestID 中间件为每个 HTTP 请求生成唯一的 ID，存储到 Context 中并通过响应头返回给客户端。

> **💡 提示：为什么需要 RequestID？**
>
> **用途**：
> 1. **日志关联**：将同一请求的多个日志关联起来
> 2. **问题追踪**：快速定位特定请求的所有日志
> 3. **分布式追踪**：跨服务追踪请求链路
> 4. **调试**：复现问题时查找相关日志
>
> **示例**：
> ```
> 客户端请求 → 生成 RequestID: 12345
> → API Gateway 日志: [12345] 收到请求
> → Service A 日志: [12345] 处理中
> → Database 日志: [12345] 执行查询
> → 所有日志都有相同的 RequestID
> ```

## 签名

```cj
public func requestid(): MiddlewareFunc
```

## 快速开始

### 基础用法

```cj
import tang.middleware.requestid.requestid

let r = Router()

// 应用 RequestID 中间件
r.use(requestid())

r.get("/api/data", { ctx =>
    // 获取 Request ID
    let id = ctx.requestid()

    println("Processing request: ${id}")

    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**响应头**：
```http
X-Request-ID: 1234567890
```

## 完整示例

### 示例 1：结合日志使用

```cj
import tang.*
import tang.middleware.requestid.requestid
import tang.middleware.accesslog.newAccessLog
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 先生成 RequestID
    r.use(requestid())

    // AccessLog 会自动使用 RequestID
    r.use(newAccessLog())

    r.get("/api/users", { ctx =>
        let requestId = ctx.requestid()

        // 在业务日志中使用 RequestID
        println("[${requestId}] Fetching users from database")

        let users = fetchUsers()

        println("[${requestId}] Found ${users.size} users")

        ctx.json(users)
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**日志输出**：
```
[2026-01-02 12:00:00] GET /api/users 200 45ms request-id=1234567890
[1234567890] Fetching users from database
[1234567890] Found 10 users
```

### 示例 2：错误追踪

```cj
import tang.middleware.requestid.requestid

func errorHandler(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let requestId = ctx.requestid()

            try {
                next(ctx)
            } catch (e: Exception) {
                // 记录错误和 RequestID
                println("[${requestId}] Error: ${e.message}")
                println("[${requestId}] Stack trace: ${e.stackTrace}")

                ctx.jsonWithCode(500u16, HashMap<String, String>([
            ("error", "Internal server error")
        ]))
            }
        }
    }
}

let r = Router()
r.use(requestid())
r.use(errorHandler())
```

**客户端可以提供 RequestID 给客服**：
```
用户：报错了，错误信息显示 Request ID: 1234567890
客服：我来查一下日志... grep "1234567890" /var/log/tang/app.log
```

### 示例 3：分布式追踪

```cj
import tang.middleware.requestid.requestid

// API Gateway
let gateway = Router()
gateway.use(requestid())

gateway.get("/api/data", { ctx =>
    let requestId = ctx.requestid()

    // 转发到后端服务时传递 RequestID
    let backendResponse = httpClient.get("http://backend-service/data", headers: [
        "X-Request-ID": requestId
    ])

    ctx.json(backendResponse)
})
```

**请求链路**：
```
客户端 → API Gateway (RequestID: 12345)
        ↓
     传递 X-Request-ID: 12345
        ↓
后端服务 → Database (Query: SELECT * FROM users)
```

### 示例 4：自定义日志格式

```cj
import tang.middleware.requestid.requestid

func structuredLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let requestId = ctx.requestid()
            let start = DateTime.now()

            next(ctx)

            let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()

            // 结构化日志
            println(
                "{\"requestId\":\"${requestId}\"," +
                "\"method\":\"${ctx.method()}\"," +
                "\"path\":\"${ctx.path()}\"," +
                "\"status\":${ctx.responseBuilder.statusCode}," +
                "\"duration\":${duration}}"
            )
        }
    }
}

let r = Router()
r.use(requestid())
r.use(structuredLogger())
```

**日志输出**（JSON 格式）：
```json
{"requestId":"1234567890","method":"GET","path":"/api/data","status":200,"duration":23}
```

### 示例 5：Context 中存储 RequestID

```cj
let r = Router()
r.use(requestid())

// 在多个中间件中使用 RequestID
func loggingMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let requestId = ctx.requestid()
            println("[${requestId}] Before handler")
            next(ctx)
            println("[${requestId}] After handler")
        }
    }
}

func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let requestId = ctx.requestid()
            let user = ctx.kvGet<String>("user")

            println("[${requestId}] Authenticated user: ${user}")

            next(ctx)
        }
    }
}

r.use(loggingMiddleware())
r.use(authMiddleware())
```

## 工作原理

### RequestID 生成

```cj
// 使用 Sonyflake 算法生成唯一 ID
let gen = Sonyflake(Setting(1))

let id = gen.NextID()  // Int64
let idStr = "${id}"    // String
```

**Sonyflake 特点**：
- 分布式环境唯一
- 按时间递增
- 高性能（无锁）

### RequestID 存储

```cj
// 1. 生成 ID
ctx.kvSet("requestid", idStr)

// 2. 设置响应头
ctx.responseBuilder.header("X-Request-ID", idStr)

// 3. 业务代码获取
let id = ctx.requestid()  // ?String
```

## 测试

### 查看响应头

```bash
curl -i http://localhost:8080/api/data

# 响应头：
# HTTP/1.1 200 OK
# X-Request-ID: 1234567890
# Content-Type: application/json
```

### 在响应体中返回 RequestID

```cj
r.get("/api/data", { ctx =>
    let requestId = ctx.requestid()

    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**响应**：
```json
{
  "data": "value",
  "requestId": "1234567890"
}
```

## 注意事项

### 1. 中间件顺序

```cj
// ✅ 正确：RequestID 在最前面
r.use(requestid())      // 1. 先生成 RequestID
r.use(logger())         // 2. Logger 可以使用 RequestID
r.use(auth())           // 3. 其他中间件

// ❌ 错误：RequestID 太晚
r.use(logger())         // Logger 无法使用 RequestID
r.use(auth())
r.use(requestid())      // 太晚了
```

### 2. RequestID 传递

**跨服务传递 RequestID**：

```cj
// 客户端请求 → API Gateway → Service A → Service B

// API Gateway
let requestId = ctx.requestid()
let response = httpClient.get("http://service-a/api", headers: [
    "X-Request-ID": requestId  // 传递给下游
])

// Service A
let requestId = ctx.request.headers.getFirst("X-Request-ID")
match (requestId) {
    case Some(id) =>
        // 使用上游的 RequestID
        ctx.kvSet("requestid", id)
    case None =>
        // 生成新的 RequestID
        r.use(requestid())
    }
}
```

### 3. 日志关联

**确保所有日志都包含 RequestID**：

```cj
// ✅ 正确：所有日志都包含 RequestID
let requestId = ctx.requestid()
println("[${requestId}] Processing request")
println("[${requestId}] Querying database")
println("[${requestId}] Sending response")

// ❌ 错误：有些日志没有 RequestID
println("Processing request")  // 无法关联
println("[${requestId}] Querying database")
```

## 最佳实践

### 1. 始终使用 RequestID

```cj
// 在所有中间件和处理器中使用
func myMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let requestId = ctx.requestid()
            // 使用 RequestID 记录日志
            next(ctx)
        }
    }
}
```

### 2. 返回 RequestID 给客户端

```cj
r.get("/api/data", { ctx =>
    let requestId = ctx.requestid()

    // 方式 1：响应体中包含
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))

    // 方式 2：响应头中包含（自动）
    // X-Request-ID: ${requestId}
})
```

### 3. 结构化日志

```cj
// JSON 格式日志，便于解析和分析
println(
    "{" +
    "\"requestId\":\"${requestId}\"," +
    "\"level\":\"INFO\"," +
    "\"message\":\"Processing request\"" +
    "}"
)
```

## 相关链接

- **[AccessLog 中间件](accesslog.md)** - 访问日志
- **[源码](../../../src/middleware/requestid/requestid.cj)** - RequestID 源代码
