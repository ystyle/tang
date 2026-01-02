# Logger - 请求日志

## 概述

- **功能**：记录每个 HTTP 请求的基本信息
- **分类**：日志与监控
- **文件**：`src/middleware/log/log.cj`

Logger 中间件用于记录所有传入的 HTTP 请求，包括方法、路径、状态码、响应时间等信息，帮助开发者监控和调试应用。

## 签名

```cj
public func logger(): MiddlewareFunc
public func logger(opts: Array<LoggerOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withFormat()` | `LogFormat` | `Common` | 日志格式（Common、JSON、Short） |
| `withTimeZone()` | `String` | `"UTC"` | 时区（UTC、Local） |

## 快速开始

### 基础用法

```cj
import tang.middleware.log.logger

let r = Router()

// 应用 Logger 中间件
r.use(logger())

r.get("/", { ctx =>
    ctx.writeString("Hello, World!")
})

r.post("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("status", "ok")
        ]))
})
```

**日志输出**：

```
[2025-01-02 10:30:15 UTC] GET / 200 2ms
[2025-01-02 10:30:20 UTC] POST /api/data 200 5ms
```

### 不同日志格式

```cj
import tang.middleware.log.logger.{logger, withFormat, LogFormat}

// Common 格式（默认）
r.use(logger([withFormat(LogFormat.Common)]))

// JSON 格式
r.use(logger([withFormat(LogFormat.JSON)]))

// Short 格式（简洁）
r.use(logger([withFormat(LogFormat.Short)]))
```

**格式对比**：

**Common 格式**：
```
[2025-01-02 10:30:15 UTC] GET /api/users 200 15ms
```

**JSON 格式**：
```json
{
    "timestamp": "2025-01-02T10:30:15Z",
    "method": "GET",
    "path": "/api/users",
    "status": 200,
    "duration": 15,
    "ip": "127.0.0.1"
}
```

**Short 格式**：
```
GET /api/users 200 15ms
```

## 完整示例

### 示例 1：生产环境配置（JSON 格式）

```cj
import tang.*
import tang.middleware.exception.recovery.recovery
import tang.middleware.log.logger.{logger, withFormat, LogFormat}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // Recovery + Logger（标准组合）
    r.use(recovery())
    r.use(logger([
        withFormat(LogFormat.JSON)  // JSON 格式便于日志分析工具解析
    ]))

    r.get("/api/users", { ctx =>
        ctx.json(ArrayList<String>())
    })

    r.post("/api/users", { ctx =>
        ctx.status(201).json(HashMap<String, String>([
            ("message", "Created")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**日志输出**：

```json
{
    "timestamp": "2025-01-02T10:30:15.123Z",
    "method": "GET",
    "path": "/api/users",
    "status": 200,
    "duration": 8,
    "ip": "192.168.1.100"
}
```

### 示例 2：自定义日志格式

```cj
import tang.middleware.log.logger.{logger, LogFormat}

// 自定义日志中间件
func customLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()

            next(ctx)

            let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()
            let method = ctx.method()
            let path = ctx.path()
            let status = ctx.responseBuilder.statusCode

            // 自定义日志格式
            println("${method} ${path} ${status} ${duration}ms - ${ctx.ip()}")
        }
    }
}

let r = Router()
r.use(customLogger())
```

### 示例 3：条件日志记录

```cj
import tang.middleware.log.logger.{logger, withFormat, LogFormat}

func conditionalLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()

            next(ctx)

            // 只记录失败的请求或耗时超过 100ms 的请求
            let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()
            let status = ctx.responseBuilder.statusCode

            if (status >= 400 || duration > 100) {
                println("[${DateTime.now()}] ${ctx.method()} ${ctx.path()} ${status} ${duration}ms")
            }
        }
    }
}

let r = Router()
r.use(conditionalLogger())
```

### 示例 4：写入日志文件

```cj
import std.io.FileWriter

func fileLogger(filepath: String): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()

            next(ctx)

            let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()
            let logEntry = "[${DateTime.now()}] ${ctx.method()} ${ctx.path()} ${ctx.responseBuilder.statusCode} ${duration}ms\n"

            // 写入文件
            let writer = FileWriter(filepath, append: true)
            writer.write(logEntry)
            writer.flush()
        }
    }
}

