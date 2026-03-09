# Tang

> 一个基于仓颉语言的高性能 Web 框架，受 [Fiber](https://github.com/gofiber/fiber) 启发

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
[![Cangjie](https://img.shields.io/badge/Cangjie-1.0.0+-orange.svg)](https://cangjie-lang.cn)

## ✨ 特性

- **🚀 高性能路由** - 基于 Radix Tree 实现，O(k) 查找复杂度
- **⛓️ 链式 API** - Fiber 风格的流畅 API 设计
- **🔌 中间件生态** - 23+ 内置中间件，覆盖常见场景
- **📦 开箱即用** - JSON 解析、Cookie、会话管理等内置功能
- **💡 简洁易用** - 清晰的 API 设计，快速上手

### ⚙️ 环境配置

**本分支适配仓颉 1.0.0 版本**，需要设置 `stdx` 依赖的环境变量：

```bash
# 需要换成自己的 stdx 路径
export CANGJIE_STDX_PATH=${HOME}/.config/cjvs/stdx/1.0.0/linux_x86_64_llvm/dynamic/stdx
```

## 🚀 快速开始

### Hello World

```cj
import tang.*

main() {
    let app = Tang()

    app.get("/", { ctx =>
        ctx.writeString("Hello, Tang!")
    })

    app.listen(8080u16)
}
```

### REST API 示例

```cj
import tang.*
import std.collection.HashMap

main() {
    let app = Tang()

    // GET 请求
    app.get("/users/:id", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("userId", id),
            ("name", "Alice")
        ]))
    })

    // POST 请求
    app.post("/users", { ctx =>
        let body = ctx.fromValue("name") ?? ""
        // 创建用户...
        ctx.status(201u16).json(HashMap<String, String>([
            ("message", "User created"),
            ("name", body)
        ]))
    })

    app.listen()
}
```

### 中间件使用

```cj
import tang.*
import tang.middleware.recovery.recovery
import tang.middleware.log.logger
import tang.middleware.cors.cors

main() {
    let app = Tang()

    // 全局中间件
    app.use(recovery())
    app.use(logger())
    app.use(cors())

    // 路由组
    let api = app.group("/api")

    api.get("/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "API data")
        ]))
    })

    app.listen()
}
```

## 📚 文档

完整文档请查看：[**📖 docs/**](./docs/)

### 核心文档

- **[快速入门](./docs/getting-started.md)** - 5 分钟上手 Tang 框架
- **[框架概述](./docs/overview.md)** - 设计理念和核心概念
- **[API 参考](./docs/api/)** - Router、Group、Context API 文档
- **[中间件文档](./docs/middleware/)** - 23+ 内置中间件使用指南
- **[性能优化](./docs/advanced/performance.md)** - 生产环境性能调优

### 中间件列表

**安全类**：Security、CORS、CSRF、BasicAuth、KeyAuth、EncryptCookie

**日志监控**：Logger、AccessLog、RequestID、Recovery

**流量控制**：RateLimit、BodyLimit、Timeout

**缓存优化**：Cache、ETag

**会话管理**：Session

**其他**：Proxy、Redirect、Rewrite、StaticFile、Favicon、HealthCheck、Idempotency

## 🎯 路由特性

### 静态路由

```cj
r.get("/users/profile", handler)  // 精确匹配
```

### 动态参数

```cj
r.get("/users/:id", { ctx =>
    let id = ctx.param("id")  // 捕获路径参数
})
```

### 通配符

```cj
r.get("/files/*", { ctx =>
    let path = ctx.param("*")  // 匹配剩余所有路径
})
```

### 路由分组

```cj
let api = r.group("/api")
api.use(cors())  // 应用到整个组

let v1 = api.group("/v1")
v1.get("/users", handler)  // 实际路径: /api/v1/users
```

## 📁 示例代码

- **[Hello World](./examples/basic/)** - 最小示例
- **[REST API](./examples/todo/)** - Todo REST API 示例
- **[中间件演示](./examples/middleware_showcase/)** - 23+ 中间件完整演示

## 🔗 相关链接

- **[仓颉语言](https://cangjie-lang.cn)** - 仓颉编程语言官网
- **[Fiber 框架](https://github.com/gofiber/fiber)** - Go 语言 Web 框架（设计灵感来源）

## 📝 许可证

[MIT License](../LICENSE)

---

**开始使用**：查看 [**快速入门文档**](./docs/getting-started.md) 🚀
