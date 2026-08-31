
# Router

## 概述

Router 是 Tang 框架的核心组件，负责 HTTP 请求的路由和分发。它基于 Radix Tree（基数树）实现，提供高性能的路由匹配能力。

**核心特性**：
- **Radix Tree 路由**：O(k) 时间复杂度（k 为路径深度）
- **动态参数支持**：`/users/:id` 风格的路径参数
- **通配符路由**：`/files/*` 风格的通配符匹配
- **HTTP 方法支持**：GET、POST、PUT、PATCH、DELETE、HEAD、OPTIONS
- **自动 HEAD 回退**：HEAD 请求自动使用 GET 处理器（符合 HTTP 标准）
- **路径重写**：支持在路由匹配前重写请求路径
- **规范化重定向**：自动处理尾部斜杠（trailing slash）

**文件位置**：`src/router.cj`

## 签名

```cj
public class Router <: HttpRequestDistributor {
    public init()
    public init(opts: Array<OptionFunc>)

    // HTTP 方法注册
    public func get(path: String, handler: HandlerFunc)
    public func post(path: String, handler: HandlerFunc)
    public func put(path: String, handler: HandlerFunc)
    public func delete(path: String, handler: HandlerFunc)
    public func patch(path: String, handler: HandlerFunc)
    public func head(path: String, handler: HandlerFunc)
    public func options(path: String, handler: HandlerFunc)
    public func all(path: String, handler: HandlerFunc)

    // 路由组
    public func group(path: String): Group

    // 路径重写
    public func addRewriteRule(rule: (String) -> String): Unit
}
```

## 创建 Router

### 无参数构造

```cj
let r = Router()
```

### 带配置的构造

```cj
import tang.*

let r = Router([
    withNotFoundHandler({ ctx =>
        ctx.status(404).json(HashMap<String, String>([
            ("error", "Not Found")
        ]))
    })
])
```

## HTTP 方法注册

### GET 请求

注册 GET 请求处理器：

```cj
r.get("/", { ctx =>
    ctx.writeString("Hello, World!")
})
```

### POST 请求

注册 POST 请求处理器：

```cj
r.post("/users", { ctx =>
    let body = ctx.bindJson<HashMap<String, String>>()
    // 处理创建逻辑...
    ctx.status(201).json(HashMap<String, String>([
        ("message", "User created")
    ]))
})
```

### PUT 请求

注册 PUT 请求处理器（更新资源）：

```cj
r.put("/users/:id", { ctx =>
    let id = ctx.param("id")
    let body = ctx.bindJson<HashMap<String, String>>()
    // 处理更新逻辑...
    ctx.json(HashMap<String, String>([
        ("message", "User ${id} updated")
    ]))
})
```

### DELETE 请求

注册 DELETE 请求处理器（删除资源）：

```cj
r.delete("/users/:id", { ctx =>
    let id = ctx.param("id")
    // 处理删除逻辑...
    ctx.status(204).body("")
})
```

### PATCH 请求

注册 PATCH 请求处理器（部分更新）：

```cj
r.patch("/users/:id", { ctx =>
    let id = ctx.param("id")
    // 处理部分更新逻辑...
    ctx.json(HashMap<String, String>([
        ("message", "User ${id} patched")
    ]))
})
```

### HEAD 请求

注册 HEAD 请求处理器：

```cj
r.head("/users", { ctx =>
    // HEAD 请求只返回响应头，不返回 body
    ctx.responseBuilder.status(200u16)
})
```

**注意**：如果未注册 HEAD 处理器，Tang 会自动回退到 GET 处理器（HTTP 标准行为）。

### OPTIONS 请求

注册 OPTIONS 请求处理器：

```cj
r.options("/users", { ctx =>
    ctx.responseBuilder
        .status(200u16)
        .header("Allow", "GET, POST, PUT, DELETE, OPTIONS")
        .header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
})
```

### 匹配所有 HTTP 方法

使用 `all()` 匹配所有 HTTP 方法：

```cj
r.all("/webhook", { ctx =>
    // 处理所有 HTTP 方法的请求
    ctx.json(HashMap<String, String>([
        ("method", ctx.method()),
        ("message", "Webhook received")
    ]))
})
```

> **💡 提示：HTTP 方法选择指南**
>
> - **GET**：获取资源，幂等且安全
> - **POST**：创建资源，非幂等
> - **PUT**：完整更新资源，幂等
> - **PATCH**：部分更新资源，可能非幂等
> - **DELETE**：删除资源，幂等
> - **HEAD**：只获取响应头（用于检查资源是否存在）
> - **OPTIONS**：获取服务器支持的 HTTP 方法
> - **all()**：处理所有方法（适用于 Webhook）

## stdx 风格注册 register()

`Router` 实现了 `HttpRequestDistributor` 接口的 `register()`，可按 stdx 语义**路径级注册**（不区分 HTTP 方法，等价于 `all()`）：