let r = Router()
r.use(fileLogger("access.log"))
```

## 测试

```bash
# 测试 GET 请求
curl http://localhost:8080/api/users
# 日志输出：[2025-01-02 10:30:15 UTC] GET /api/users 200 8ms

# 测试 POST 请求
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test"}'
# 日志输出：[2025-01-02 10:30:20 UTC] POST /api/users 201 12ms

# 测试错误请求
curl http://localhost:8080/not-found
# 日志输出：[2025-01-02 10:30:25 UTC] GET /not-found 404 3ms
```

## 工作原理

Logger 中间件在请求处理前后记录时间戳：

```cj
public func logger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()  // 记录开始时间

            next(ctx)  // 执行后续处理器

            let end = DateTime.now()  // 记录结束时间
            let duration = end.toUnixTimeStamp() - start.toUnixTimeStamp()  // 计算耗时

            // 输出日志
            println("[${start}] ${ctx.method()} ${ctx.path()} ${ctx.responseBuilder.statusCode} ${duration}ms")
        }
    }
}
```

### 日志字段说明

| 字段 | 描述 | 示例 |
|------|------|------|
| `timestamp` | 请求时间戳 | `2025-01-02 10:30:15 UTC` |
| `method` | HTTP 方法 | `GET`, `POST`, `PUT`, `DELETE` |
| `path` | 请求路径 | `/api/users`, `/api/users/123` |
| `status` | HTTP 状态码 | `200`, `404`, `500` |
| `duration` | 响应时间（毫秒） | `15ms`, `123ms` |
| `ip` | 客户端 IP 地址 | `192.168.1.100` |

## 注意事项

### 1. Logger 应在 Recovery 之后应用

如果应用了 Recovery 中间件，Logger 应该在它之后应用，这样即使发生异常也能记录日志：

```cj
// ✅ 正确顺序
r.use(recovery())  // 1. 最外层
r.use(logger())    // 2. 记录所有请求（包括失败的）

// ❌ 错误顺序
r.use(logger())    // 如果后续异常，日志可能不完整
r.use(recovery())
```

### 2. 性能考虑

日志记录会带来轻微的性能开销。在高并发场景下，考虑：

```cj
// 异步日志记录（使用单独的线程/协程）
func asyncLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()

            next(ctx)

            // 将日志任务提交到后台队列
            logQueue.enqueue({
                let duration = DateTime.now().toUnixTimeStamp() - start.toUnixTimeStamp()
                println("${ctx.method()} ${ctx.path()} ${duration}ms")
            })
        }
    }
}
```

### 3. 敏感信息过滤

避免记录敏感信息（密码、token 等）：

```cj
// ❌ 错误：记录了密码
r.post("/login", { ctx =>
    let password = ctx.param("password")
    println("Password: ${password}")  // 危险！
})

// ✅ 正确：过滤敏感字段
r.post("/login", { ctx =>
    let password = ctx.param("password")
    println("Login attempt for user: ${ctx.param("username")}")  // 不记录密码
})
```

### 4. 日志轮转

生产环境应该实现日志轮转，避免单个日志文件过大：

```cj
import std.fs.File

func rotateLog(filepath: String) {
    let file = File(filepath)
    if (file.size() > 100_000_000) {  // 100MB
        // 重命名当前日志文件
        file.rename("${filepath}.${DateTime.now().toUnixTimeStamp()}")
        // 创建新的日志文件
        FileWriter(filepath).close()
    }
}
```

## 与 AccessLog 的区别

Tang 提供了两个日志中间件：

| 特性 | Logger | AccessLog |
|------|--------|-----------|
| **详细程度** | 简单 | 详细 |
| **字段** | 方法、路径、状态码、耗时 | 额外包括 User-Agent、Referer 等 |
| **性能开销** | 低 | 稍高 |
| **适用场景** | 开发、小型应用 | 生产、需要详细分析 |

**推荐使用**：
- **开发环境**：`logger()` - 简洁高效
- **生产环境**：`accesslog()` - 详细日志便于分析

## 相关链接

- **[AccessLog 中间件](accesslog.md)** - 详细的访问日志
- **[Recovery 中间件](recovery.md)** - 异常恢复
- **[源码](../../../src/middleware/log/log.cj)** - Logger 源代码
