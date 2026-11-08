# 性能优化指南

## 概述

本文档介绍 Tang 框架的性能优化策略和最佳实践，帮助你在生产环境中获得最佳性能。

## 前置要求

- 仓颉 SDK 1.2.0+
- 核心零 stdx；只有用 `tang_ext_crypto` / `tang_ext_stdx` 时才需要 stdx

## 本分支实测（tachyon 后端 vs 原 stdx 后端）

同机 128 连接、20 秒、两轮，应用代码完全相同（`/hello` 返回固定字符串）：

| 后端 | QPS | p50 | p99 | 每请求 CPU |
|---|---:|---:|---:|---:|
| stdx.net.http（1.0.x） | 256,800 / 244,994 | 410 / 430 µs | 1.99 / 2.07 ms | 27.5 / 28.6 µs |
| **tachyon（本分支）** | **537,095 / 522,024** | 215 / 220 µs | **0.92 / 0.94 ms** | **12.3 / 12.7 µs** |

- 吞吐约 **2.1 倍**，每请求 CPU 约 **1/2.2**，p99 约 **1/2.2**
- 服务端 RSS：tachyon 约 230 MB，stdx 约 110–170 MB（tachyon 用了更大的读写缓冲换吞吐）
- 中间件开销：`requestid + cors` 约 1–2%，p99 无恶化

