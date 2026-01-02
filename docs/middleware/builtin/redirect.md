# Redirect - URL 重定向

## 概述

- **功能**：URL 重定向（301 永久重定向、302 临时重定向）
- **分类**：路由与请求控制
- **文件**：`src/middleware/redirect/redirect.cj`

Redirect 中间件提供 URL 重定向功能，支持将旧路径重定向到新路径。

> **💡 提示：Redirect vs Rewrite**
>
> **URL 重定向（Redirect）**：
> - 服务器告诉浏览器访问新的 URL
> - 浏览器地址栏改变
> - 用户感知到 URL 变化
> - 返回 3xx 状态码 + Location 头
>
> **URL 重写（Rewrite）**：
> - 服务器端修改 URL 路径
> - 浏览器地址栏不变
> - 对用户透明
> - 路由匹配时修改路径
>
> **选择建议**：
> - **永久迁移**：使用 Redirect（301）
> - **临时路径变更**：使用 Rewrite
> - **API 版本迁移**：使用 Rewrite（对客户端透明）
> - **域名迁移**：使用 Redirect（SEO 友好）

## 签名

### 重定向处理器

```cj
public func redirect(url: String, statusCode: UInt16 = 302): HandlerFunc
```

### 重定向中间件

```cj
public func redirectMiddleware(
    fromPath: String,
    toPath: String,
    statusCode: UInt16 = 302
): MiddlewareFunc
```

## HTTP 状态码

| 状态码 | 名称 | 用途 |
|--------|------|------|
| `301` | Moved Permanently | 永久重定向（SEO 友好） |
| `302` | Found | 临时重定向（默认） |
| `303` | See Other | POST 请求后重定向到 GET |
| `307` | Temporary Redirect | 临时重定向（保持请求方法） |
| `308` | Permanent Redirect | 永久重定向（保持请求方法） |

## 快速开始

### 方式 1：重定向处理器

```cj
import tang.middleware.redirect.redirect

let r = Router()

// 将 /old-path 重定向到 /new-path
r.get("/old-path", redirect(
    url: "/new-path",
    statusCode: 301u16  // 永久重定向
))

r.get("/new-path", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "New path")
        ]))
})
```

**请求流程**：
```bash
curl -i http://localhost:8080/old-path

# 响应：
# HTTP/1.1 301 Moved Permanently
# Location: /new-path
```

### 方式 2：重定向中间件

```cj
import tang.middleware.redirect.redirectMiddleware

let r = Router()

// 重定向 /old/* 到 /new/*
r.use(redirectMiddleware(
    fromPath: "/old",
    toPath: "/new",
    statusCode: 302u16
))

r.get("/new/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Data")
        ]))
})
```

**请求流程**：
```bash
curl -i http://localhost:8080/old/data

# 响应：
# HTTP/1.1 302 Found
# Location: /new/data
```

## 完整示例

### 示例 1：API 版本迁移（永久重定向）

```cj
import tang.*
import tang.middleware.redirect.redirect
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 旧 API v1 重定向到 v2
    r.get("/api/v1/users", redirect(
        url: "/api/v2/users",
        statusCode: 301u16  // 永久重定向
    ))

    r.get("/api/v1/products", redirect(
        url: "/api/v2/products",
        statusCode: 301u16
    ))

    // 新 API v2
    r.get("/api/v2/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("data", "users")
        ]))
    })

    r.get("/api/v2/products", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "v2"),
            ("data", "products")
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
curl -i http://localhost:8080/api/v1/users

# 响应：
# HTTP/1.1 301 Moved Permanently
# Location: /api/v2/users
```

### 示例 2：批量重定向

```cj
import tang.middleware.redirect.redirectMiddleware

let r = Router()

// 重定向所有 /blog/* 到 /posts/*
r.use(redirectMiddleware(
    fromPath: "/blog",
    toPath: "/posts",
    statusCode: 301u16
))

r.get("/posts/latest", { ctx =>
    ctx.json(HashMap<String, String>([
            ("title", "Latest Post")
        ]))
})

r.get("/posts/:id", { ctx =>
    let id = ctx.param("id")
    ctx.json(HashMap<String, String>([
            ("postId", id)
        ]))
})
```

**测试**：
```bash
# 请求 /blog/latest
curl -i http://localhost:8080/blog/latest

# 重定向到 /posts/latest
# HTTP/1.1 301 Moved Permanently
# Location: /posts/latest

# 请求 /blog/123
curl -i http://localhost:8080/blog/123

# 重定向到 /posts/123
# HTTP/1.1 301 Moved Permanently
# Location: /posts/123
```

### 示例 3：POST 后重定向（PRG 模式）

