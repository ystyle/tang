# BodyLimit - 请求体大小限制

## 概述

- **功能**：限制请求体大小，防止大文件攻击
- **分类**：流量控制
- **文件**：`src/middleware/bodylimit/bodylimit.cj`

BodyLimit 中间件通过检查 `Content-Length` 头来限制请求体大小，防止客户端发送过大的数据导致服务器资源耗尽。

> **💡 提示：为什么需要 BodyLimit？**
>
> **攻击场景**：
> 1. **内存耗尽攻击**：发送超大请求体占用服务器内存
> 2. **磁盘耗尽攻击**：上传超大文件占用存储空间
> 3. **DDoS 放大**：小带宽发送大请求体占用网络带宽
>
> **防护效果**：
> - ✅ 提前拒绝超大请求（不读取完整请求体）
> - ✅ 保护服务器内存和磁盘资源
> - ✅ 防止恶意上传攻击
>
> **建议配置**：
> - API 服务：1MB - 10MB
> - 文件上传：根据实际需求（如 100MB）
> - 不同路由设置不同限制

## 签名

```cj
public func bodyLimit(): MiddlewareFunc
public func bodyLimit(opts: Array<BodyLimitOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withMaxSize()` | `Int64` | `1048576`（1MB） | 最大请求体大小（字节） |

## 快速开始

### 基础用法

```cj
import tang.middleware.bodylimit.{bodyLimit, withMaxSize}

let r = Router()

// 限制请求体最大 10MB
r.use(bodyLimit([
    withMaxSize(10 * 1024 * 1024)  // 10MB
]))

r.post("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Data received")
        ]))
})
```

**请求过大时的响应**：
```http
HTTP/1.1 413 Request Entity Too Large
Content-Type: text/plain; charset=utf-8

Request Entity Too Large

Maximum request body size is 10485760 bytes
```

### 使用默认配置（1MB）

```cj
import tang.middleware.bodylimit.bodyLimit

let r = Router()

// 默认限制 1MB
r.use(bodyLimit())

r.post("/api/upload", { ctx =>
    ctx.json(HashMap<String, String>([
            ("status", "uploaded")
        ]))
})
```

## 完整示例

### 示例 1：不同路由不同限制

```cj
import tang.*
import tang.middleware.bodylimit.{bodyLimit, withMaxSize}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 小数据路由（严格限制 1KB）
    let smallData = r.group("/api/small")
    smallData.use(bodyLimit([withMaxSize(1024)]))  // 1KB

    smallData.post("/save", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Small data saved")
        ]))
    })

    // 中等数据路由（限制 1MB）
    let mediumData = r.group("/api/medium")
    mediumData.use(bodyLimit([withMaxSize(1024 * 1024)]))  // 1MB

    mediumData.post("/config", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Config saved")
        ]))
    })

    // 文件上传路由（宽松限制 100MB）
    let fileUpload = r.group("/api/upload")
    fileUpload.use(bodyLimit([withMaxSize(100 * 1024 * 1024)]))  // 100MB

    fileUpload.post("/image", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Image uploaded")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：自定义错误响应

```cj
import tang.middleware.bodylimit.{bodyLimit, withMaxSize}

func customBodyLimit(maxSize: Int64): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let contentLength = ctx.request.headers.getFirst("Content-Length")

            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        // 自定义错误响应
                        ctx.responseBuilder.status(413u16)
                        ctx.responseBuilder.header("Content-Type", "application/json")
                        ctx.responseBuilder.body(
                            "{\"error\":\"Request body too large\",\"max_size\":${maxSize},\"actual_size\":${length}}"
                        )
                        return
                    }
                }
            }

            next(ctx)
        }
    }
}

let r = Router()

r.use(customBodyLimit(5 * 1024 * 1024))  // 5MB

r.post("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Success")
        ]))
})
```

### 示例 3：基于 Content-Type 的限制

```cj
func smartBodyLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let contentType = ctx.request.headers.getFirst("Content-Type")

            let maxSize = match (contentType) {
                case Some(ct) =>
                    if (ct.contains("application/json")) {
                        1024 * 1024  // JSON: 1MB
                    } else if (ct.contains("multipart/form-data")) {
                        100 * 1024 * 1024  // 文件上传: 100MB
                    } else if (ct.contains("application/x-www-form-urlencoded")) {
                        64 * 1024  // 表单: 64KB
                    } else {
                        1024 * 1024  // 默认: 1MB
                    }
                case None => 1024 * 1024  // 无 Content-Type: 1MB
            }

            let contentLength = ctx.request.headers.getFirst("Content-Length")
            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        ctx.responseBuilder.status(413u16)
                        ctx.json(HashMap<String, String>([
            ("error", "Request body too large"),
            ("maxSize", "${maxSize}")
        ])
                        ))
                        return
                    }
                }
            }

            next(ctx)
        }
    }
}