更完整的剖析（含 runtime `sched_yield` 定位、跨机/弱机数据）见
[为什么比 stdx.net.http 快](https://github.com/ystyle/cangjie-runtime-issue-3577-repro)。

### requestid 曾把吞吐卡在 2.5 万/秒

旧 `requestid` 用 sonyflake：全局 Mutex + 8 bit 序列（每 10ms 只能出 256 个 ID，
超出就 sleep 等时钟片）+ 序列回绕时 `println`。单线程实测仅 **2.49 万 ID/秒**，
也就是说这个中间件本身把服务端吞吐封顶在 2.5 万 req/s。
现已改为 `<启动秒>-<AtomicInt64 自增>`，无锁、无时钟依赖。

## Tang 性能特性

Tang 框架在设计时注重性能，提供了以下特性：

- **O(k) 路由查找**：基于 Radix Tree，k 为路径深度
- **零拷贝设计**：最小化内存分配和复制
- **中间件复用**：避免重复创建中间件实例
- **高效的模式匹配**：充分利用仓颉的模式匹配特性

## 路由性能优化

### 1. 路由设计原则

#### 避免深层嵌套

```cj
// ❌ 差：深层嵌套影响路由匹配性能
let v1 = r.group("/api")
let v2 = v1.group("/v1")
let users = v2.group("/users")
let profile = users.group("/profile")
profile.get("/", handler)  // 实际路径: /api/v1/users/profile/

// ✅ 好：扁平化路由结构
r.get("/api/v1/users/profile/", handler)
```

#### 合理使用动态参数

```cj
// ✅ 好：精确匹配优先
r.get("/users/profile", handler)      // 优先级 1
r.get("/users/:id", handler)          // 优先级 2

// ❌ 差：所有路由都用动态参数
r.get("/:resource/:id", handler)      // 匹配所有路径，性能较差
```

#### 避免通配符滥用

```cj
// ⚠️ 谨慎使用：通配符匹配性能低于精确匹配
r.get("/files/*", handler)           // 匹配 /files/ 下的所有路径

// ✅ 好：对于常见路径使用精确路由
r.get("/files/documents", handler)
r.get("/files/images", handler)
r.get("/files/*", handler)           // 只用于兜底
```


## 中间件性能优化

### 1. 中间件顺序很重要

```cj
// ✅ 正确的中间件顺序
r.use(recovery())        // 1. 最外层（异常恢复）
r.use(requestid())       // 2. 生成请求 ID
r.use(logger())          // 3. 日志记录
r.use(cors())            // 4. CORS 处理

// ❌ 错误的顺序
r.use(cors())            // CORS 在日志之后，无法记录预检请求
r.use(logger())          // 日志太晚
r.use(recovery())        // 恢复在最内层，无法捕获外层异常
```

**原则**：
1. **Recovery** 始终在最外层
2. **请求 ID** 早期生成
3. **认证/授权** 在业务逻辑之前
4. **压缩** 在响应生成之后

### 2. 中间件复用

```cj
// ❌ 差：每次请求都创建新中间件
r.get("/api/data", { ctx =>
    let middleware = new ExpensiveMiddleware()
    middleware.process(ctx)
})

// ✅ 好：复用中间件实例
class DatabaseMiddleware {
    let db: Database

    public init(db: Database) {
        this.db = db
    }

    public func apply(): MiddlewareFunc {
        let db = this.db
        return { next =>
            return { ctx =>
                ctx.kvSet("db", db)
                next(ctx)
            }
        }
    }
}

let dbMiddleware = DatabaseMiddleware(db)
r.use(dbMiddleware.apply())
```

### 3. 条件中间件

```cj
// ✅ 好：使用条件中间件避免不必要的处理
func conditionalLogger(shouldLog: (TangHttpContext) -> Bool): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (shouldLog(ctx)) {
                // 只记录特定请求
                println("[LOG] ${ctx.method()} ${ctx.path()}")
            }
            next(ctx)
        }
    }
}

// 只记录 API 请求
r.use(conditionalLogger({ ctx => ctx.path().startsWith("/api/") }))
```

## Context 操作优化

### 1. 避免重复解析

```cj
// ❌ 差：多次解析同一参数
r.get("/users/:id", { ctx =>
    let id1 = ctx.param("id")
    let id2 = ctx.param("id")  // 重复解析
})

// ✅ 好：解析一次，复用结果
r.get("/users/:id", { ctx =>
    let id = ctx.param("id")
    // 使用 id
})
```

### 2. 使用类型安全的解析方法

```cj
// ✅ 好：使用类型化方法，避免手动转换
r.get("/search", { ctx =>
    let page = ctx.queryInt("page") ?? 1
    let limit = ctx.queryInt("limit") ?? 10

    // 类型已转换，直接使用
    let users = fetchUsers(page, limit)
})

// ❌ 差：手动解析和转换
r.get("/search", { ctx =>
    let pageStr = ctx.query("page") ?? 1
    let page = Int64.parse(pageStr)  // 需要处理解析异常
})
```

### 3. 使用链式 API

```cj
// ✅ 好：链式调用，减少中间变量
ctx.status(200u16)
    .set("Content-Type", "application/json")
    .json(HashMap<String, String>(
        ("message", "Success")
    ))

// ❌ 差：多次调用
ctx.status(200u16)
ctx.set("Content-Type", "application/json")
ctx.json(HashMap<String, String>(
    ("message", "Success")
))
```

## 内存优化

### 1. 避免大对象频繁创建

```cj
// ❌ 差：每次请求都创建大数组
r.get("/api/data", { ctx =>
    let largeArray = Array<Int64>(10000, i => i)
    // 使用 largeArray
})

// ✅ 好：复用或使用流式处理
class DataCache {
    static let cachedData = Array<Int64>(10000, i => i)
}

r.get("/api/data", { ctx =>
    let data = DataCache.cachedData  // 复用缓存
    // 使用 data
})
```

### 2. 及时释放资源

```cj
// ✅ 好：使用完毕后清理资源
r.get("/api/file", { ctx =>
    // 使用 try-with-resource 语法来自动释放资源
    try (file = File.open("/path/to/file"))
        let content = file.readAll()
        ctx.send(content)
    }
})
```

### 3. 使用合适的数据结构

```cj
// ✅ 好：根据场景选择合适的集合类型
// - 频繁查找：使用 HashSet 或 HashMap
// - 有序数据：使用 ArrayList
// - 固定大小：使用 Array

let whitelist = HashSet<String>()  // O(1) 查找
whitelist.add("127.0.0.1")
whitelist.add("192.168.1.1")

func checkIP(ip: String): Bool {
    whitelist.contains(ip)  // 高效查找
}
```

## 并发处理优化

### 1. 避免共享可变状态

```cj
// ❌ 差：共享可变状态，需要加锁
class Counter {
    var count: Int64 = 0
    let lock = Mutex()

    public func increment() {
        lock.lock()
        this.count++
        lock.unlock()
    }
}

// ✅ 好：使用 Context 传递请求级数据
r.get("/api/count", { ctx =>
    let count = ctx.kvGet<Int64>("request_count") ?? 0
    ctx.kvSet("request_count", count + 1)
})
```

### 2. 使用连接池

```cj
// ✅ 好：数据库连接池
class DatabasePool {
    var connections: ArrayList<Database>
    let lock = Mutex()
    let maxConnections: Int64

    public init(maxConnections: Int64) {
        this.maxConnections = maxConnections
        this.connections = ArrayList<Database>()
    }

    public func acquire(): Database {
        lock.lock()
        if (this.connections.size > 0) {
            let conn = this.connections[0]
            this.connections.removeAt(0)
            lock.unlock()
            return conn
        } else {
            lock.unlock()
            return createNewConnection()
        }
    }

    public func release(conn: Database) {
        lock.lock()
        if (this.connections.size < this.maxConnections) {
            this.connections.append(conn)
        }
        lock.unlock()
    }
}
```

## 缓存策略

### 1. 使用 ETag 缓存

```cj
import tang.middleware.etag.etag

r.use(etag())

r.get("/api/data", { ctx =>
    // ETag 中间件会自动处理缓存验证
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**优势**：
- 减少不必要的数据传输
- 降低服务器 CPU 使用
- 提升客户端响应速度

### 2. 使用 Cache-Control

```cj
import tang.middleware.cache.cache

// 静态资源缓存
r.get("/static/*", cache([
    withCacheControl("public, max-age=31536000, immutable")
]), handler)

// API 响应缓存
r.get("/api/config", cache([
    withCacheControl("public, max-age=3600")
]), handler)
```

### 3. 应用层缓存

```cj
class ConfigCache {
    var config: ?Map<String, String> = None
    var lastUpdate: Int64 = 0
    let ttl: Int64 = 60000  // 60 秒
    let lock = Mutex()

    public func get(): Map<String, String> {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()

        lock.lock()
        if (this.config.isNone() || now - this.lastUpdate > this.ttl) {
            this.config = fetchConfigFromDB()
            this.lastUpdate = now
        }
        let result = this.config.getOrThrow()
        lock.unlock()

        return result
    }
}
```

## I/O 优化

### 1. 使用流式处理

```cj
// ✅ 好：流式读取大文件
r.get("/download", { ctx =>
    let file = File.open("/path/to/large.file")
    let stream = file.getInputStream()

    // 分块读取并发送
    let buffer = Array<UInt8>(8192, repeat: 0)
    while (true) {
        let bytesRead = stream.read(buffer)
        if (bytesRead <= 0) {
            break
        }
        ctx.write(buffer[0..bytesRead])
    }

    stream.close()
    file.close()
})
```

### 2. 异步处理

```cj
// ✅ 好：异步处理耗时操作
r.post("/api/process", { ctx =>
    // 立即返回任务 ID
    let taskId = generateTaskID()

    // 在后台处理
    spawnTask({
        let result = processTask(taskId)
        saveResult(taskId, result)
    })

    ctx.json(Map<String, String>(
        ("taskId", taskId),
        ("status", "processing")
    ))
})
```

## 日志优化

### 1. 使用合适的日志级别

```cj
import tang.middleware.log.log

// 开发环境：DEBUG 级别
r.use(log([
    withLogLevel(LogLevel.Debug)
]))

// 生产环境：INFO 级别
r.use(log([
    withLogLevel(LogLevel.Info)
]))
```

### 2. 条件日志

```cj
func smartLogger(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()
            next(ctx)
            let duration = DateTime.now().toUnixTimeStamp().toMilliseconds() -
                          start.toUnixTimeStamp().toMilliseconds()

            // 只记录慢请求
            if (duration > 1000) {
                println("[SLOW REQUEST] ${ctx.method()} ${ctx.path()} took ${duration}ms")
            }
        }
    }
}

