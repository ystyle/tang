# Rewrite - URL 重写

## 概述

- **功能**：在路由匹配前重写请求 URL 路径
- **分类**：路由处理
- **文件**：`src/middleware/rewrite/rewrite.cj`

Rewrite 中间件用于在路由匹配之前重写 URL 路径，实现 URL 迁移、版本控制、路径规范化等功能。

> **💡 提示：重写 vs 重定向**
>
> **URL 重写（Rewrite）**：
> - 服务器端修改 URL 路径
> - 浏览器地址栏不变
> - 对用户透明
>
> **URL 重定向（Redirect）**：
> - 告诉浏览器访问新的 URL
> - 浏览器地址栏改变
> - 用户感知到 URL 变化
>
> **使用场景**：
> - API 版本迁移：使用 Rewrite
> - 域名迁移：使用 Redirect

## 签名

```cj
public func rewrite(pattern: String, replacement: String): MiddlewareFunc

// Router 层面（推荐）
public func addRewriteRule(rule: (String) -> String): Unit
```

## 快速开始

### Router 层面重写（推荐）

```cj
import tang.middleware.rewrite.createRewriteFunction

let r = Router()

// 添加重写规则：/api/v1/* → /api/v2/*
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))

// 注册路由（匹配重写后的路径）
r.get("/api/v2/users", { ctx =>
    // 请求 /api/v1/users 会被重写为 /api/v2/users
    ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("data", "users")
        ]))
})
```

**请求流程**：
```
客户端请求：GET /api/v1/users
          ↓
    [重写规则]
          ↓
路由匹配：GET /api/v2/users  ← 实际匹配的路径
          ↓
    [执行处理器]
```

### 中间件方式（路由组）

```cj
import tang.middleware.rewrite.rewrite

let apiV2 = r.group("/api/v2")

// 应用重写中间件
apiV2.use(rewrite("/api/v1/(.*)", "/api/v2/$1"))

apiV2.get("/users", { ctx =>
    // 实际路径是 /api/v2/users
    ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("users", "[]")
        ]))
})
```

## 完整示例

### 示例 1：API 版本迁移

```cj
import tang.*
import tang.middleware.rewrite.createRewriteFunction
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 重写规则：v1 API → v2 API
    r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))

    // v2 API 路由
    r.get("/api/v2/users", { ctx =>
        // 请求 /api/v1/users 会被重写为 /api/v2/users
        ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("data", "users list")
        ]))
    })

    r.post("/api/v2/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("message", "User created")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**测试**：
```bash
# 旧版本 API 仍然可用（自动重写到新版本）
curl http://localhost:8080/api/v1/users
# 返回：{"version":"v2","data":"users list"}

curl http://localhost:8080/api/v2/users
# 返回：{"version":"v2","data":"users list"}
```

### 示例 2：移除 URL 前缀

```cj
import tang.middleware.rewrite.createRewriteFunction

let r = Router()

// 移除 /api/v1 前缀
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/$1"))

// 注册路由（不需要前缀）
r.get("/users", { ctx =>
    // 请求 /api/v1/users 会被重写为 /users
    ctx.json(ArrayList<String>())
})

r.post("/users", { ctx =>
    ctx.status(201).json(HashMap<String, String>([
            ("message", "Created")
        ]))
})
```

**映射关系**：
```
客户端请求：/api/v1/users
        ↓
    [重写]
        ↓
实际路由：/users
```

### 示例 3：多个重写规则

```cj
import tang.middleware.rewrite.createRewriteFunction

let r = Router()

// 规则 1：old/* → new/*
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))

// 规则 2：/api/v1/* → /api/v2/*
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))

// 规则 3：/blog/* → /posts/*
r.addRewriteRule(createRewriteFunction("/blog/(.*)", "/posts/$1"))

// 注册路由
r.get("/new/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Old path redirected to new")
        ]))
})

r.get("/api/v2/users", { ctx =>
    ctx.json(HashMap<String, String>([
            ("version", "v2")
        ]))
})

r.get("/posts/latest", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Blog renamed to Posts")
        ]))
})
```

### 示例 4：路径规范化

```cj
import tang.middleware.rewrite.createRewriteFunction

let r = Router()

// 移除尾部斜杠
r.addRewriteRule(createRewriteFunction("(.+)/$", "$1"))

// 强制添加尾部斜杠
r.addRewriteRule(createRewriteFunction("^([^/]+)$", "$1/"))

// 统一小写
r.addRewriteRule({ path =>
    // 将路径转为小写
    if (path.contains("/api/")) {
        path.toLower()
    } else {
        path
    }
})
```

### 示例 5：条件重写

```cj
func conditionalRewrite(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            let path = ctx.path()

            // 只在特定条件下重写
            if (path.startsWith("/old/")) {
                // 重写路径
                let newPath = path.replace("/old/", "/new/")
                ctx.kvSet("rewritten_path", newPath)
            }

            next(ctx)
        }
    }
}

let r = Router()
r.use(conditionalRewrite())

r.get("/new/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Rewritten successfully")
        ]))
})
```

## 正则表达式语法

### 基本语法

```cj
// .* 匹配任意字符（除换行外）
createRewriteFunction("/api/(.*)", "/v2/$1")
// /api/users → /v2/users
// /api/posts/123 → /v2/posts/123