```cj
import stdx.net.http.{HttpContext}

let r = Router()

// 函数式：任意 HTTP 方法（GET/POST/PUT/DELETE...）都能命中
r.register("/ping", { ctx: HttpContext =>
    ctx.responseBuilder.body("pong")
})

// 类式：任意 HttpRequestHandler（FuncHandler / FileHandler / NotFoundHandler 等）
r.register("/file", fromStd(FileHandler("./public", handlerType: FileHandlerType.DownLoad)))
```

- 路径支持 `:param` / `*` 语法（走同一条 radix tree）
- 转换后自动享受所在 group 的中间件链
- 与 stdx 默认 distributor 语义一致，可无差别替换

## 子应用挂载 mount()

Fiber 风格 `app.Mount`，把子 Router 的路由以 `prefix` 前缀注册到当前 Router（**注册展开**）：

```cj
let r = Router()
let subRouter = Router()
subRouter.get("/users/:id", { ctx => ctx.writeString("user-" + ctx.param("id")) })

r.mount("/api", subRouter)   // 实际路径 /api/users/:id
```

- **中间件保留**：子 Router mount 前 wrap 的中间件原样生效
- **路径参数照常**：走同一条 radix tree；`all()` 语义保留
- **快照语义**：mount 后子 Router 新增路由不生效（与 Fiber `app.Mount` 一致）
- **404 兜底**：子 Router 未命中的路径由父 Router 处理
- 配合 `Tang.mount()` 使用（`app.mount(prefix, subApp.getRouter())`）

## 路径参数

### 单个参数

使用 `:param` 语法定义路径参数：

```cj
r.get("/users/:id", { ctx =>
    let id = ctx.param("id")
    ctx.json(HashMap<String, String>([
        ("userId", id)
    ]))
})

// 访问: /users/123
// 输出: {"userId":"123"}
```

### 多个参数

```cj
r.get("/users/:userId/posts/:postId", { ctx =>
    let userId = ctx.param("userId")
    let postId = ctx.param("postId")
    ctx.json(HashMap<String, String>([
        ("userId", userId),
        ("postId", postId)
    ]))
})

// 访问: /users/123/posts/456
// 输出: {"userId":"123","postId":"456"}
```

### 通配符参数

使用 `*` 匹配剩余路径：

```cj
r.get("/files/*", { ctx =>
    let filePath = ctx.param("*")  // 获取通配符匹配的部分
    ctx.json(HashMap<String, String>([
        ("filePath", filePath)
    ]))
})

// 访问: /files/docs/guide.pdf
// 输出: {"filePath":"docs/guide.pdf"}
```

> **💡 提示：路径参数优先级**（从高到低）：
>
> 1. **精确匹配**：`/users/profile` > `/users/:id`
> 2. **动态参数**：`/users/:id` > `/users/*`
> 3. **通配符**：`/files/*` 匹配所有子路径
>
> **注意**：通配符 `*` 必须是路径的最后一个片段


## 路由组

### 创建路由组

使用 `group()` 方法创建路由组：

```cj
let api = r.group("/api")

api.get("/users", handler)  // 实际路径: /api/users
api.post("/users", handler) // 实际路径: /api/users
```

### 嵌套路由组

```cj
let api = r.group("/api")
let v1 = api.group("/v1")
let users = v1.group("/users")

users.get("/", handler)      // 实际路径: /api/v1/users
users.get("/:id", handler)   // 实际路径: /api/v1/users/:id
```

### 路由组中间件

```cj
import tang.middleware.log.logger
import tang.middleware.cors.cors

let api = r.group("/api")

// 应用于整个组
api.use(logger())
api.use(cors())

api.get("/users", { ctx =>
    // 这些路由会经过 logger 和 cors 中间件
    ctx.json(users)
})
```

详细的路由组文档请参考 [Group API](group.md)。

## 路径重写

### 添加重写规则

使用 `addRewriteRule()` 在路由匹配前重写路径：

```cj
import tang.middleware.rewrite.createRewriteFunction

// 重写 /old/* -> /new/*
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))

// 重写 /api/v1/* -> /api/v2/*
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))

// 注册路由
r.get("/new/users", { ctx =>
    // 访问 /old/users 会被重写为 /new/users
    ctx.writeString("This matches /new/users")
})
```

### 移除路径前缀

```cj
// 移除 /api/v1 前缀
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/$1"))

r.get("/users", { ctx =>
    // 访问 /api/v1/users 会被重写为 /users
    ctx.writeString("Users endpoint")
})
```

> **💡 提示：重写 vs 重定向**
>
> - **路径重写**：服务器端重写 URL，浏览器地址栏不变
> - **重定向**：告诉浏览器访问新 URL，地址栏会改变
>
> **注意**：重写在路由匹配**之前**执行，可以影响路由匹配结果


## 自动规范化

### 尾部斜杠处理