r.use(smartLogger())
```

### 3. 异步日志

```cj
class AsyncLogger {
    let channel: Channel<String>
    let file: File

    public init(filePath: String) {
        this.file = File.open(filePath, appendMode: true)
        this.channel = Channel<String>(1000)

        // 启动日志写入协程
        spawn({ =>
            while (true) {
                let logMsg = this.channel.receive()
                this.file.writeLine(logMsg)
            }
        })
    }

    public func log(message: String) {
        this.channel.send(message)
    }
}
```

## 监控和诊断

### 1. 请求追踪

```cj
import tang.middleware.requestid.requestid

r.use(requestid())

r.get("/api/trace", { ctx =>
    let requestId = ctx.requestid()
    println("[${requestId}] Processing request")

    // 所有相关日志都包含 requestId
    println("[${requestId}] Query: ${ctx.query("search")}")
    println("[${requestId}] Result: found")

    ctx.json(HashMap<String, String>(
        ("requestId", requestId),
        ("data", "value")
    ))
})
```

### 2. 性能指标收集

```cj
class MetricsCollector {
    var requestCount: Int64 = 0
    var totalDuration: Int64 = 0
    var slowRequests: Int64 = 0
    let lock = Mutex()

    public func record(duration: Int64) {
        lock.lock()
        this.requestCount++
        this.totalDuration += duration
        if (duration > 1000) {
            this.slowRequests++
        }
        lock.unlock()
    }