```cj
import tang.middleware.redirect.redirect

let r = Router()

// POST 请求：处理表单
r.post("/form/submit", { ctx =>
    // 处理表单数据
    let name = ctx.fromValue("name") ?? ""
    processForm(name)

    // 重定向到成功页面（PRG 模式）
    ctx.redirect("/form/success", 303u16)  // 303 See Other
})

// GET 请求：显示成功页面
r.get("/form/success", { ctx =>
    ctx.json(HashMap<String, String>([
            ("status", "success")
        ]))
})
```

**PRG 模式（Post/Redirect/Get）**：
```
1. 用户提交表单（POST /form/submit）
2. 服务器处理数据
3. 服务器返回 303 重定向到 GET /form/success
4. 浏览器自动访问 /form/success
5. 显示成功页面
```

**好处**：防止用户刷新浏览器导致重复提交

### 示例 4：条件重定向

```cj
import tang.middleware.redirect.redirect

let r = Router()

r.get("/download", { ctx =>
    let userAgent = ctx.request.headers.getFirst("User-Agent")

    // 移动设备重定向到移动页面
    match (userAgent) {
        case Some(ua) =>
            if (ua.contains("Mobile") || ua.contains("Android") || ua.contains("iPhone")) {
                ctx.redirect("/download/mobile", 302u16)
                return
            }
        case None => ()
    }

    // 桌面设备
    ctx.redirect("/download/desktop", 302u16)
})

r.get("/download/mobile", { ctx =>
    ctx.json(HashMap<String, String>([
            ("platform", "mobile")
        ]))
})

r.get("/download/desktop", { ctx =>
    ctx.json(HashMap<String, String>([
            ("platform", "desktop")
        ]))
})
```

### 示例 5：域名迁移

```cj
r.get("/*", { ctx =>
    let host = ctx.hostName()

    // 旧域名重定向到新域名
    if (host == "old-domain.com") {
        let newURL = "https://new-domain.com${ctx.path()}"
        ctx.redirect(newURL, 301u16)
        return
    }

    // 正常处理
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

## 重定向策略

### 1. 永久重定向（301）

```cj
r.get("/old-url", redirect(url: "/new-url", statusCode: 301u16))
```

**用途**：
- URL 永久变更
- SEO 迁移（搜索引擎会更新索引）
- 域名迁移

**浏览器行为**：缓存重定向，下次直接访问新 URL

### 2. 临时重定向（302）

```cj
r.get("/temp-url", redirect(url: "/new-url", statusCode: 302u16))
```

**用途**：
- 临时维护
- A/B 测试
- 临时功能迁移

**浏览器行为**：不缓存，每次都请求旧 URL

### 3. 保持请求方法（307/308）

```cj
// 307 Temporary Redirect（临时，保持方法）
r.post("/api/v1/data", redirect(url: "/api/v2/data", statusCode: 307u16))

// 308 Permanent Redirect（永久，保持方法）
r.post("/api/v1/create", redirect(url: "/api/v2/create", statusCode: 308u16))
```

**用途**：
- POST/PUT/DELETE 请求的重定向
- 确保重定向后请求方法不变

## 测试

### 测试重定向

```bash
# 使用 -L 跟随重定向
curl -L http://localhost:8080/old-path

# 使用 -i 查看响应头
curl -i http://localhost:8080/old-path

# 响应：
# HTTP/1.1 301 Moved Permanently
# Location: /new-path
```

### 测试 POST 重定向

```bash
# POST 请求重定向（307 保持方法）
curl -X POST -i -L \
  -H "Content-Type: application/json" \
  -d '{"name":"test"}' \
  http://localhost:8080/api/v1/data

# 响应：
# HTTP/1.1 307 Temporary Redirect
# Location: /api/v2/data
```

## 注意事项

### 1. 重定向循环

```cj
// ❌ 错误：重定向循环
r.get("/a", redirect(url: "/b"))
r.get("/b", redirect(url: "/a"))

// 浏览器会检测到循环并报错：
# ERR_TOO_MANY_REDIRECTS
```

### 2. POST 数据丢失

```cj
// ❌ 错误：302 重定向会丢失 POST 数据
r.post("/form", redirect(url: "/success", statusCode: 302u16))

// ✅ 正确：使用 303 或 307
r.post("/form", redirect(url: "/success", statusCode: 303u16))
```

**原因**：302 重定向浏览器会将 POST 转为 GET

### 3. 相对路径 vs 绝对路径

```cj
// 相对路径
r.get("/old", redirect(url: "new"))  // /old → /new

// 绝对路径
r.get("/old", redirect(url: "/new"))  // /old → /new

// 完整 URL
r.get("/old", redirect(url: "https://example.com/new"))
```

**建议**：使用绝对路径或完整 URL

## 相关链接

- **[Rewrite 中间件](rewrite.md)** - URL 重写
- **[源码](../../../src/middleware/redirect/redirect.cj)** - Redirect 源代码
