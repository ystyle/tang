# HealthCheck - 健康检查

## 概述

- **功能**：提供存活检查（Liveness）和就绪检查（Readiness）
- **分类**：监控与检查
- **文件**：`src/middleware/healthcheck/healthcheck.cj`

HealthCheck 处理器提供 Kubernetes 兼容的健康检查端点，支持存活检查和就绪检查。

> **💡 提示：Liveness vs Readiness**
>
> **存活检查（Liveness Probe）**：
> - 检查服务是否正在运行
> - 失败时：重启容器（Kubernetes）
> - 检查内容：服务是否崩溃、死锁
> - 示例：HTTP 200 = 存活
>
> **就绪检查（Readiness Probe）**：
> - 检查服务是否准备好接收流量
> - 失败时：移出服务轮询（不重启）
> - 检查内容：依赖服务（数据库、Redis）是否可用
> - 示例：数据库连接成功 = 就绪

## 签名

```cj
public func healthcheck(): HandlerFunc
public func healthcheck(opts: Array<HealthCheckOption>): HandlerFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withLivenessCheck()` | `(TangHttpContext) -> Bool` | `true`（总是健康） | 存活检查函数 |
| `withReadinessCheck()` | `(TangHttpContext) -> Bool` | `true`（总是就绪） | 就绪检查函数 |
| `withSystemInfo()` | - | `true` | 包含系统信息（时间戳） |
| `withoutSystemInfo()` | - | - | 不包含系统信息 |

## 快速开始

### 基础用法

```cj
import tang.middleware.healthcheck.healthcheck

let r = Router()

// 添加健康检查端点
r.get("/health", healthcheck())

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

**响应**：
```json
{
  "status": "ok",
  "liveness": "ok",
  "readiness": "ok",
  "timestamp": "2026-01-02 12:00:00"
}
```

### 自定义检查

```cj
import tang.middleware.healthcheck.{healthcheck, withLivenessCheck, withReadinessCheck}

let r = Router()

r.get("/health", healthcheck([
    withLivenessCheck({ ctx =>
        // 检查服务是否存活
        true  // 简单示例
    }),
    withReadinessCheck({ ctx =>
        // 检查数据库连接
        isDatabaseReady()
    })
]))
```

## 完整示例

### 示例 1：生产环境健康检查

```cj
import tang.*
import tang.middleware.healthcheck.{healthcheck, withLivenessCheck, withReadinessCheck}
import stdx.net.http.ServerBuilder

// 模拟服务状态
var isHealthy = true
var isReady = true

func checkLiveness(ctx: TangHttpContext): Bool {
    // 检查服务是否存活
    // 示例：检查关键组件是否响应
    isHealthy
}

func checkReadiness(ctx: TangHttpContext): Bool {
    // 检查依赖服务是否可用
    let dbOK = checkDatabase()
    let redisOK = checkRedis()

    dbOK && redisOK
}

func checkDatabase(): Bool {
    // 检查数据库连接
    true  // 实际应用中应该 ping 数据库
}

func checkRedis(): Bool {
    // 检查 Redis 连接
    true  // 实际应用中应该 ping Redis
}