    public func getStats(): Map<String, Int64> {
        lock.lock()
        let a = if (this.requestCount > 0) {
            this.totalDuration / this.requestCount
        } else {
            0
        }
        let stats = HashMap<String, Int64>(
            ("totalRequests", this.requestCount),
            ("avgDuration", a),
            ("slowRequests", this.slowRequests）
        )
        lock.unlock()
        return stats
    }
}

let metrics = MetricsCollector()

func metricsMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()
            next(ctx)
            let duration = DateTime.now().toUnixTimeStamp().toMilliseconds() -
                          start.toUnixTimeStamp().toMilliseconds()

            metrics.record(duration)
        }
    }
}

r.use(metricsMiddleware())

// 查看指标
r.get("/metrics", { ctx =>
    ctx.json(metrics.getStats())
})
```

## 部署优化

### 1. 使用反向代理

> **💡 提示：为什么推荐 Nginx 层压缩？**
>
> 在 Nginx 或其他反向代理层配置压缩，而不是在应用层处理：
>
> **性能更好**：
> - Nginx 事件驱动，压缩不影响应用服务器 CPU
> - 应用服务器可以专注业务逻辑处理
> - 充分利用多核架构
>
> **配置灵活**：
> - 可以根据路径、文件类型灵活配置
> - 支持压缩阈值、压缩级别等调优
> - 动态调整配置，无需重启应用
>
> **维护简单**：
> - 不需要修改应用代码
> - 重新部署时不需要重启应用服务器
> - 配置集中管理，便于维护

#### Nginx 完整配置示例

```nginx
# HTTP 服务器（重定向到 HTTPS）
server {
    listen 80;
    server_name example.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS 服务器
server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL 证书配置
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # SSL 优化
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    # 现代 SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    # Gzip 压缩
    gzip on;
    gzip_comp_level 6;  # 压缩级别（1-9，推荐 6）
    gzip_types
        application/json
        application/javascript
        text/css
        text/html
        text/plain
        text/xml
        application/xml;
    gzip_min_length 1000;  # 最小压缩文件大小
    gzip_http_version 1.1;
    gzip_proxied any;
    gzip_vary on;
    gzip_buffers 16 8k;

    # 代理到 Tang 应用
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        # 传递真实客户端信息
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### 其他反向代理配置

**Caddy**（自动 HTTPS）：

```
example.com {
    encode gzip {
        level 6
    }
    reverse_proxy localhost:8080
}
```

**Traefik**（云原生反向代理）：

```yaml
http:
  middlewares:
    my-compress:
      compress: true
```

**优势**：
- Nginx 处理静态文件，减少 Tang 负载
- Gzip 压缩在 Nginx 层，节省应用 CPU
- SSL/TLS 终止在 Nginx 层

### 2. 启用 HTTP/2

```nginx
server {
    listen 443 ssl http2;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 其他配置...
}
```

### 3. 负载均衡

```nginx
upstream tang_backend {
    server localhost:8080;
    server localhost:8081;
    server localhost:8082;
}

server {
    location / {
        proxy_pass http://tang_backend;
    }
}
```

## 性能测试

### 基准测试示例

```bash
# 使用 Apache Bench (ab)
ab -n 10000 -c 100 http://localhost:8080/api/data

# 使用 wrk
wrk -t4 -c100 -d30s http://localhost:8080/api/data

# 使用 hey
hey -n 10000 -c 100 http://localhost:8080/api/data
```

### 性能测试脚本

```cj
func benchmarkRequest(url: String, iterations: Int64) {
    var totalTime: Int64 = 0

    for (i in 1..=iterations) {
        let start = DateTime.now()

        // 执行 HTTP 请求
        let response = httpClient.get(url)

        let duration = DateTime.now().toUnixTimeStamp().toMilliseconds() -
                      start.toUnixTimeStamp().toMilliseconds()
        totalTime += duration

        if (i % 100 == 0) {
            println("Completed ${i} requests")
        }
    }

    let avgTime = totalTime / iterations
    println("Average request time: ${avgTime}ms")
    println("Requests per second: ${1000 / avgTime}")
}
```

## 性能检查清单

- [ ] 路由设计合理，避免深层嵌套
- [ ] 中间件顺序正确，复用中间件实例
- [ ] 避免重复解析参数
- [ ] 使用链式 API 减少中间变量
- [ ] 及时释放资源（文件、连接等）
- [ ] 使用合适的数据结构
- [ ] 避免共享可变状态
- [ ] 使用连接池复用连接
- [ ] 启用 ETag 和 Cache-Control
- [ ] 使用合适的日志级别
- [ ] 实现请求追踪
- [ ] 配置反向代理（Nginx/Caddy）
- [ ] 启用 Gzip 压缩
- [ ] 启用 HTTP/2
- [ ] 配置负载均衡
- [ ] 进行性能基准测试

## 常见性能问题

### 问题 1：响应时间过长

**症状**：API 响应时间超过 1 秒

**排查**：
1. 使用 `requestid` 中间件追踪请求
2. 添加计时中间件定位慢点
3. 检查数据库查询是否优化
4. 检查是否有外部 API 调用

**解决**：
```cj
func timingMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let start = DateTime.now()
            next(ctx)
            let duration = DateTime.now().toUnixTimeStamp().toMilliseconds() -
                          start.toUnixTimeStamp().toMilliseconds()

            if (duration > 1000) {
                println("[WARN] Slow request: ${ctx.path()} took ${duration}ms")
            }
        }
    }
}
```

### 问题 2：内存占用过高

**症状**：应用内存持续增长

**排查**：
1. 检查是否有内存泄漏
2. 检查是否频繁创建大对象
3. 检查连接是否正确关闭

**解决**：
- 使用连接池复用连接
- 及时释放资源
- 使用弱引用或缓存过期机制

### 问题 3：CPU 使用率高

**症状**：应用 CPU 占用率持续 100%

**排查**：
1. 检查是否有死循环
2. 检查是否有频繁的字符串操作
3. 检查是否在应用层做压缩

**解决**：
- 将 Gzip 压缩移到 Nginx 层
- 使用缓存减少重复计算
- 优化数据库查询

## 生产环境部署清单

在将 Tang 应用部署到生产环境之前，请确认以下项目：

### 基础设施
- [ ] 配置反向代理（Nginx/Caddy/Traefik）
- [ ] 启用 Gzip 压缩（在反向代理层）
- [ ] 配置 SSL/TLS 证书
- [ ] 设置合理的超时时间
- [ ] 配置日志轮转
- [ ] 设置监控告警
- [ ] 配置自动重启机制
- [ ] 备份策略和灾难恢复

### 性能优化
- [ ] 路由设计合理，避免深层嵌套
- [ ] 中间件顺序正确，复用中间件实例
- [ ] 避免重复解析参数
- [ ] 使用链式 API 减少中间变量
- [ ] 及时释放资源（文件、连接等）
- [ ] 使用合适的数据结构
- [ ] 避免共享可变状态
- [ ] 使用连接池复用连接
- [ ] 启用 ETag 和 Cache-Control
- [ ] 使用合适的日志级别
- [ ] 实现请求追踪

### 安全配置
- [ ] 使用 HTTPS（生产环境必须）
- [ ] 配置安全响应头（使用 `security` 中间件）
- [ ] 根据需求配置 CORS
- [ ] 配置认证和授权机制
- [ ] 启用 CSRF 保护（如果使用 Cookie）
- [ ] 配置请求速率限制
- [ ] 敏感 Cookie 加密（使用 `encryptcookie`）

### 监控和诊断
- [ ] 配置访问日志（使用 `accesslog` 中间件）
- [ ] 配置错误追踪（使用 `recovery` 中间件）
- [ ] 实现请求追踪（使用 `requestid` 中间件）
- [ ] 配置性能指标收集
- [ ] 设置慢请求告警
- [ ] 配置错误率监控

### 测试和验证
- [ ] 进行性能基准测试
- [ ] 进行负载测试
- [ ] 测试故障恢复机制
- [ ] 验证缓存策略
- [ ] 测试限流机制
- [ ] 验证 SSL/TLS 配置

### 部署后验证
```bash
# 1. 健康检查
curl https://api.example.com/health

# 2. 性能测试
ab -n 1000 -c 100 https://api.example.com/api/data

# 3. SSL 测试
openssl s_client -connect api.example.com:443 -tls1_2

# 4. 检查响应头
curl -I https://api.example.com/api/data

# 5. 验证 Gzip 压缩
curl -H "Accept-Encoding: gzip" -I https://api.example.com/api/data
```

## 相关文档

- **[性能基准测试](./benchmark.md)** - Tang vs stdx 性能对比测试结果
- **[框架概述](../overview.md)** - Tang 的设计理念和性能特性
- **[中间件概述](../middleware/overview.md)** - 中间件系统原理
- **[Router API](../api/router.md)** - 路由系统 API
- **[中间件文档](../middleware/builtin/)** - 23+ 内置中间件文档
