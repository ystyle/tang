# 快速入门

欢迎来到 Tang 框架！本指南将带你用 5 分钟时间构建一个功能完整的 Web 应用。

## 📋 前置要求

开始之前，确保你已安装：

- **仓颉 SDK**（1.0.0 或更高版本）
- **stdx**（1.0.0 或更高版本）- 仓颉扩展库
- 任意代码编辑器（VS Code、IntelliJ IDEA 等）

## 🚀 第一步：创建项目

创建一个新的项目目录并初始化：

```bash
mkdir my-tang-app
cd my-tang-app

# 初始化仓颉项目
cjpm init
```

在 `cjpm.toml` 中添加 Tang 框架依赖：

**方式一：中心仓依赖（推荐）**

```toml
[dependencies]
  tang = "1.0.3"
```

**方式二：Git 依赖**

```toml
[dependencies]
  tang = { git = "https://github.com/ystyle/tang.git", branch = "master" }
  # 国内可以使用 gitcode
  tang = { git = "https://gitcode.com/ystyle/tang.git", branch = "master" }
```

然后安装依赖：

```bash
cjpm update
```

### ⚙️ 配置 stdx 环境变量

**本框架适配仓颉 1.0.0 版本**，在使用前需要设置 `stdx` 依赖的环境变量：

```bash
# 设置 stdx 路径（请根据实际安装位置调整）
export CANGJIE_STDX_PATH=${HOME}/.config/cjvs/stdx/1.0.0/linux_x86_64_llvm/dynamic/stdx
```

**Tips**：若需要，将此环境变量添加到 shell 配置文件中，使其永久生效：

```bash
# 对于 bash 用户
echo 'export CANGJIE_STDX_PATH=${HOME}/.config/cjvs/stdx/1.0.0/linux_x86_64_llvm/dynamic/stdx' >> ~/.bashrc
source ~/.bashrc

# 对于 zsh 用户
echo 'export CANGJIE_STDX_PATH=${HOME}/.config/cjvs/stdx/1.0.0/linux_x86_64_llvm/dynamic/stdx' >> ~/.zshrc
source ~/.zshrc
```

> **💡 提示：依赖管理**
>
> 仓颉使用 `cjpm` (Cangjie Package Manager) 管理项目依赖：
> - **git 依赖**：直接从 Git 仓库拉取源码
> - **branch**：指定分支（如 `master`、`main`、`develop`）
> - **tag**：也可以指定版本标签（如 `v1.0.0`）
>
> 示例：
> ```toml
> # 使用特定分支
> tang = { git = "https://github.com/ystyle/tang.git", branch = "master" }
> # 国内可以使用 gitcode
> tang = { git = "https://gitcode.com/ystyle/tang.git", branch = "master" }
>
> # 使用特定版本标签
> tang = { git = "https://github.com/ystyle/tang.git", tag = "v1.0.0" }
> # 国内可以使用 gitcode
> tang = { git = "https://gitcode.com/ystyle/tang.git", tag = "v1.0.0" }
> ```

## 📝 第二步：编写 Hello World

创建 `src/main.cj` 文件：

```cj
import tang.*

main() {
    // 创建 Tang 应用实例
    let app = Tang()

    // 注册第一个路由
    app.get("/", { ctx =>
        ctx.writeString("Hello, Tang! 🚀")
    })

    // 启动应用（自动打印 Banner 和路由）
    app.listen(8080u16)
}
```

运行应用：

```bash
cjpm run
```

打开浏览器访问 `http://localhost:8080`，你将看到：

```
Hello, Tang! 🚀
```

> **💡 提示：Tang 应用结构**
>
> 1. **Tang** - 应用类，封装了 Router 和 Server，提供更简洁的 API
> 2. **Handler** - 处理函数，接收 `TangHttpContext` 参数并返回响应
> 3. **自动打印** - 启动时自动显示 Banner 和已注册的路由列表

## 🛣️ 第三步：添加更多路由

让我们添加更多路由来构建一个简单的 API：

