# Recovery - 异常恢复

## 概述

- **功能**：捕获 panic 和异常，返回友好的错误响应
- **分类**：异常处理
- **文件**：`src/middleware/exception/recovery.cj`

Recovery 中间件用于捕获应用中的 panic 和异常，防止整个应用崩溃，并返回友好的错误响应给客户端。这是生产环境的必备中间件。

## 签名

```cj
public func recovery(): MiddlewareFunc
public func recovery(opts: Array<RecoveryOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withStackSize()` | `Int64` | 8192 | 堆栈跟踪的最大深度 |
| `withCustomHandler()` | `(TangHttpContext, Exception) -> Unit` | 默认处理器 | 自定义错误处理函数 |

## 快速开始

### 基础用法

```cj
import tang.middleware.exception.recovery

let r = Router()

// 应用 Recovery 中间件（应该是第一个应用的中间件）
r.use(recovery())

r.get("/panic", { ctx =>
    throw Exception("Something went wrong!")
})

r.get("/", { ctx =>
    ctx.writeString("Hello, World!")
})
```

**测试**：

```bash
curl http://localhost:8080/panic
# HTTP/1.1 500 Internal Server Error
# {"error":"Internal Server Error"}

curl http://localhost:8080/
# HTTP/1.1 200 OK
# Hello, World!
```

### 带自定义处理器

```cj
import tang.middleware.exception.recovery.{recovery, withCustomHandler}

let r = Router()

r.use(recovery([
    withCustomHandler({ ctx, err =>
        // 自定义错误响应
        ctx.responseBuilder
            .status(500u16)
            .header("Content-Type", "application/json")
            .body("""
                {
                    "error": "Internal Server Error",
                    "message": "${err.message}",
                    "timestamp": "${DateTime.now()}",
                    "request_id": "${ctx.requestid()}"
                }
                """)
    })
]))

r.get("/data", { ctx =>
    // 可能抛出异常的代码
    let data = riskyOperation()
    ctx.json(data)
})
```

## 完整示例

### 示例 1：生产环境配置

```cj
import tang.*
import tang.middleware.exception.recovery.{recovery, withCustomHandler, withStackSize}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // Recovery 应该是最先应用的中间件
    r.use(recovery([
        withCustomHandler({ ctx, err =>
            // 记录错误日志
            println("[ERROR] ${ctx.method()} ${ctx.path()}: ${err.message}")

            // 返回友好的错误响应
            ctx.responseBuilder
                .status(500u16)
                .header("Content-Type", "application/json")
                .body("""
                    {
                        "success": false,
                        "error": "Internal Server Error",
                        "message": "An unexpected error occurred. Please try again later.",
                        "request_id": "${ctx.requestid()}"
                    }
                    """)
        }),
        withStackSize(10240)  // 更详细的堆栈跟踪
    ]))

    // 其他中间件
    r.use(logger())
    r.use(cors())

    // 路由
    r.get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("status", "ok")
        ]))
    })

    r.get("/error", { ctx =>
        throw Exception("Simulated error!")
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：开发环境 vs 生产环境

```cj
import tang.middleware.exception.recovery.{recovery, withCustomHandler}
import std.env.Env

func createRecovery(): MiddlewareFunc {
    let isDev = Env.get("ENV") ?? "development" == "development"

    return recovery([
        withCustomHandler({ ctx, err =>
            if (isDev) {
                // 开发环境：返回详细错误信息和堆栈跟踪
                ctx.responseBuilder
                    .status(500u16)
                    .header("Content-Type", "application/json")
                    .body("""
                        {
                            "error": "${err.message}",
                            "stack": "${getStackTrace(err)}",
                            "request": {
                                "method": "${ctx.method()}",
                                "path": "${ctx.path()}",
                                "query": "${ctx.originalURL()}"
                            }
                        }
                        """)
            } else {
                // 生产环境：只返回简短错误信息
                ctx.responseBuilder
                    .status(500u16)
                    .header("Content-Type", "application/json")
                    .body("""
                        {
                            "error": "Internal Server Error",
                            "request_id": "${ctx.requestid()}"
                        }
                        """)
            }
        })
    ])
}