let r = Router()
r.use(smartBodyLimit())

r.post("/api/data", { ctx => ctx.json(HashMap<String, String>([
            ("status", "ok")
        ])) })
```

### 示例 4：记录超限请求

```cj
import tang.middleware.bodylimit.{bodyLimit, withMaxSize}

func loggingBodyLimit(maxSize: Int64): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let contentLength = ctx.request.headers.getFirst("Content-Length")

            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        // 记录超限请求
                        let ip = ctx.ip()
                        let path = ctx.path()
                        let method = ctx.method()

                        println("[BODY LIMIT EXCEEDED] ${ip} - ${method} ${path} - ${length} bytes")

                        // 返回错误
                        ctx.responseBuilder.status(413u16)
                        ctx.json(HashMap<String, String>([
            ("error", "Request body too large"),
            ("maxSize", "${maxSize} bytes"),
            ("actualSize", "${length} bytes")
        ]))
                        return
                    }
                }
            }

            next(ctx)
        }
    }
}

let r = Router()
r.use(loggingBodyLimit(10 * 1024 * 1024))  // 10MB

r.post("/api/data", { ctx => ctx.json(HashMap<String, String>([
            ("status", "ok")
        ])) })
```

### 示例 5：用户级别限制

```cj
import std.collection.HashMap

var userLimits = HashMap<String, Int64>()

func initUserLimits() {
    userLimits["free"] = 10 * 1024 * 1024      // 免费用户: 10MB
    userLimits["premium"] = 100 * 1024 * 1024  // 付费用户: 100MB
    userLimits["admin"] = 1024 * 1024 * 1024   // 管理员: 1GB
}

func getUserLimit(username: String): Int64 {
    userLimits.get(username).getOr(10 * 1024 * 1024)  // 默认 10MB
}

func userBasedBodyLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 从认证信息获取用户类型
            let username = ctx.request.headers.getFirst("X-User-Type")
            let maxSize = match (username) {
                case Some(user) => getUserLimit(user)
                case None => 10 * 1024 * 1024  // 默认 10MB
            }

            let contentLength = ctx.request.headers.getFirst("Content-Length")
            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        ctx.responseBuilder.status(413u16)
                        ctx.json(HashMap<String, String>([
                            ("error", "Request body too large"),
                            ("maxSize", "${maxSize} bytes")
                        ]))
                        return
                    }
                }
            }

            next(ctx)
        }
    }
}

main() {
    initUserLimits()

    let r = Router()
    r.use(userBasedBodyLimit())

    r.post("/api/upload", { ctx =>
        ctx.json(HashMap<String, String>([
            ("status", "uploaded")
        ]))
    })

    // 运行服务器...
}
```

## 测试

### 测试正常请求

```bash
# 发送小数据（1KB）
curl -X POST http://localhost:8080/api/data \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":"data"}'

# 响应：200 OK
```

### 测试超限请求

```bash
# 发送大数据（20MB，超过 10MB 限制）
dd if=/dev/zero bs=1M count=20 | \
  curl -X POST http://localhost:8080/api/data \
    -H "Content-Type: application/json" \
    -H "Content-Length: 20971520" \
    --data-binary @-

# 响应：413 Request Entity Too Large
# {"error":"Request body too large","maxSize":10485760}
```

### 测试文件上传

```bash
# 上传小文件（成功）
curl -X POST http://localhost:8080/api/upload/image \
  -F "file=@small_image.jpg"

# 上传大文件（失败）
curl -X POST http://localhost:8080/api/upload/image \
  -F "file=@huge_image.jpg"

# 响应：413 Request Entity Too Large
```

## 工作原理

### 限制流程

```
1. 客户端发送请求
   POST /api/data
   Content-Length: 15728640  (15MB)
   ↓
2. BodyLimit 检查 Content-Length
   if (length > maxSize) → 拒绝
   ↓
3a. 超限：返回 413（不读取请求体）
    HTTP/1.1 413 Request Entity Too Large

3b. 未超限：继续处理
    next(ctx)
