# AccessLog - 访问日志

## 概述

- **功能**：记录 HTTP 请求的详细信息（方法、路径、状态码、延迟等）
- **分类**：日志与监控
- **文件**：`src/middleware/accesslog/accesslog.cj`

AccessLog 中间件记录每个 HTTP 请求的详细信息，用于监控、调试和审计。

> **💡 提示：AccessLog vs Log**
>
> **AccessLog（访问日志）**：
> - 记录请求信息（方法、路径、状态码、延迟）
> - 格式化输出，易于解析
> - 适合访问统计、性能分析
>
> **Log（请求日志）**：
> - 简单的请求日志
> - 更简洁
> - 适合快速调试
>
> **建议**：
> - 生产环境：使用 AccessLog（详细、可解析）
> - 开发环境：使用 Log（简洁）

## 签名

```cj
public func newAccessLog(opts: Array<AccessLogOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withTimeFormat()` | - | `true` | 启用时间格式 |
| `withoutTimeFormat()` | - | - | 禁用时间格式 |
| `withUserAgent()` | - | `false` | 启用 User-Agent 记录 |
| `withClientIP()` | - | `false` | 启用客户端 IP 记录 |

## 默认记录字段

- **时间**（`timeFormat`）：请求时间
- **方法**（`method`）：HTTP 方法
- **路径**（`path`）：请求路径
- **状态码**（`status`）：HTTP 状态码
- **延迟**（`latency`）：请求处理时间
- **请求 ID**（`requestID`）：唯一标识符

## 快速开始

### 基础用法

```cj
import tang.middleware.accesslog.newAccessLog

let r = Router()

// 应用访问日志中间件
r.use(newAccessLog())

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

**日志输出**：
```
[2026-01-02 12:00:00] GET / 200 15ms request-id=123456
```

### 启用 User-Agent 和 IP

```cj
import tang.middleware.accesslog.{newAccessLog, withUserAgent, withClientIP}

let r = Router()

r.use(newAccessLog([
    withUserAgent(),   // 记录 User-Agent
    withClientIP()     // 记录客户端 IP
]))
```

**日志输出**：
```
[2026-01-02 12:00:00] GET / 200 15ms request-id=123456 ip=127.0.0.1 ua=Mozilla/5.0
```

## 完整示例

### 示例 1：生产环境配置

```cj
import tang.*
import tang.middleware.accesslog.{newAccessLog, withUserAgent, withClientIP}
import tang.middleware.requestid.requestid
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 先生成请求 ID
    r.use(requestid())

    // 记录详细信息
    r.use(newAccessLog([
        withUserAgent(),
        withClientIP()
    ]))

    r.get("/api/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**日志输出示例**：
```
[2026-01-02 12:34:56] GET /api/data 200 23ms request-id=738291049283 ip=192.168.1.100 ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
[2026-01-02 12:34:57] POST /api/users 201 45ms request-id=738291049284 ip=192.168.1.101 ua=curl/7.68.0
```

### 示例 2：禁用时间格式

```cj
import tang.middleware.accesslog.{newAccessLog, withoutTimeFormat}

let r = Router()

// 不记录时间（简化日志）
r.use(newAccessLog([
    withoutTimeFormat()
]))
```

**日志输出**：
```
GET / 200 15ms request-id=123456
```

### 示例 3：自定义日志格式

```cj
import std.time.DateTime

func customAccessLog(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let startTime = DateTime.now()

            next(ctx)

            let endTime = DateTime.now()
            let duration = endTime.toUnixTimeStamp() - startTime.toUnixTimeStamp()

            // 自定义日志格式
            println("${startTime}|${ctx.method()}|${ctx.path()}|${ctx.responseBuilder.statusCode}|${duration}ms")
        }
    }
}

let r = Router()
r.use(customAccessLog())
```

**日志输出**：
```
2026-01-02 12:00:00|GET|/|200|15
```

## 日志格式

### 标准格式

```
[时间] 方法 路径 状态码 延迟 request-id=xxx
```

### 完整格式（启用所有选项）

```
[时间] 方法 路径 状态码 延迟 request-id=xxx ip=xxx ua=xxx
```

### 字段说明

| 字段 | 描述 | 示例 |
|------|------|------|
| `[时间]` | 请求时间 | `[2026-01-02 12:00:00]` |
| `方法` | HTTP 方法 | `GET`, `POST`, `PUT`, `DELETE` |
| `路径` | 请求路径 | `/api/users` |
| `状态码` | HTTP 状态码 | `200`, `404`, `500` |
| `延迟` | 处理时间（毫秒） | `15ms` |
| `request-id` | 请求唯一 ID | `123456789` |
| `ip` | 客户端 IP | `192.168.1.100` |
| `ua` | User-Agent | `Mozilla/5.0` |

## 测试

### 查看日志输出

```bash
# 运行服务器
cjpm run

# 访问端点
curl http://localhost:8080/api/data

# 查看日志输出（终端）
# [2026-01-02 12:00:00] GET /api/data 200 23ms request-id=123456
```

### 多次请求

```bash
# 快速多次请求
for i in {1..5}; do
  curl http://localhost:8080/api/data
done

# 日志输出：
# [2026-01-02 12:00:00] GET /api/data 200 23ms request-id=001
# [2026-01-02 12:00:01] GET /api/data 200 21ms request-id=002
# [2026-01-02 12:00:02] GET /api/data 200 22ms request-id=003
# [2026-01-02 12:00:03] GET /api/data 200 24ms request-id=004
# [2026-01-02 12:00:04] GET /api/data 200 20ms request-id=005
```

## 注意事项

### 1. 日志量控制

```cj
// ❌ 错误：记录所有信息（日志量太大）
r.use(newAccessLog([
    withUserAgent(),
    withClientIP()
]))

// ✅ 正确：根据需求选择字段
r.use(newAccessLog())  // 只记录基本信息
```

### 2. 性能影响

日志记录会增加少量延迟（通常 < 1ms）：

```cj
// 高流量场景：考虑异步日志
// 或使用采样（只记录部分请求）
```

### 3. 日志轮转

生产环境应该配置日志轮转：

```bash
# 使用 logrotate
# /etc/logrotate.d/tang
/var/log/tang/access.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

## 相关链接

- **[RequestID 中间件](requestid.md)** - 请求 ID 生成
- **[源码](../../../src/middleware/accesslog/accesslog.cj)** - AccessLog 源代码