let r = Router()
r.use(createRecovery())
```

### 示例 3：记录错误到日志系统

```cj
import tang.middleware.exception.recovery.{recovery, withCustomHandler}
import std.io.FileWriter

func logError(ctx: TangHttpContext, err: Exception): Unit {
    let timestamp = DateTime.now().toString()
    let logMessage = """
        [${timestamp}] ERROR
        Request: ${ctx.method()} ${ctx.path()}
        Error: ${err.message}
        Stack: ${getStackTrace(err)}
        --------------------
        """

    // 写入日志文件
    let writer = FileWriter("errors.log", append: true)
    writer.write(logMessage)
    writer.flush()
}

let r = Router()
r.use(recovery([
    withCustomHandler({ ctx, err =>
        logError(ctx, err)

        ctx.responseBuilder
            .status(500u16)
            .header("Content-Type", "application/json")
            .body("""
                {
                    "error": "Internal Server Error",
                    "message": "The error has been logged. Please contact support."
                }
                """)
    })
]))
```

## 测试

```bash
# 测试正常请求
curl http://localhost:8080/
# HTTP 200 OK
# {"status":"ok"}

# 测试异常请求
curl http://localhost:8080/error
# HTTP 500 Internal Server Error
# {"error":"Internal Server Error"}
```

## 工作原理

Recovery 中间件使用 `try-catch` 机制捕获异常：

```cj
public func recovery(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            try {
                next(ctx)  // 执行后续中间件和处理器
            } catch (e: Exception) {
                // 捕获异常，调用自定义处理器或默认处理器
                customHandler(ctx, e)
            }
        }
    }
}
```

### 默认错误响应

默认情况下，Recovery 返回以下响应：

**状态码**：500 Internal Server Error

**响应体**：
```json
{
    "error": "Internal Server Error"
}
```

## 注意事项

### 1. Recovery 应该最先应用

Recovery 中间件应该是**第一个**应用的中间件，这样可以捕获所有后续中间件和处理器的异常：

```cj
// ✅ 正确顺序
r.use(recovery())  // 1. 第一个应用
r.use(logger())
r.use(cors())

// ❌ 错误顺序
r.use(logger())
r.use(cors())
r.use(recovery())  // 无法捕获 logger 和 cors 的异常
```

### 2. 不要在 Recovery 中抛出异常

自定义错误处理器本身不应该抛出异常，否则会导致未捕获的 panic：

```cj
// ❌ 错误：处理器中抛出异常
r.use(recovery([
    withCustomHandler({ ctx, err =>
        throw Exception("Error in error handler!")  // 危险！
    })
]))

// ✅ 正确：处理器应该安全地返回响应
r.use(recovery([
    withCustomHandler({ ctx, err =>
        ctx.responseBuilder.status(500u16).body("Error occurred")
    })
]))
```

### 3. 生产环境隐藏敏感信息

生产环境不应该返回详细的错误信息和堆栈跟踪：

```cj
// ❌ 生产环境：暴露敏感信息
ctx.json(HashMap<String, String>([
    ("error", err.message),
    ("stack", getStackTrace(err)),  // 暴露了代码结构
    ("database", "Connection failed to db.example.com")  // 暴露了数据库地址
]))

// ✅ 生产环境：只返回通用错误信息
ctx.json(HashMap<String, String>([
            ("error", "Internal Server Error")
        ])  // 用于追踪
))
```

### 4. 记录错误日志

至少在生产环境记录错误日志，以便后续排查：

```cj
r.use(recovery([
    withCustomHandler({ ctx, err =>
        // 记录到日志系统
        logger.error("Request failed", HashMap<String, String>([
            ("path", ctx.path()),
            ("error", err.message),
            ("stack", getStackTrace(err))
        ]))

        // 返回通用错误
        ctx.status(500u16).json(HashMap<String, String>([
            ("error", "Internal Server Error")
        ]))
    })
]))
```

## 相关链接

- **[Logger 中间件](log.md)** - 请求日志记录
- **[自定义中间件开发](../custom.md)** - 如何编写自己的中间件
- **[源码](../../../src/middleware/exception/recovery.cj)** - Recovery 源代码