Tang 会自动处理尾部斜杠：

```cj
r.get("/users", handler)

// 以下请求都会匹配：
// - http://localhost:8080/users
// - http://localhost:8080/users/ (自动重定向到 /users)
```

### 路径清理

Tang 会自动清理多余斜杠：

```cj
r.get("/users/profile", handler)

// 以下请求都会匹配：
// - /users/profile
// - /users//profile (自动清理)
```

## 完整示例

### REST API 服务器

```cj
import tang.*
import stdx.net.http.ServerBuilder
import std.collection.HashMap

main() {
    let r = Router()

    // 用户资源路由
    let users = r.group("/users")

    // 获取所有用户
    users.get("/", { ctx =>
        ctx.json(ArrayList<HashMap<String, String>>())
    })

    // 创建用户
    users.post("/", { ctx =>
        let body = ctx.bindJson<HashMap<String, String>>()
        match (body) {
            case Some(data) =>
                ctx.status(201).json(HashMap<String, String>([
                    ("id", "1"),
                    ("name", data.getOrDefault("name", "Unknown"))
                ]))
            case None =>
                ctx.status(400).json(HashMap<String, String>([
                    ("error", "Invalid JSON")
                ]))
    })

    // 单个用户路由
    let user = r.group("/users/:id")

    // 获取单个用户
    user.get("/", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("id", id),
            ("name", "User ${id}")
        ]))
    })

    // 更新用户
    user.put("/", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("message", "User ${id} updated")
        ]))
    })

    // 删除用户
    user.delete("/", { ctx =>
        let id = ctx.param("id")
        ctx.status(204).body("")
    })

    // 启动服务器
    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    println("🚀 Server running on http://localhost:8080")
    server.serve()
}
```

### 带中间件的路由

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import tang.middleware.recovery.recovery
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 全局中间件
    r.use(recovery())
    r.use(logger())

    // 公开路由
    r.get("/", { ctx =>
        ctx.writeString("Welcome to Tang API!")
    })

    // API 路由组
    let api = r.group("/api")
    api.use(cors())

    // v1 API
    let v1 = api.group("/v1")
    v1.get("/users", { ctx => ctx.json(ArrayList<String>()) })
    v1.get("/users/:id", { ctx =>
        ctx.json(HashMap<String, String>([
            ("id", ctx.param("id"))
        ]))
    })

    // 启动服务器
    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

## 工作原理

### Radix Tree 路由

Router 使用 Radix Tree（基数树）数据结构实现高效路由匹配：

```
                (root)
                 |
                / \
              GET  POST
              |     |
            users  users
             |      |
          :id      (leaf)
           |
         posts
           |
         :postId
           |
         (leaf)
```

**优点**：
- **快速查找**：O(k) 时间复杂度（k 为路径深度）
- **参数提取**：一次遍历同时匹配和提取参数
- **内存高效**：公共路径前缀共享节点

### 请求分发流程

```
1. HTTP 请求到达
   ↓
2. applyRewriteRules(path)  // 应用路径重写规则
   ↓
3. tree.searchRoute(method, path)  // Radix Tree 查找
   ↓
4. 如果没找到 && method == HEAD
   → 回退到 GET 处理器
   ↓
5. 如果没找到
   → 尝试规范化重定向（trailing slash）
   ↓
6. 如果还是没找到
   → 调用 404 处理器
   ↓
7. 创建 TangHttpContext
   ↓
8. 执行中间件栈
   ↓
9. 执行 Handler
```

## 注意事项

### 1. 路径必须以 `/` 开头

```cj
// ✅ 正确
r.get("/users", handler)

// ❌ 错误
r.get("users", handler)  // 会抛出异常
```

### 2. 路径参数不能在通配符之后

```cj
// ✅ 正确
r.get("/users/:id/posts/*", handler)

// ❌ 错误
r.get("/users/*/posts/:id", handler)  // 通配符必须最后
```

### 3. 相同路径和方法的重复注册

后注册的路由会覆盖先注册的路由：

```cj
r.get("/users", handler1)
r.get("/users", handler2)  // handler1 会被 handler2 覆盖
```

### 4. HEAD 请求自动回退

如果没有注册 HEAD 处理器，会自动使用 GET 处理器（但不会返回 body）：

```cj
r.get("/users", { ctx =>
    ctx.writeString("User list")
})

// HEAD /users 会自动匹配 GET 处理器，但不返回 body
```

## 性能考虑

- **Radix Tree**：路由查找效率 O(k)，k 为路径深度
- **参数解析**：路径参数在路由匹配时自动提取，无需额外解析
- **中间件栈**：每个路由继承父路由组的中间件（共享引用）

## 相关链接

- **[Group API](group.md)** - 路由组详细文档
- **[Radix Tree 原理](../advanced/radix-tree-routing.md)** - 深入理解路由实现
- **[源码](../../src/router.cj)** - Router 类源代码
