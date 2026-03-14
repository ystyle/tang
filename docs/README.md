
# Tang Web 框架文档

欢迎来到 Tang 框架文档！Tang 是一个基于仓颉语言构建的高性能 Web 框架，受到 [Fiber](https://github.com/gofiber/fiber) 的启发，提供了简洁优雅的链式 API 和强大的中间件生态系统。

## ✨ 特性

- **🚀 高性能路由**：基于 Radix Tree 实现的路由系统，支持动态参数和通配符
- **⛓️ 链式 API**：Fiber 风格的流畅 API 设计，提升开发体验
- **🔌 中间件系统**：23+ 内置中间件，覆盖日志、安全、认证、缓存等场景
- **🎯 RESTful 支持**：轻松构建 REST API 和 Web 服务
- **💡 简洁易用**：清晰的 API 设计，快速上手

## 📚 文档导航

### 快速开始

- **[快速入门](getting-started.md)** - 5 分钟上手 Tang 框架
- **[框架概述](overview.md)** - Tang 的设计理念和核心概念

### API 参考

- **[Router](api/router.md)** - 路由系统 API 参考
- **[Group](api/group.md)** - 路由分组 API 参考
- **[TangHttpContext](api/context/)** - HTTP 上下文 API
  - [请求处理](api/context/request.md) - Query、Param、Body 解析
  - [响应操作](api/context/response.md) - 状态码、Headers、JSON 响应
  - [Cookie 操作](api/context/cookie.md) - Cookie 读写
  - [辅助方法](api/context/utils.md) - 请求信息、IP、协议等

### 中间件

- **[中间件概述](middleware/overview.md)** - 中间件系统原理
- **[自定义中间件](middleware/custom.md)** - 开发自定义中间件
- **[内置中间件](middleware/builtin/)** - 23+ 内置中间件文档
  - [Recovery](middleware/builtin/recovery.md) - 异常恢复
  - [Logger](middleware/builtin/log.md) - 请求日志
  - [CORS](middleware/builtin/cors.md) - 跨域资源共享
  - [CSRF](middleware/builtin/csrf.md) - CSRF 保护
  - [Session](middleware/builtin/session.md) - 会话管理
  - [RateLimit](middleware/builtin/ratelimit.md) - 请求速率限制
  - [Proxy](middleware/builtin/proxy.md) - 反向代理
  - [Idempotency](middleware/builtin/idempotency.md) - 幂等性控制
  - ... [更多中间件](middleware/builtin/)

### 高级主题

- **[性能优化](advanced/performance.md)** - 性能调优指南
- **[性能基准测试](advanced/benchmark.md)** - Tang vs stdx 性能对比

### 示例

- **[Hello World](../examples/basic/)** - 最小示例
- **[REST API](../examples/todo/)** - Todo REST API 示例
- **[中间件演示](../examples/middleware_showcase/)** - 23+ 中间件完整演示

## 🚀 快速开始

### 安装

确保你已经安装了仓颉 SDK 和 stdx。

```bash
# 克隆仓库（国内可以使用 gitcode）
git clone https://github.com/ystyle/tang.git
# 或者使用 gitcode：git clone https://gitcode.com/ystyle/tang.git
cd tang

# 构建项目
cjpm build

# 运行示例
cd examples/basic # 或者其它的
cjpm run
```

### Hello World

创建 `main.cj` 文件：

```cj
import tang.*

main() {
    // 创建 Tang 应用
    let app = Tang()

    // 注册路由
    app.get("/", { ctx =>
        ctx.writeString("Hello, Tang!")
    })

    // 启动应用（自动打印 Banner 和路由）
    app.listen(8080u16)
}
```

运行：

```bash
cjpm run
```

访问 `http://localhost:8080`，你将看到 "Hello, Tang!"。

## 📖 核心概念

### Router（路由器）

Router 是 Tang 的核心组件，负责 HTTP 请求的路由和分发。

```cj
let r = Router()

// 注册路由
r.get("/users", handler)      // GET 请求
r.post("/users", handler)     // POST 请求
r.put("/users/:id", handler)  // PUT 请求（带路径参数）
r.delete("/users/:id", handler) // DELETE 请求
```

### Group（路由组）

Group 允许你组织路由并共享中间件。

```cj
let api = r.group("/api")
api.use(middleware1())  // 应用于整个组

let v1 = api.group("/v1")
v1.get("/users", handler)  // 实际路径: /api/v1/users
```

### Middleware（中间件）

中间件是拦截 HTTP 请求和响应的函数。

```cj
// 全局中间件
r.use(logger())

// 路由组中间件
api.use(cors())

// 特定路由中间件
r.get("/protected", auth(), handler)
```

### TangHttpContext（上下文）

Context 包含了 HTTP 请求和响应的所有信息。

```cj
import std.collection.HashMap

func handler(ctx: TangHttpContext) {
    // 读取请求信息
    let name = ctx.param("name")

    // 发送响应
    ctx.json(HashMap<String, String>([
        ("message", "Hello, ${name}")
    ]))
}
```

## 🎯 设计理念

Tang 框架的设计遵循以下原则：

1. **简洁优先**：API 设计简洁明了，易于理解和使用
2. **性能至上**：基于 Radix Tree 的高性能路由，最小化内存分配
3. **Fiber 风格**：借鉴 Fiber 的成功经验，提供熟悉的开发体验
4. **仓颉原生**：充分利用仓颉语言特性，如类型安全、模式匹配等
5. **中间件生态**：丰富的内置中间件，开箱即用

## 📊 性能

Tang 使用 Radix Tree 路由算法，提供：

- **O(k) 路由查找复杂度**（k 为路径深度）
- **支持动态参数**：`/users/:id`
- **支持通配符**：`/files/*`
- **自动 HEAD → GET 转换**

## 🔗 相关资源

- **GitHub 仓库**：[https://github.com/ystyle/tang](https://github.com/ystyle/tang)
- **仓颉语言文档**：[https://cangjie-lang.cn](https://cangjie-lang.cn)
- **问题反馈**：[GitHub Issues](https://github.com/ystyle/tang/issues)

## 📝 许可证

本项目采用 MulanPSLv2 许可证。详见 [LICENSE](../LICENSE) 文件。

---

**准备好开始了吗？** 从 [快速入门](getting-started.md) 开始你的 Tang 之旅！