```cj
import tang.*
import std.collection.HashMap
import std.collection.ArrayList

main() {
    let app = Tang()

    // 首页
    app.get("/", { ctx =>
        ctx.writeString("Welcome to Tang API! 🎉")
    })

    // 用户列表
    app.get("/api/users", { ctx =>
        let users = ArrayList<HashMap<String, String>>()
        users.add(HashMap<String, String>([
            ("id", "1"),
            ("name", "Alice"),
            ("email", "alice@example.com")
        ]))
        users.add(HashMap<String, String>([
            ("id", "2"),
            ("name", "Bob"),
            ("email", "bob@example.com")
        ]))

        ctx.json(users)
    })

    // 获取单个用户（路径参数）
    app.get("/api/users/:id", { ctx =>
        let id = ctx.param("id")  // 获取路径参数
        ctx.json(HashMap<String, String>([
            ("name", "User ${id}"),
            ("email", "user${id}@example.com"),
            ("id", id)
        ]))
    })

    // 创建用户（POST 请求）
    app.post("/api/users", { ctx =>
        // 解析 JSON 请求体
        let body = ctx.bindJson<HashMap<String, String>>()
        match (body) {
            case Some(data) =>
                ctx.status(201)
                    .json(HashMap<String, String>([
                        ("message", "User created"),
                        ("name", data.getOrDefault("name", "Unknown"))
                    ]))
            case None =>
                ctx.status(400).json(HashMap<String, String>([
                    ("error", "Invalid JSON")
                ]))
        }
    })

    // 健康检查
    app.get("/health", { ctx =>
        ctx.json(HashMap<String, String>([
            ("status", "ok"),
            ("framework", "Tang")
        ]))
    })

    app.listen(8080u16)
}
```

测试这些端点：

```bash
# 获取用户列表
curl http://localhost:8080/api/users

# 获取单个用户
curl http://localhost:8080/api/users/123

# 创建用户
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Charlie","email":"charlie@example.com"}'

# 健康检查
curl http://localhost:8080/health
```

> **💡 提示：路径参数 vs 查询参数**
>
> - **路径参数**：`/users/:id` → 通过 `ctx.param("id")` 获取
> - **查询参数**：`/users?page=1` → 通过 `ctx.query("page")` 获取
>
> 路径参数用于资源定位，查询参数用于过滤和排序

## 🔌 第四步：使用中间件

中间件让你可以预处理请求和后处理响应。让我们添加日志和 CORS 中间件：

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import std.collection.HashMap

main() {
    let app = Tang()

    // 全局中间件（应用于所有路由）
    app.use(logger())      // 请求日志
    app.use(cors())        // CORS 支持

    // 你的路由
    app.get("/", { ctx =>
        ctx.writeString("Hello with middleware! 🎊")
    })

    app.listen()
}

// 自定义认证中间件
func authMiddleware(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let token = ctx.request.headers.getFirst("Authorization")

            match (token) {
                case Some(t) =>
                    if (t.startsWith("Bearer ")) {
                        next(ctx)  // 验证通过，继续处理
                    } else {
                        ctx.status(401)
                            .json(HashMap<String, String>([
                                ("error", "Invalid token format")
                            ]))
                    }
                case None =>
                    ctx.status(401)
                        .json(HashMap<String, String>([
                            ("error", "Missing token")
                        ]))
            }
        }
    }
}
```

> **💡 提示：中间件执行顺序**
>
> 中间件按照注册顺序执行（洋葱模型）：
>
> ```
> 请求 → Logger → CORS → Auth → Handler
> 响应 ← Logger ← CORS ← Auth ← Handler
> ```
>
> 每个中间件可以在调用 `next()` 前后处理请求/响应

## 📦 第五步：使用路由组

路由组让你可以组织路由并共享中间件：

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import std.collection.HashMap

main() {
    let app = Tang()

    // API v1 路由组
    let apiV1 = app.group("/api/v1")

    // 组级别的中间件
    apiV1.use(logger())
    apiV1.use(cors())

    // 用户路由
    apiV1.get("/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "v1"),
            ("resource", "users")
        ]))
    })

    apiV1.get("/users/:id", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("version", "v1"),
            ("userId", id)
        ]))
    })

    // API v2 路由组（不同的中间件）
    let apiV2 = app.group("/api/v2")
    apiV2.use(logger())

    apiV2.get("/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("resource", "users")
        ]))
    })

    app.listen()
}
```

测试路由组：

```bash
curl http://localhost:8080/api/v1/users
# {"version":"v1","resource":"users"}

curl http://localhost:8080/api/v2/users
# {"version":"v2","resource":"users"}
```

## 🎯 完整示例：简单的 REST API

让我们把所有知识整合起来，创建一个待办事项 API：

