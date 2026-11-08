

> **本分支说明**：本分支中间件行为基本不变；注意加密类中间件的 import 已改为 tang_ext_crypto.*。

# Group

## 概述

Group（路由组）用于组织路由并共享中间件。它允许你将相关的路由分组在一起，自动继承父组的中间件，并支持无限层级嵌套。

**核心特性**：
- **路径前缀**：自动为组内所有路由添加前缀
- **中间件继承**：子组自动继承父组的中间件
- **无限嵌套**：支持多层路由组嵌套
- **独立中间件**：每个组可以有自己的中间件栈
- **链式调用**：支持流畅的 API 链式调用

**文件位置**：`src/group.cj`

## 签名

```cj
public class Group {
    // 构造函数
    init(router: Router, path: String, stack: Array<MiddlewareFunc>)
    init(path: String, stack!: Array<MiddlewareFunc> = [])
    init()

    // 路由注册
    public func get(path: String, handler: HandlerFunc)
    public func post(path: String, handler: HandlerFunc)
    public func put(path: String, handler: HandlerFunc)
    public func delete(path: String, handler: HandlerFunc)
    public func patch(path: String, handler: HandlerFunc)
    public func head(path: String, handler: HandlerFunc)
    public func options(path: String, handler: HandlerFunc)
    public func all(path: String, handler: HandlerFunc)

    // 路由组操作
    public func group(path: String, opts!: Array<GroupOptionFunc> = Array()): Group
    public func use(middlewares: Array<MiddlewareFunc>): Group
}
```

## 创建路由组

### 基础用法

通过 `Router.group()` 创建路由组：

```cj
let r = Router()

// 创建 /api 路由组
let api = r.group("/api")

api.get("/users", { ctx =>  // 实际路径: /api/users
    ctx.json(ArrayList<String>())
})

api.post("/users", { ctx =>  // 实际路径: /api/users
    ctx.status(201).json(HashMap<String, String>([
            ("message", "Created")
        ]))
})
```

### 链式调用

路由组方法支持链式调用：

```cj
r.group("/api")
    .use(logger())
    .get("/users", handler1)
    .post("/users", handler2)
    .group("/v1")
        .get("/posts", handler3)
```

> **💡 提示：路由组的优势**
>
> 1. **代码组织**：将相关路由归类管理
> 2. **中间件复用**：避免在每个路由上重复添加中间件
> 3. **版本控制**：轻松实现 API 版本管理（/api/v1、/api/v2）
> 4. **权限控制**：为不同组的路由设置不同的认证中间件


## 中间件管理

### 应用中间件到路由组

使用 `use()` 方法为整个路由组添加中间件：

```cj
import tang.middleware.log.logger
import tang.middleware.cors.cors

let api = r.group("/api")

// 应用于整个组
api.use([logger(), cors()])

api.get("/users", { ctx =>
    // 这些路由会先经过 logger 和 cors 中间件
    ctx.json(users)
})

api.post("/users", { ctx =>
    // 这里也会经过 logger 和 cors
    ctx.status(201).json(createdUser)
})
```

### 中间件继承顺序

子路由组自动继承父组的中间件：

```cj
import tang.middleware.log.logger
import tang.middleware.cors.cors

let api = r.group("/api")
api.use([logger()])  // API 层级：logger

let v1 = api.group("/v1")
v1.use([cors()])    // V1 层级：logger + cors

v1.get("/users", { ctx =>
    // 中间件执行顺序：logger → cors → handler
    ctx.json(users)
})
```

**执行顺序**：父组中间件 → 子组中间件 → Handler

### 中间件栈示例

```cj
import tang.middleware.log.logger
import tang.middleware.cors.cors
import tang.middleware.auth.basicAuth

let r = Router()

// 全局中间件
r.use([logger()])

// API 组（继承 logger）
let api = r.group("/api")

// 公开端点（不需要认证）
let public = api.group("/public")
public.get("/health", { ctx =>
    ctx.json(HashMap<String, String>([
            ("status", "ok")
        ]))
})

// 受保护端点（需要认证）
let protected = api.group("/protected")
protected.use([basicAuth({ username, password =>
    username == "admin" && password == "secret"
})])

protected.get("/users", { ctx =>
    ctx.json(users)
})

protected.get("/data", { ctx =>
    ctx.json(data)
})
```

**中间件执行流程**：
```
请求: GET /api/protected/users

执行顺序：
1. logger（Router 层）
2. basicAuth（protected 层）
3. handler

如果认证失败，basicAuth 会返回 401，不会到达 handler
```

## 嵌套路由组

### 两层嵌套

```cj
let api = r.group("/api")
let v1 = api.group("/v1")

v1.get("/users", handler)  // 路径: /api/v1/users
v1.get("/posts", handler)  // 路径: /api/v1/posts
```

### 三层嵌套