```

### 检查时机

BodyLimit 在**读取请求体之前**检查 `Content-Length` 头：

```cj
// ❌ 错误：先读取请求体
let body = ctx.bodyRaw()  // 已经读取到内存
if (body.size > maxSize) { ... }  // 太晚了！

// ✅ 正确：先检查 Content-Length
let contentLength = ctx.request.headers.getFirst("Content-Length")
if (let Some(lengthStr) <- contentLength) {
    if (let length <- Int64.parse(lengthStr)) {
        if (length > maxSize) {
            // 拒绝请求，不读取请求体
            return
        }
    }
}
```

## 大小参考

### 常用大小配置

```cj
// 1 KB - 超小数据（如配置项）
withMaxSize(1024)

// 64 KB - 表单数据
withMaxSize(64 * 1024)

// 1 MB - JSON 数据
withMaxSize(1024 * 1024)

// 10 MB - 中等文件
withMaxSize(10 * 1024 * 1024)

// 100 MB - 大文件上传
withMaxSize(100 * 1024 * 1024)

// 1 GB - 超大文件（不推荐）
withMaxSize(1024 * 1024 * 1024)
```

### 实际场景建议

| 场景 | 建议大小 | 说明 |
|------|----------|------|
| API JSON 请求 | 1MB | JSON 数据通常较小 |
| 表单提交 | 64KB | 文本表单数据 |
| 图片上传 | 10MB - 100MB | 根据业务需求 |
| 视频上传 | 500MB - 2GB | 建议使用分片上传 |
| 日志上报 | 10MB | 批量日志 |

## 安全最佳实践

### 1. 全局默认限制

```cj
let r = Router()

// 全局默认限制：1MB
r.use(bodyLimit([withMaxSize(1024 * 1024)]))

// 特定路由放宽限制
let upload = r.group("/upload")
upload.use(bodyLimit([withMaxSize(100 * 1024 * 1024)]))  // 100MB

upload.post("/image", { ctx =>
    ctx.json(HashMap<String, String>([
            ("status", "uploaded")
        ]))
})
```

### 2. 结合认证和限流

```cj
// 免费用户：10MB + 每小时 10 次
// 付费用户：100MB + 每小时 100 次

func getLimitForUser(userType: String): (Int64, Int64) {
    match (userType) {
        case "free" => (10 * 1024 * 1024, 10)
        case "premium" => (100 * 1024 * 1024, 100)
        case _ => (10 * 1024 * 1024, 10)
    }
}

func combinedLimit(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let userType = ctx.request.headers.getFirst("X-User-Type").getOr("free")
            let (maxSize, maxRequests) = getLimitForUser(userType)

            // 1. Body Limit
            let contentLength = ctx.request.headers.getFirst("Content-Length")
            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        ctx.jsonWithCode(413u16,
                            HashMap<String, String>([
            ("error", "Body too large for ${userType} user")
        ])
                        )
                        return
                    }
                }
            }

            // 2. Rate Limit
            let usageCount = getUsageCount(userType)
            if (usageCount >= maxRequests) {
                ctx.jsonWithCode(429u16,
                    HashMap<String, String>([
            ("error", "Rate limit exceeded for ${userType} user")
        ])
                )
                return
            }

            incrementUsage(userType)
            next(ctx)
        }
    }
}

let r = Router()
r.use(combinedLimit())
```

### 3. 记录和监控

```cj
var totalBytesReceived = Int64(0)
var totalRequestsRejected = Int64(0)

func monitoringBodyLimit(maxSize: Int64): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let contentLength = ctx.request.headers.getFirst("Content-Length")

            if (let Some(lengthStr) <- contentLength) {
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > maxSize) {
                        totalRequestsRejected++
                        println("[STATS] Rejected ${totalRequestsRejected} requests, total bytes: ${totalBytesReceived}")

                        ctx.responseBuilder.status(413u16)
                        ctx.json(HashMap<String, String>([
            ("error", "Body too large")
        ]))
                        return
                    }

                    totalBytesReceived += length
                }
            }

            next(ctx)
        }
    }
}
```

### 4. 分层防御

```cj
let r = Router()

// 第一层：全局严格限制（1MB）
r.use(bodyLimit([withMaxSize(1024 * 1024)]))

// 第二层：API 路由（10MB）
let api = r.group("/api")
api.use(bodyLimit([withMaxSize(10 * 1024 * 1024)]))