main() {
    let r = Router()

    // 健康检查端点
    r.get("/health", healthcheck([
        withLivenessCheck({ ctx => checkLiveness(ctx) }),
        withReadinessCheck({ ctx => checkReadiness(ctx) })
    ]))

    // 业务端点
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

### 示例 2：多检查项

```cj
import std.collection.HashMap

func comprehensiveHealthCheck(ctx: TangHttpContext): Bool {
    let checks = HashMap<String, Bool>()

    // 检查 1：数据库
    checks["database"] = checkDatabase()

    // 检查 2：Redis
    checks["redis"] = checkRedis()

    // 检查 3：磁盘空间
    checks["disk"] = checkDiskSpace()

    // 检查 4：内存使用
    checks["memory"] = checkMemoryUsage()

    // 所有检查都通过
    checks.values().all({ v => v })
}

func checkDiskSpace(): Bool {
    // 检查磁盘空间是否 > 10%
    true
}

func checkMemoryUsage(): Bool {
    // 检查内存使用是否 < 90%
    true
}

let r = Router()

r.get("/health", healthcheck([
    withLivenessCheck({ ctx => true }),  // 总是存活
    withReadinessCheck({ ctx => comprehensiveHealthCheck(ctx) })
]))
```

### 示例 3：健康状态变更

```cj
var databaseConnected = false

// 数据库连接回调
func onDatabaseConnect() {
    databaseConnected = true
    println("Database connected: service is ready")
}

func onDatabaseDisconnect() {
    databaseConnected = false
    println("Database disconnected: service is not ready")
}

let r = Router()

r.get("/health", healthcheck([
    withReadinessCheck({ ctx =>
        // 数据库连接失败时，服务不就绪
        databaseConnected
    })
]))

// 模拟数据库连接/断开
r.post("/admin/db/connect", { ctx =>
    onDatabaseConnect()
    ctx.json(HashMap<String, String>([
            ("status", "connected")
        ]))
})

r.post("/admin/db/disconnect", { ctx =>
    onDatabaseDisconnect()
    ctx.json(HashMap<String, String>([
            ("status", "disconnected")
        ]))
})
```

**测试**：
```bash
# 数据库连接后
curl http://localhost:8080/health
# {"status":"ok","liveness":"ok","readiness":"ok","timestamp":"..."}

# 数据库断开后
curl http://localhost:8080/health
# HTTP 503 Service Unavailable
# {"status":"not_ready","liveness":"ok","readiness":"not_ready","timestamp":"..."}
```

### 示例 4：不包含系统信息

```cj
import tang.middleware.healthcheck.{healthcheck, withoutSystemInfo}

let r = Router()

r.get("/health", healthcheck([
    withoutSystemInfo()  // 不返回 timestamp
]))
```

**响应**：
```json
{
  "status": "ok",
  "liveness": "ok",
  "readiness": "ok"
}
```

## Kubernetes 配置

### Liveness Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tang-app
spec:
  containers:
  - name: tang
    image: tang-app:latest
    ports:
    - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30  # 容器启动后 30 秒开始检查
      periodSeconds: 10         # 每 10 秒检查一次
      timeoutSeconds: 5         # 超时时间
      failureThreshold: 3       # 连续 3 次失败后重启
```

### Readiness Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tang-app
spec:
  containers:
  - name: tang
    image: tang-app:latest
    ports:
    - containerPort: 8080
    readinessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 10  # 容器启动后 10 秒开始检查
      periodSeconds: 5          # 每 5 秒检查一次
      timeoutSeconds: 3         # 超时时间
      failureThreshold: 3       # 连续 3 次失败后标记为未就绪
```

### 完整示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tang-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tang
  template:
    metadata:
      labels:
        app: tang
    spec:
      containers:
      - name: tang
        image: tang-app:latest
        ports:
        - containerPort: 8080
        # 存活检查：服务崩溃时重启容器
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        # 就绪检查：依赖服务未就绪时移出流量
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
```

## 响应格式

### 健康状态

```json
{
  "status": "ok",
  "liveness": "ok",
  "readiness": "ok",
  "timestamp": "2026-01-02 12:00:00"
}
```

- **status**: `ok` - 服务健康
- **HTTP 状态码**: `200 OK`

### 未就绪状态

```json
{
  "status": "not_ready",
  "liveness": "ok",
  "readiness": "not_ready",
  "timestamp": "2026-01-02 12:00:00"
}
```

- **status**: `not_ready` - 服务未就绪（依赖服务不可用）
- **HTTP 状态码**: `503 Service Unavailable`

### 不健康状态

```json
{
  "status": "unhealthy",
  "liveness": "failed",
  "readiness": "ok",
  "timestamp": "2026-01-02 12:00:00"
}
```

- **status**: `unhealthy` - 服务不健康
- **HTTP 状态码**: `503 Service Unavailable`

## 测试

### 测试健康检查

```bash
# 健康的服务
curl http://localhost:8080/health

# 响应：200 OK
# {"status":"ok","liveness":"ok","readiness":"ok","timestamp":"..."}
```

### 测试就绪检查失败

```bash
# 数据库未连接
curl -i http://localhost:8080/health

# 响应：503 Service Unavailable
# {"status":"not_ready","liveness":"ok","readiness":"not_ready","timestamp":"..."}
```

### 测试存活检查失败

```bash
# 服务崩溃
curl -i http://localhost:8080/health

# 响应：503 Service Unavailable
# {"status":"unhealthy","liveness":"failed","readiness":"ok","timestamp":"..."}
```

## 最佳实践

### 1. 快速检查

健康检查应该快速完成（< 1 秒）：

```cj
// ✅ 正确：快速检查
func checkReadiness(ctx: TangHttpContext): Bool {
    // 简单的数据库 ping
    database.ping()  // 毫秒级
}

// ❌ 错误：慢速检查
func checkReadiness(ctx: TangHttpContext): Bool {
    // 复杂的查询
    database.execute("SELECT COUNT(*) FROM large_table")  // 秒级
}
```

### 2. 分离存活和就绪检查

```cj
r.get("/healthz", healthcheck([
    withLivenessCheck({ ctx =>
        // 存活检查：只检查服务是否运行
        true
    })
]))

r.get("/readyz", healthcheck([
    withReadinessCheck({ ctx =>
        // 就绪检查：检查依赖服务
        checkDatabase() && checkRedis()
    })
]))
```

**Kubernetes 配置**：
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080

readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
```

### 3. 检查项幂等性

健康检查不应该改变系统状态：

```cj
// ❌ 错误：检查改变状态
func checkReadiness(ctx: TangHttpContext): Bool {
    // 每次检查都创建新连接（可能耗尽数据库连接）
    database.connect()
    true
}

// ✅ 正确：检查不改变状态
func checkReadiness(ctx: TangHttpContext): Bool {
    // 使用现有连接检查
    connectionPool.ping()
}
```

### 4. 超时处理

```cj
import std.time.DateTime
import std.sync.Mutex

var lastHealthCheck = Int64(0)
var healthCheckMutex = Mutex()

func rateLimitedCheck(): Bool {
    synchronized(healthCheckMutex) {
        let now = DateTime.now().toUnixTimeStamp()
        if (now - lastHealthCheck < 5) {  // 5 秒内不重复检查
            return true  // 返回上次结果
        }
        lastHealthCheck = now
    }

    // 执行实际检查
    checkDatabase()
}
```

## 注意事项

### 1. 检查频率

Kubernetes 默认配置：
- **periodSeconds**: 10 秒（检查间隔）
- **timeoutSeconds**: 1 秒（超时时间）
- **failureThreshold**: 3 次（失败阈值）

**建议**：
- Liveness：periodSeconds = 10-30 秒
- Readiness：periodSeconds = 5-10 秒

### 2. 初始延迟

```yaml
livenessProbe:
  initialDelaySeconds: 30  # 给容器足够的启动时间

readinessProbe:
  initialDelaySeconds: 10  # 就绪检查可以更早开始
```

**原因**：服务启动需要时间（数据库连接、缓存预热等）

### 3. 失败阈值

```yaml
livenessProbe:
  failureThreshold: 3  # 连续 3 次失败才重启（避免抖动）

readinessProbe:
  failureThreshold: 3  # 连续 3 次失败才移出流量
```

**原因**：网络抖动、临时故障不应导致重启

## 相关链接

- **[源码](../../../src/middleware/healthcheck/healthcheck.cj)** - HealthCheck 源代码