```cj
let api = r.group("/api")
let v1 = api.group("/v1")
let users = v1.group("/users")

users.get("/", handler1)      // 路径: /api/v1/users
users.get("/:id", handler2)   // 路径: /api/v1/users/:id
users.get("/:id/posts", handler3)  // 路径: /api/v1/users/:id/posts
```

### 不同版本的 API

```cj
let api = r.group("/api")

// v1 API
let v1 = api.group("/v1")
v1.get("/users", { ctx =>
    ctx.json(HashMap<String, String>([
            ("version", "v1")
        ]))
})

// v2 API
let v2 = api.group("/v2")
v2.get("/users", { ctx =>
    ctx.json(HashMap<String, String>([
            ("version", "v2")
        ]))
})
```

测试：

```bash
curl http://localhost:8080/api/v1/users
# {"version":"v1","data":"users"}

curl http://localhost:8080/api/v2/users
# {"version":"v2","data":"users"}
```

## 完整示例

### REST API 组织

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 全局中间件
    r.use([recovery(), logger()])

    // 根路由
    r.get("/", { ctx =>
        ctx.writeString("Welcome to API!")
    })

    // API 路由组
    let api = r.group("/api")
    api.use([cors()])

    // 公开端点
    let public = api.group("/public")
    public.get("/health", { ctx =>
        ctx.json(HashMap<String, String>([
            ("status", "healthy")
        ]))
    })

    // v1 API
    let v1 = api.group("/v1")

    // 用户资源
    let users = v1.group("/users")
    users.get("/", { ctx =>
        ctx.json(ArrayList<HashMap<String, String>>())
    })
    users.post("/", { ctx =>
        ctx.status(201).json(HashMap<String, String>([
            ("message", "User created")
        ]))
    })

    // 单个用户操作
    let user = v1.group("/users/:id")
    user.get("/", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("name", "User ${id}")
        ]))
    })
    user.put("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "User updated")
        ]))
    })
    user.delete("/", { ctx =>
        ctx.status(204).body("")
    })

    // 文章资源
    let posts = v1.group("/posts")
    posts.get("/", { ctx =>
        ctx.json(ArrayList<HashMap<String, String>>())
    })
    posts.post("/", { ctx =>
        ctx.status(201).json(HashMap<String, String>([
            ("message", "Post created")
        ]))
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

### 带权限控制的路由组

```cj
import tang.*
import tang.middleware.auth.basicAuth
import tang.middleware.keyauth.keyauth
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 公开路由
    r.get("/", { ctx =>
        ctx.writeString("Public home page")
    })

    // Basic 认证路由组
    let basicAuthGroup = r.group("/basic")
    basicAuthGroup.use([basicAuth({ username, password =>
        username == "admin" && password == "secret"
    })])

    basicAuthGroup.get("/dashboard", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Basic Auth protected")
        ]))
    })

    // API Key 认证路由组
    let apiKeyGroup = r.group("/api")
    apiKeyGroup.use([keyauth([
        withKeyLookup("header:X-API-Key"),
        withValidator({ key =>
            key == "your-secret-api-key"
        })
    ])])

    apiKeyGroup.get("/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "API Key protected")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 分层中间件架构

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import tang.middleware.ratelimit.ratelimit
import tang.middleware.auth.basicAuth
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 第一层：全局中间件
    r.use([
        recovery(),     // 异常恢复
        logger(),       // 请求日志
    ])

    // 第二层：API 组
    let api = r.group("/api")
    api.use([
        cors(),                     // CORS 支持
        ratelimit([                 // 速率限制
            withMaxRequests(100),
            withWindowMs(60000)
        ])
    ])

    // 第三层：v1 API
    let v1 = api.group("/v1")

    // 第四层：公开资源
    let public = v1.group("/public")
    public.get("/health", { ctx =>
        ctx.json(HashMap<String, String>([
            ("status", "ok")
        ]))
    })

    // 第四层：受保护资源
    let protected = v1.group("/protected")
    protected.use([
        basicAuth({ username, password =>  // 认证
            username == "admin" && password == "secret"
        })
    ])

    protected.get("/users", { ctx =>
        ctx.json(ArrayList<String>())
    })

    protected.get("/data", { ctx =>
        ctx.json(HashHashMap<String, String>([
            ("data", "sensitive")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

## 路径拼接规则

### 自动拼接

Group 会自动拼接路径前缀：

```cj
let api = r.group("/api")
let v1 = api.group("/v1")
let users = v1.group("/users")

users.get("/", handler)  // 最终路径: /api/v1/users
```

### 尾部斜杠处理

Group 会自动处理尾部斜杠：

```cj
let api = r.group("/api")     // /api
let v1 = api.group("/v1/")    // 自动清理为 /v1
let users = v1.group("users") // 自动添加前导斜杠

users.get("/", handler)  // 最终路径: /api/v1/users
```

### 路径验证

如果路径不以 `/` 开头，会抛出异常：

```cj
// ❌ 错误
let invalid = r.group("api")  // 抛出异常：path must start with a slash

// ✅ 正确
let valid = r.group("/api")
```

## 与 Router 的区别

| 特性 | Router | Group |
|------|--------|-------|
| **顶层入口** | ✅ | ❌ |
| **路径前缀** | 无（或根路径 `/`） | 支持任意前缀 |
| **独立使用** | ✅ | ❌（必须依附于 Router） |
| **嵌套支持** | ✅（通过 group()） | ✅（支持无限嵌套） |
| **中间件继承** | ❌ | ✅（子组继承父组） |
| **主要用途** | 创建应用入口 | 组织路由结构 |

## 最佳实践

### 1. 合理的层级深度

建议不超过 3-4 层：

```cj
// ✅ 推荐：3 层
r.group("/api")
  .group("/v1")
    .group("/users")

// ⚠️ 谨慎使用：超过 4 层
r.group("/api")
  .group("/v1")
    .group("/users")
      .group("/:id")
        .group("/posts")
          .group("/:postId")  // 路径太长，难以维护
```

### 2. 语义化的组名

```cj
// ✅ 推荐：语义化
let api = r.group("/api")
let v1 = api.group("/v1")
let users = v1.group("/users")

// ❌ 避免：无意义的组名
let g1 = r.group("/g1")
let g2 = g1.group("/g2")
let g3 = g2.group("/g3")
```

### 3. 中间件分层原则

```cj
// ✅ 推荐：按功能分层中间件
r.use([recovery(), logger()])           // 全局：异常、日志
let api = r.group("/api")
api.use([cors(), ratelimit()])          // API 层：CORS、限流
let protected = api.group("/protected")
protected.use([auth()])                 // 受保护层：认证

// ❌ 避免：所有中间件堆在一起
r.use([recovery(), logger(), cors(), ratelimit(), auth()])
```

### 4. 路由资源命名

遵循 RESTful 约定：

```cj
// ✅ 推荐：使用复数名词
let users = v1.group("/users")
let posts = v1.group("/posts")
let comments = v1.group("/comments")

// ❌ 避免：使用单数或不一致的命名
let user = v1.group("/user")
let User = v1.group("/User")
let post = v1.group("/posts")  // 不一致
```

## 工作原理

### 路径拼接算法

```cj
func joinPath(base: String, path: String): String {
    // 1. 验证路径格式
    checkPath(path)  // 确保以 / 开头

    // 2. 拼接路径
    let combined = base + path

    // 3. 转换为 Rune 数组处理 Unicode
    let runes = combined.toRuneArray()

    // 4. 移除尾部斜杠（除非是根路径）
    if (runes.size > 1 && runes[runes.size - 1] == r'/') {
        return String(runes[..runes.size - 1])
    }

    return String(runes)
}
```

### 中间件栈构建

Group 使用"洋葱模型"构建中间件栈：

```cj
func wrap(handler: HandlerFunc): HandlerFunc {
    var wrapped = handler
    var i = 0

    // 从后向前包装中间件
    while (i < this.stack.size) {
        let middleware = this.stack[this.stack.size - 1 - i]
        wrapped = middleware(wrapped)
        i++
    }

    return wrapped
}
```

**执行顺序**：
```
请求 → Middleware1 → Middleware2 → Handler
响应 ← Middleware1 ← Middleware2 ← Handler
```

## 注意事项

### 1. 路径参数在组级定义无效

```cj
// ❌ 错误：组级路径参数不会被保留
let users = r.group("/users/:id")
users.get("/profile", handler)  // 路径是 /users/:id/profile，不是 /users/123/profile

// ✅ 正确：在路由级定义路径参数
let users = r.group("/users")
users.get("/:id/profile", handler)  // 路径是 /users/:id/profile
```

### 2. 通配符路由要谨慎使用

```cj
// ⚠️ 谨慎使用：通配符会捕获所有子路径
let files = r.group("/files")
files.all("/*", handler)  // 会匹配 /files/*，但不包括 /files

// ✅ 正确做法：显式注册两个路由
files.get("/", handler1)  // /files
files.all("/*", handler2) // /files/*
```

### 3. 中间件顺序很重要

```cj
// ❌ 错误顺序：认证在 CORS 之前
let api = r.group("/api")
api.use([auth(), cors()])  // OPTIONS 预检请求会被 auth 拦截

// ✅ 正确顺序：CORS 在认证之前
let api = r.group("/api")
api.use([cors(), auth()])
```

## 相关链接

- **[Router API](router.md)** - Router 类详细文档
- **[中间件文档](../middleware/overview.md)** - 中间件系统原理
- **[源码](../../src/group.cj)** - Group 类源代码