// (.*) 捕获组
createRewriteFunction("/users/(.*)/posts/(.*)", "/posts/$1/comments/$2")
// /users/123/posts/456 → /posts/123/comments/456

// ^ 开始锚点
createRewriteFunction("^/api/(.*)", "/$1")
// /api/users → /users（只匹配开头的 /api）

// $ 结束锚点
createRewriteFunction("/users/([^/]+)$", "/profile/$1")
// /users/john → /profile/john
// /users/john/posts → 不匹配（以 /posts 结尾）
```

### 捕获组引用

```cj
// $1, $2, $3... 引用捕获组
createRewriteFunction("/api/(v[0-9]+)/(.*)", "/$2")
// /api/v1/users → /users（移除版本号）

createRewriteFunction("/(.*)/(.*)/(.*)", "/$3/$2")
// /a/b/c → /c/b（反转路径）
```

## 工作原理

### Router 层面重写（推荐）

```cj
// Router 的 lookup() 方法
public func lookup(ctx: HttpContext): (HandlerFunc, Params) {
    var path = ctx.request.url.rawPath

    // 1. 应用路径重写规则（在路由匹配之前）
    for (rule in this.rewriteRules) {
        let newPath = rule(path)
        if (newPath != path) {
            path = newPath
            break  // 只应用第一个匹配的规则
        }
    }

    // 2. 使用重写后的路径进行路由匹配
    let (node, params) = this.tree.searchRoute(method, path)
    // ...
}
```

### 中间件方式重写

```cj
// 中间件方式（仅限特定路由组）
public func rewrite(pattern: String, replacement: String): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 这里可以修改路径，但不会影响路由匹配结果
            // 因为路由匹配已经在 Router.lookup() 中完成
            next(ctx)
        }
    }
}
```

> **💡 提示：为什么推荐 Router 层面重写？**
>
> **Tang 的路由流程**：
> ```
> 1. Router.lookup(ctx)
>    ├── 应用重写规则（在路由匹配之前）
>    ├── Radix Tree 搜索
>    └── 找到匹配的 Handler
>
> 2. 执行中间件和 Handler
> ```
>
> **Router 层面重写**（推荐）：
> - ✅ 在路由匹配**之前**执行
> - ✅ 真正改变路由匹配结果
> - ✅ 支持正则捕获组替换
>
> **中间件方式重写**（限制）：
> - ❌ 在路由匹配**之后**执行
> - ❌ 不影响已完成的路由匹配
> - ❌ 仅用于特定路由组
>
> **结论**：使用 `r.addRewriteRule()` 进行路径重写

## 注意事项

### 1. 重写规则顺序

重写规则按照添加顺序依次匹配，只应用第一个匹配的规则：

```cj
// ✅ 正确：从具体到通用
r.addRewriteRule(createRewriteFunction("/api/v1/users/(.*)", "/api/v2/users/$1"))
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))

// ❌ 错误：通用规则会先匹配
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))  // 会先匹配
r.addRewriteRule(createRewriteFunction("/api/v1/users/(.*)", "/api/v2/users/$1"))  // 永远不会执行
```

### 2. 循环重写

避免重写规则产生循环：

```cj
// ❌ 错误：产生循环
r.addRewriteRule(createRewriteFunction("/a/(.*)", "/b/$1"))
r.addRewriteRule(createRewriteFunction("/b/(.*)", "/a/$1"))
// /a/x → /b/x → /a/x → /b/x ... 无限循环

// ✅ 正确：避免循环
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))
// 只将 /old 重写到 /new，不再反向重写
```

### 3. 参数查询字符串

当前实现只重写路径部分，不包含查询字符串：

```cj
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))

// 请求：/old/data?foo=bar
// 重写：/new/data?foo=bar  （查询字符串保持不变）
```

### 4. 与 Redirect 配合

如果需要永久迁移 URL，应该使用 Redirect 而非 Rewrite：

```cj
// Rewrite：服务器端重写，地址栏不变
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))

// Redirect：客户端重定向，地址栏改变
r.get("/old/*", { ctx =>
    let path = ctx.param("*")  // 获取通配符匹配的部分
    ctx.redirect("/new/${path}")
})
```

**选择指南**：
- **临时迁移**：使用 Rewrite
- **永久迁移**：使用 Redirect（SEO 友好）

## 测试

### 测试路径重写

```bash
# 重写规则：/api/v1/* → /api/v2/*
curl http://localhost:8080/api/v1/users
# 返回：{"version":"v2"}  （证明被重写到 /api/v2/users）
```

### 测试捕获组

```bash
# 重写规则：/users/([^/]+)/profile → /profile/$1
curl http://localhost:8080/users/john/profile
# 返回：{"username":"john"}
```

## 相关链接

- **[Redirect 中间件](redirect.md)** - URL 重定向
- **[Proxy 中间件](proxy.md)** - 反向代理
- **[Router API](../../api/router.md)** - Router 类文档
- **[源码](../../../src/middleware/rewrite/rewrite.cj)** - Rewrite 源代码
