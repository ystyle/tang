# Tang 框架概述

## 概述

Tang 是一个基于仓颉（Cangjie）语言构建的高性能 Web 框架，深受 [Fiber](https://github.com/gofiber/fiber) 的启发，专为现代 Web 开发设计。Tang 提供了简洁优雅的 API、强大的路由系统和丰富的中间件生态。

## 设计理念

### 1. 简洁优先

Tang 的 API 设计遵循"简洁但强大"的原则：

- **链式 API**：流畅的方法调用体验
- **约定优于配置**：合理的默认值，减少配置工作
- **类型安全**：充分利用仓颉的类型系统

```cj
let r = Router()

r.get("/users/:id", { ctx =>
    let id = ctx.param("id")
    ctx.json(HashMap<String, String>([
        ("userId", id)
    ]))
})
```

### 2. 性能至上

Tang 在设计时始终考虑性能：

- **Radix Tree 路由**：O(k) 路由查找复杂度
- **零拷贝**：最小化内存分配
- **中间件复用**：避免重复创建中间件实例

### 3. Fiber 风格

借鉴 Fiber 的成功经验：

- **熟悉的 API**：与 Fiber 类似的命名和用法
- **中间件模式**：`(HandlerFunc) -> HandlerFunc`
- **Context 对象**：统一的请求/响应处理接口

### 4. 仓颉原生

充分利用仓颉语言特性：

- **模式匹配**：优雅的 Option 类型处理
- **类型推断**：减少类型标注
- **单元测试**：内置测试框架支持

## 核心架构

```
┌─────────────────────────────────────────┐
│          Client (Browser/cURL)          │
└─────────────────┬───────────────────────┘
                  │ HTTP Request
┌─────────────────▼───────────────────────┐
│          Server (stdx HTTP)             │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│            Tang Router                  │
│  ┌──────────────────────────────────┐  │
│  │      Radix Tree Routing         │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │      Middleware Pipeline         │  │
│  └──────────────────────────────────┘  │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         TangHttpContext                │
│  ┌──────────────┬───────────────────┐   │
│  │   Request    │     Response      │   │
│  │  - Query     │  - Status        │   │
│  │  - Param     │  - Headers       │   │
│  │  - Body      │  - Body          │   │
│  │  - Headers   │  - JSON          │   │
│  └──────────────┴───────────────────┘   │
└─────────────────────────────────────────┘
```

## 核心组件

### Router（路由器）

Router 是 Tang 的核心，负责 HTTP 请求的路由和分发。

**特点**：
- 基于 Radix Tree 的高性能路由
- 支持动态参数：`/users/:id`
- 支持通配符：`/files/*`
- 自动 HEAD → GET 转换
- 路由分组和嵌套

```cj
let r = Router()

r.get("/users", handler)           // 精确匹配
r.get("/users/:id", handler)      // 动态参数
r.get("/files/*", handler)        // 通配符匹配
r.all("/api/*", handler)          // 所有方法
```

### Group（路由组）

Group 用于组织路由并共享中间件。

**特点**：
- 路径前缀自动拼接
- 中间件继承
- 支持嵌套分组

```cj
let api = r.group("/api")
api.use([logger(), cors()])

let v1 = api.group("/v1")
v1.get("/users", handler)  // 实际路径: /api/v1/users
```

### TangHttpContext（上下文）

Context 封装了 HTTP 请求和响应的所有信息。

**特点**：
- 链式 API：流畅的方法调用
- 类型安全：Option 类型处理可能为空的值
- 丰富的方法：Query、Param、Body、Cookie 等

```cj
func handler(ctx: TangHttpContext) {
    // 请求处理
    let name = ctx.query("name").getOrThrow()
    let id = ctx.param("id")

    // 响应处理（链式调用）
    ctx.status(200u16)
        .set("Content-Type", "application/json")
        .json(HashMap<String, String>([
            ("name", name)
        ]))
    })
}
```

### Middleware（中间件）

中间件是拦截请求和响应的函数。

**特点**：
- 链式处理：依次执行中间件
- 灵活组合：全局、分组、单个路由
- 丰富生态：23+ 内置中间件

```cj
// 中间件类型
public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

// 使用中间件
r.use(logger())              // 全局
api.use(cors())              // 路由组
r.get("/protected", auth(), handler)  // 单个路由
```

## 请求生命周期

```
1. HTTP Request
   ↓
2. Server 接收请求
   ↓
3. Router 路由匹配
   ├── 应用路径重写规则（Rewrite）
   ├── Radix Tree 搜索
   └── 找到匹配的 Handler + 中间件链
   ↓
4. 执行中间件链
   ├── Middleware 1 (next(ctx))
   │   ├── Middleware 2 (next(ctx))
   │   │   ├── ... (更多中间件)
   │   │   └── Handler (业务逻辑)
   │   └── (返回到 Middleware 2)
   └── (返回到 Middleware 1)
   ↓
5. 构建响应
   ├── 设置状态码
   ├── 设置 Headers
   └── 发送 Body
   ↓
6. HTTP Response
```

## 中间件系统

### 中间件类型

Tang 提供了 23+ 内置中间件，按功能分类：

#### 监控与检查
- **HealthCheck** - 健康检查（存活/就绪）

#### 路由与请求控制
- **Redirect** - URL 重定向（301/302）
- **Rewrite** - URL 重写
- **Favicon** - Favicon 处理
- **Timeout** - 请求超时控制
- **Proxy** - 反向代理

#### 安全类
- **Security** - 安全响应头
- **CORS** - 跨域资源共享
- **BasicAuth** - HTTP 基本认证
- **CSRF** - CSRF 保护
- **KeyAuth** - API 密钥认证

#### 日志与监控
- **Log** - 请求日志
- **AccessLog** - 访问日志（详细格式）
- **RequestID** - 请求 ID 生成

#### 异常处理
- **Recovery** - 异常恢复

#### 流量控制
- **RateLimit** - 请求速率限制
- **BodyLimit** - 请求体大小限制

#### 静态文件
- **StaticFile** - 静态文件服务

#### 会话与 Cookie
- **Session** - 会话管理
- **EncryptCookie** - Cookie 加密

#### 缓存与优化
- **Cache** - Cache-Control 头
- **ETag** - ETag 缓存验证

#### 高级功能
- **Idempotency** - 幂等性控制

### 中间件执行顺序

```cj
let r = Router()

// 执行顺序：1 → 2 → 3 → Handler → 3 → 2 → 1
r.use(recovery())    // 1. 最外层（异常恢复）
r.use(logger())      // 2. 日志记录
r.use(cors())        // 3. CORS 处理

r.get("/api/data", handler)  // Handler
```

## 路由系统

### Radix Tree 路由

Tang 使用 Radix Tree（基数树）实现高性能路由：

**特点**：
- **O(k) 查找复杂度**：k 为路径深度
- **动态参数支持**：`/users/:id`
- **通配符匹配**：`/files/*`
- **自动优化**：树结构自动优化

**路由匹配优先级**：
```
1. 精确匹配：/users/profile
2. 动态参数：/users/:id
3. 通配符：/files/*
```

### 路径参数

```cj
// 单个参数
r.get("/users/:id", { ctx =>
    let id = ctx.param("id")  // "123"
    ctx.json(HashMap<String, String>([
        ("userId", id)
    ]))
})

// 多个参数
r.get("/users/:userId/posts/:postId", { ctx =>
    let userId = ctx.param("userId")
    let postId = ctx.param("postId")
    ctx.json(HashMap<String, String>([
        ("userId", userId),
        ("postId", postId)
    ]))
})
```

### 通配符

```cj
// 匹配所有子路径
r.get("/files/*", { ctx =>
    let path = ctx.param("*")  // "documents/report.pdf"
    ctx.json(HashMap<String, String>([
        ("filePath", path)
    ]))
})
```

## Context API

### 链式 API

Tang 提供流畅的链式 API：

```cj
ctx.status(200u16)
    .set("Content-Type"),
            ("application/json")
    .set("X-Custom-Header"),
            ("value")
    .json(HashMap<String, String>([
            ("message"),
            ("Success)
        ]))
```

### 类型安全

使用 Option 类型处理可能为空的值：

```cj
// query() 返回 Option<String>
let name = ctx.query("name")

match (name) {
    case Some(n) => ctx.json(HashMap<String, String>([
            ("name", n))
    case None => ctx.json(HashMap<String, String>([
            ("error"),
            ("Missing name)
        ]))
}
```

## 性能特性

### 路由性能

- **O(k) 查找**：k 为路径深度
- **零拷贝**：最小化内存分配
- **自动优化**：树结构自动优化

### 并发处理

- **无锁设计**：减少锁竞争
- **高效复用**：中间件实例复用
- **内存高效**：最小化内存占用

## 与 Fiber 的对比

Tang 借鉴了 Fiber 的设计，但针对仓颉语言特性进行了优化：

| 特性 | Tang (仓颉) | Fiber (Go) |
|------|-------------|-------------|
| 语法风格 | 仓颉 | Go |
| 类型系统 | 强类型 + Option | 接口 + nil |
| 错误处理 | 模式匹配 | 多返回值 |
| 并发模型 | （待补充） | Goroutines |
| 中间件模式 | 相同 | 相同 |

## 适用场景

### 适合 Tang 的场景

✅ **REST API**：简洁的路由和中间件
✅ **微服务**：轻量级、高性能
✅ **Web 服务**：完整的 HTTP 功能
✅ **快速原型**：快速开发和迭代

### 可能不适合的场景

❌ **实时通信**：WebSocket 支持（待实现）
❌ **超高并发**：需要进一步的性能优化
❌ **复杂模板**：需要集成模板引擎

## 下一步

- **[快速入门](getting-started.md)** - 5 分钟上手 Tang
- **[API 参考](api/router.md)** - Router API 文档
- **[中间件文档](middleware/README.md)** - 中间件使用指南
- **[示例代码](../examples/middleware_showcase/)** - 完整示例

## 相关资源

- **GitHub 仓库**：[https://github.com/ystyle/tang](https://github.com/ystyle/tang)
- **仓颉语言**：[https://cangjie-lang.cn](https://cangjie-lang.cn)
- **Fiber 框架**：[https://github.com/gofiber/fiber](https://github.com/gofiber/fiber)