// 第三层：上传路由（100MB）
let upload = api.group("/upload")
upload.use(bodyLimit([withMaxSize(100 * 1024 * 1024)]))

upload.post("/image", { ctx =>
    // 最终实际处理
    ctx.json(HashMap<String, String>([
            ("status", "uploaded")
        ]))
})
```

## 注意事项

### 1. Content-Length 缺失

某些请求可能没有 `Content-Length` 头：

```cj
// 当前实现：Content-Length 缺失时放行
if (let Some(lengthStr) <- contentLength) {
    // 检查大小
} else {
    // 没有 Content-Length，继续处理（风险！）
    next(ctx)
}
```

**建议**：
- 对于必须包含请求体的 POST/PUT 请求，要求客户端发送 Content-Length
- 或使用流式读取并实时检查大小

### 2. 分块传输编码（Chunked Encoding）

当前实现**不检查分块传输**的请求：

```bash
# 分块传输：没有 Content-Length
curl -X POST http://localhost:8080/api/data \
  -H "Transfer-Encoding: chunked" \
  -d @huge_file.json
```

**解决方案**：需要读取请求体时检查实际大小

```cj
func streamBodyLimit(maxSize: Int64): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 读取请求体并检查大小
            let body = ctx.bodyRaw()

            if (body.size > maxSize) {
                ctx.responseBuilder.status(413u16)
                ctx.json(HashMap<String, String>([
            ("error", "Body too large")
        ]))
                return
            }

            next(ctx)
        }
    }
}
```

### 3. 与文件上传中间件配合

```cj
let r = Router()

// BodyLimit 限制总体大小
r.use(bodyLimit([withMaxSize(100 * 1024 * 1024)]))  // 100MB

// 文件上传中间件检查单个文件大小
r.post("/upload", { ctx =>
    let file = ctx.fromFile("upload")

    match (file) {
        case Some(f) =>
            // 检查单个文件大小
            if (f.size > 10 * 1024 * 1024) {  // 10MB
                ctx.jsonWithCode(413u16,
                    HashMap<String, String>([
            ("error", "File too large (max 10MB)")
        ])
                )
                return
            }

            // 保存文件
            saveFile(f)
            ctx.json(HashMap<String, String>([
            ("status", "uploaded")
        ]))
        case None =>
            ctx.jsonWithCode(400u16,
                HashMap<String, String>([
            ("error", "No file uploaded")
        ])
            )
    }
})
```

### 4. 内存使用

即使限制了请求体大小，服务器仍需将请求体读入内存：

```cj
// ❌ 问题：大量并发请求仍然占用内存
r.use(bodyLimit([withMaxSize(100 * 1024 * 1024)]))  // 100MB

// 1000 个并发请求 = 100GB 内存！
```

**建议**：
- 限制并发请求数（使用 RateLimit）
- 使用流式处理（不将完整请求体读入内存）
- 大文件上传到外部存储（如 S3）

## 常见问题

### 问题 1：小文件也被拒绝

**原因**：配置的限制过小

**解决**：
```cj
// 检查实际配置
r.use(bodyLimit([withMaxSize(1024)]))  // 只有 1KB！

// 调整为合理大小
r.use(bodyLimit([withMaxSize(10 * 1024 * 1024)]))  // 10MB
```

### 问题 2：Content-Length 格式错误

**场景**：客户端发送了错误的 Content-Length

```bash
# 错误的 Content-Length
curl -X POST http://localhost:8080/api/data \
  -H "Content-Length: not-a-number" \
  -d '{"test":"data"}'
```

**当前行为**：`Int64.parse()` 失败时放行请求

**建议**：客户端应确保发送正确的 Content-Length

### 问题 3：如何测试超大请求

```bash
# 方法 1：使用 dd 生成大文件
dd if=/dev/zero bs=1M count=50 > large_file.bin

# 方法 2：使用 /dev/zero 直接发送
dd if=/dev/zero bs=1M count=50 | \
  curl -X POST http://localhost:8080/api/data \
    -H "Content-Length: 52428800" \
    --data-binary @-

# 方法 3：使用 Python
python3 -c "import sys; sys.stdout.buffer.write(b'0' * 52428800)" | \
  curl -X POST http://localhost:8080/api/data --data-binary @-
```

## 相关链接

- **[RateLimit 中间件](ratelimit.md)** - 请求速率限制
- **[源码](../../../src/middleware/bodylimit/bodylimit.cj)** - BodyLimit 源代码