```cj
import tang.*
import tang.middleware.log.logger
import tang.middleware.cors.cors
import std.collection.HashMap
import std.collection.ArrayList

main() {
    let app = Tang()

    // 全局中间件
    app.use(logger())
    app.use(cors())

    // 内存存储（生产环境应使用数据库）
    var todos = ArrayList<HashMap<String, String>>()
    var nextId = 1

    // 获取所有待办事项
    app.get("/api/todos", { ctx =>
        ctx.json(todos)
    })

    // 获取单个待办事项
    app.get("/api/todos/:id", { ctx =>
        let id = ctx.param("id")

        // 查找待办事项
        for (todo in todos) {
            if (todo.getOrDefault("id", "") == id) {
                ctx.json(todo)
                return
            }
        }

        ctx.status(404).json(HashMap<String, String>([
            ("error", "Todo not found")
        ]))
    })

    // 创建待办事项
    app.post("/api/todos", { ctx =>
        let body = ctx.bindJson<HashMap<String, String>>()

        match (body) {
            case Some(data) =>
                let title = data.getOrDefault("title", "")

                if (title.size == 0) {
                    ctx.status(400).json(HashMap<String, String>([
                        ("error", "Title is required")
                    ]))
                    return
                }

                let todo = HashMap<String, String>([
                    ("id", "${nextId}"),
                    ("completed", "false"),
                    ("title", title)
                ])
                todos.add(todo)
                nextId += 1

                ctx.status(201).json(todo)
            case None =>
                ctx.status(400).json(HashMap<String, String>([
                    ("error", "Invalid JSON")
                ]))
        }
    })

    // 更新待办事项
    app.put("/api/todos/:id", { ctx =>
        let id = ctx.param("id")
        let body = ctx.bindJson<HashMap<String, String>>()

        match (body) {
            case Some(data) =>
                // 查找并更新
                for (i in 0..todos.size) {
                    if (todos[i].getOrDefault("id", "") == id) {
                        let title = data.getOrDefault("title", todos[i].getOrDefault("title", ""))
                        let completed = data.getOrDefault("completed", todos[i].getOrDefault("completed", "false"))

                        todos[i] = HashMap<String, String>([
                            ("id", id),
                            ("title", title),
                            ("completed", completed)
                        ])

                        ctx.json(todos[i])
                        return
                    }
                }

                ctx.status(404).json(HashMap<String, String>([
                    ("error", "Todo not found")
                ]))
            case None =>
                ctx.status(400).json(HashMap<String, String>([
                    ("error", "Invalid JSON")
                ]))
        }
    })

    // 删除待办事项
    app.delete("/api/todos/:id", { ctx =>
        let id = ctx.param("id")

        for (i in 0..todos.size) {
            if (todos[i].getOrDefault("id", "") == id) {
                todos.remove(i)
                ctx.status(204).body("")
                return
            }
        }

        ctx.status(404).json(HashMap<String, String>([
            ("error", "Todo not found")
        ]))
    })

    app.listen(8080u16)
}
```

测试完整的 CRUD API：

```bash
# 创建待办事项
curl -X POST http://localhost:8080/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Tang"}'

# 获取所有待办事项
curl http://localhost:8080/api/todos

# 获取单个待办事项
curl http://localhost:8080/api/todos/1

# 更新待办事项
curl -X PUT http://localhost:8080/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Tang Framework","completed":"true"}'

# 删除待办事项
curl -X DELETE http://localhost:8080/api/todos/1
```

## 🎉 恭喜！

你已经学会了：

✅ 创建基本的 Tang 应用
✅ 注册路由和处理请求
✅ 使用路径参数和查询参数
✅ 解析 JSON 请求体
✅ 返回 JSON 响应
✅ 使用中间件
✅ 组织路由组
✅ 构建 REST API

## 📚 下一步

继续探索：

- **[Router API](api/router.md)** - 深入了解路由系统
- **[中间件文档](middleware/overview.md)** - 23+ 内置中间件
- **[构建 REST API](tutorial/building-rest-api.md)** - REST API 最佳实践
- **[示例集合](../examples/middleware_showcase/)** - 完整的中间件演示

## 🆘 遇到问题？

- 查看 [API 文档](api/)
- 阅读 [常见问题](#)
- 在 [GitHub Issues](https://github.com/ystyle/tang/issues) 提问

---

**祝你使用 Tang 愉快！** 🚀
