# ETag - HTTP 缓存验证

> **本分支变更**：该中间件已移到扩展成员 `tang_ext_crypto` 以保持核心零 stdx。
> import 从 `tang.middleware.etag.*` 改为 `tang_ext_crypto.etag.*`，
> 并需要在 `cjpm.toml` 里加 `tang_ext_crypto` 依赖（含 `CANGJIE_STDX_PATH` 环境）。
> 详见 [迁移指南](../../MIGRATION.md)。

## 概述

- **功能**：生成 ETag 响应头，支持 HTTP 缓存验证（304 Not Modified）
- **分类**：缓存与优化
- **文件**：`src/middleware/etag/etag.cj`

ETag 中间件自动为响应生成 ETag 响应头，实现 HTTP 缓存验证机制。浏览器可以使用 ETag 判断资源是否已修改，避免重复下载相同内容。

> **💡 提示：ETag vs Last-Modified**
>
> **ETag（推荐）**：
> - 基于内容哈希值（指纹）
> - 更精确地判断内容变化
> - 不受时钟同步问题影响
>
> **Last-Modified**：
> - 基于文件修改时间
> - 只能精确到秒级
> - 可能受时钟偏差影响
>
> **建议**：优先使用 ETag，可以与 Cache-Control 配合使用

## 签名

```cj
public func etag(): MiddlewareFunc
public func etag(opts: Array<ETagOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withSHA256()` | - | `SHA256` | 使用 SHA256 哈希算法（默认，更安全） |
| `withMD5()` | - | - | 使用 MD5 哈希算法（更快，安全性较低） |
| `withWeak()` | - | - | 使用弱 ETag（W/ 前缀） |
| `withExcludePath()` | `String` | - | 添加排除的路径（不生成 ETag） |
| `withExcludePaths()` | `Array<String>` | - | 批量添加排除路径 |

## 快速开始

### 基础用法

```cj
import tang.middleware.etag.etag

let r = Router()

// 应用 ETag 中间件
r.use(etag())

r.get("/api/data", { ctx =>
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**响应头**：
```http
ETag: "5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8"
```

### 带配置的用法

```cj
import tang.middleware.etag.{etag, withMD5, withExcludePaths}

let r = Router()

// 使用 MD5（更快）并排除某些路径
r.use(etag([
    withMD5(),  // 使用 MD5 算法
    withExcludePaths([
        "/api/dynamic/",  // 动态内容不生成 ETag
        "/upload/"
    ])
]))
```

### 使用弱 ETag

```cj
import tang.middleware.etag.{etag, withWeak}

r.use(etag([
    withWeak()  // 使用弱 ETag（W/ 前缀）
]))
```

**响应头**：
```http
ETag: W/"5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c"
```

## 完整示例

### 示例 1：静态资源缓存

```cj
import tang.*
import tang.middleware.etag.etag
import tang.middleware.cache.cache
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // 先应用 ETag，再应用 Cache
    r.use(etag())
    r.use(cache())

    // 静态数据：生成 ETag + 缓存
    r.get("/api/config", { ctx =>
        ctx.json(HashMap<String, String>([
            ("version", "1.0.0"),
            ("environment", "production"),
            ("features", "cache,etag,session")
        ]))
    })

    // 用户数据：生成 ETag
    r.get("/api/users/:id", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("username", "testuser"),
            ("email", "test@example.com")
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
# 第一次请求：返回完整数据和 ETag
curl -I http://localhost:8080/api/config
# ETag: "abc123..."

# 第二次请求：发送 If-None-Match
curl -I -H "If-None-Match: \"abc123...\"" http://localhost:8080/api/config
# HTTP/1.1 304 Not Modified（节省带宽）
```

### 示例 2：排除动态内容

```cj
import tang.middleware.etag.{etag, withExcludePath}

let r = Router()

r.use(etag([
    withExcludePath("/api/now/"),      // 实时时间戳
    withExcludePath("/api/dynamic/")   // 动态内容
]))

// 静态内容：生成 ETag
r.get("/api/config", { ctx =>
    ctx.json(HashMap<String, String>([
            ("version", "1.0.0")
        ]))
})

// 动态内容：不生成 ETag
r.get("/api/now/timestamp", { ctx =>
    ctx.json(HashMap<String, String>([
            ("timestamp", "${DateTime.now()}")
        ]))
})
```

### 示例 3：自定义 ETag 生成（业务层）

```cj
import stdx.crypto.digest.SHA256
import stdx.encoding.hex.toHexString

// 自定义 ETag 生成函数
func generateContentETag(content: String): String {
    let bytes = content.toArray()
    let sha256 = SHA256()
    sha256.write(bytes)
    let hash = sha256.finish()
    let hashString = toHexString(hash)
    return "\"${hashString}\""
}

let r = Router()

r.get("/api/data", { ctx =>
    let data = HashMap<String, String>([
            ("id", "123"),
            ("name", "Test")
        ])}"
    )

    // 生成基于内容的 ETag
    let etagValue = generateContentETag(data.toJSON())
    ctx.responseBuilder.header("ETag", etagValue)

    // 检查 If-None-Match
    let ifNoneMatch = ctx.request.headers.getFirst("If-None-Match")
    match (ifNoneMatch) {
        case Some(matchTag) =>
            if (matchTag == etagValue) {
                // 内容未修改，返回 304
                ctx.responseBuilder.status(304u16).send()
                return
            }
        case None => ()
    }

    // 内容已修改或首次请求，返回完整数据
    ctx.json(data)
})
```

### 示例 4：条件请求（Conditional Request）

```cj
let r = Router()

r.get("/api/users/:id", { ctx =>
    let id = ctx.param("id")
    let user = getUserFromDB(id)

    if (user == None) {
        ctx.jsonWithCode(404u16, HashMap<String, String>([
            ("error", "User not found")
        ]))
        return
    }

    let userData = user.getOrThrow()
    let content = userData.toJSON()

    // 生成 ETag
    let etagValue = generateETag(content)
    ctx.responseBuilder.header("ETag", etagValue)

    // 检查客户端缓存
    let ifNoneMatch = ctx.request.headers.getFirst("If-None-Match")
    match (ifNoneMatch) {
        case Some(matchTag) =>
            if (matchTag == etagValue) {
                // ETag 匹配，返回 304
                ctx.status(304u16).send()
                return
            }
        case None => ()
    }

    // ETag 不匹配或首次请求，返回数据
    ctx.json(userData)
})
```

### 示例 5：不同资源使用不同算法

```cj
import tang.middleware.etag.{etag, withSHA256, withMD5, withWeak}

let r = Router()

// 静态资源：使用 MD5（更快）
let staticRoutes = r.group("/static")
staticRoutes.use(etag([withMD5()]))

staticRoutes.get("/css/main.css", { ctx =>
    ctx.responseBuilder
        .contentType("text/css")
        .body("body { margin: 0; }")
})

// API 响应：使用 SHA256（更安全）
let apiRoutes = r.group("/api")
apiRoutes.use(etag([withSHA256()]))

apiRoutes.get("/users", { ctx =>
    ctx.json(ArrayList<String>())
})

// 动态内容：使用弱 ETag
let dynamicRoutes = r.group("/dynamic")
dynamicRoutes.use(etag([withWeak()]))

dynamicRoutes.get("/news", { ctx =>
    ctx.json(HashMap<String, String>([
            ("latest", "News content")
        ]))
})
```

## 工作原理

### ETag 生成流程

```
1. 客户端请求资源
   ↓
2. 服务器生成 ETag（基于内容哈希）
   ↓
3. 返回响应（包含 ETag 头）
   ETag: "5a3e7b4c3d9f..."
   ↓
4. 客户端缓存资源 + ETag
   ↓
5. 客户端再次请求相同资源
   If-None-Match: "5a3e7b4c3d9f..."
   ↓
6. 服务器检查 ETag 是否匹配
   ↓
7. 如果匹配：返回 304 Not Modified（不传输内容）
   如果不匹配：返回 200 OK + 新内容 + 新 ETag
```

### ETag 类型

#### 强 ETag（Strong ETag）

```http
ETag: "5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c"
```

- **特点**：字节级别的精确匹配
- **用途**：静态资源、精确缓存
- **验证**：内容完全相同（包括空格、换行等）

#### 弱 ETag（Weak ETag）

```http
ETag: W/"5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c"
```

- **特点**：语义级别匹配（W/ 前缀）
- **用途**：动态内容、HTML 页面
- **验证**：语义相同但字节可能不同

> **💡 提示：何时使用弱 ETag？**
>
> **场景 1：动态生成的内容**
> - 同一用户的不同请求可能生成字节不同的 HTML
> - 但语义相同（都包含用户数据）
>
> **场景 2：服务器负载均衡**
> - 不同服务器可能生成格式略有不同的响应
> - 但内容实质相同
>
> **场景 3：允许微小差异**
> - 时间戳、版本号等次要信息变化
> - 但主要数据未改变

## 测试

### 测试 ETag 生成

```bash
# 第一次请求：获取完整数据 + ETag
curl -i http://localhost:8080/api/config

# 响应：
# HTTP/1.1 200 OK
# ETag: "abc123..."
# Content-Type: application/json
# {"version":"1.0.0"}
```

### 测试条件请求（304 Not Modified）

```bash
# 使用 If-None-Match 发送条件请求
curl -i \
  -H "If-None-Match: \"abc123...\"" \
  http://localhost:8080/api/config

# 响应（如果 ETag 匹配）：
# HTTP/1.1 304 Not Modified
# ETag: "abc123..."
# (无响应体)
```

### 测试 ETag 不匹配

```bash
# 使用错误的 ETag
curl -i \
  -H "If-None-Match: \"wrong-etag\"" \
  http://localhost:8080/api/config

# 响应（ETag 不匹配）：
# HTTP/1.1 200 OK
# ETag: "abc123..."
# {"version":"1.0.0"}
```

## 算法选择

### SHA256（默认）

```cj
r.use(etag([withSHA256()]))
```

**优点**：
- ✅ 更安全（抗碰撞性强）
- ✅ 哈希值长度固定（64 字符）
- ✅ 适用于安全性要求高的场景

**缺点**：
- ❌ 计算速度相对较慢
- ❌ 生成的 ETag 较长

**适用场景**：
- API 响应
- 敏感数据
- 需要高安全性的场景

### MD5

```cj
r.use(etag([withMD5()]))
```

**优点**：
- ✅ 计算速度快
- ✅ 生成的 ETag 较短（32 字符）
- ✅ 广泛支持

**缺点**：
- ❌ 安全性较低（可能存在碰撞）
- ❌ 不适合安全敏感场景

**适用场景**：
- 静态资源（CSS、JS、图片）
- 高流量场景
- 非敏感数据

## 性能优化

### 1. 排除高动态路径

```cj
r.use(etag([
    withExcludePath("/api/realtime/"),   // 实时数据
    withExcludePath("/api/stream/"),      // 流式数据
    withExcludePath("/upload/")           // 上传文件
]))
```

**原因**：高动态内容的 ETag 每次都不同，生成和验证没有意义。

### 2. 合理选择算法

```cj
// 静态资源：MD5（快）
let staticRoutes = r.group("/static")
staticRoutes.use(etag([withMD5()]))

// API 响应：SHA256（安全）
let apiRoutes = r.group("/api")
apiRoutes.use(etag([withSHA256()]))
```

### 3. 配合 Cache-Control

```cj
r.use(etag())
r.use(cache([withConfig("public, max-age=3600")]))
```

**效果**：
- 首次请求：返回 200 + ETag + Cache-Control
- 有效期内：浏览器使用缓存（不发送请求）
- 过期后：发送条件请求（If-None-Match）
- ETag 匹配：返回 304（节省带宽）

## 注意事项

### 1. 当前实现的限制

当前 ETag 中间件基于路径和查询参数生成简单 ETag：

```cj
// 当前实现
let path = ctx.path()
let query = ctx.request.url.query
let content = "${path}?${query}".toArray()
let etagValue = config.generateETag(content)
```

**限制**：
- ❌ 不基于响应体内容
- ❌ 路径相同但内容不同的资源会生成相同的 ETag

**解决方案**：业务层手动生成

```cj
r.get("/api/users/:id", { ctx =>
    let user = getUserFromDB(ctx.param("id"))
    let content = user.toJSON()

    // 基于内容生成 ETag
    let etagValue = generateContentETag(content)
    ctx.responseBuilder.header("ETag", etagValue)

    // 检查 If-None-Match
    let ifNoneMatch = ctx.request.headers.getFirst("If-None-Match")
    match (ifNoneMatch) {
        case Some(matchTag) =>
            if (matchTag == etagValue) {
                ctx.status(304u16).send()
                return
            }
        case None => ()
    }

    ctx.json(user)
})
```

### 2. POST/PUT/DELETE 请求

通常不需要为状态变更操作生成 ETag：

```cj
// ❌ 不推荐：POST 生成 ETag
r.post("/api/users", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "User created")
        ]))
})

// ✅ 推荐：只对 GET 生成 ETag
func selectiveETag(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (ctx.method() == "GET") {
                // 对 GET 请求生成 ETag
                let etagValue = generateETag(ctx.path())
                ctx.responseBuilder.header("ETag", etagValue)
            }

            next(ctx)
        }
    }
}
```

### 3. 与其他缓存头配合

```cj
// ✅ 完整的缓存策略
r.use(etag())
r.use(cache([withConfig("public, max-age=3600")]))

// 响应头：
# ETag: "abc123..."
# Cache-Control: public, max-age=3600
# Last-Modified: Wed, 01 Jan 2025 00:00:00 GMT
```

**优先级**：
1. 浏览器先检查 Cache-Control（是否过期）
2. 如果过期，发送条件请求（If-None-Match / If-Modified-Since）
3. 服务器检查 ETag / Last-Modified
4. 返回 304 或 200

### 4. ETag 长度

ETag 越长，请求头越大：

```cj
// SHA256：64 字符（较长）
"5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8"

// MD5：32 字符（较短）
"5a3e7b4c3d9f2e1a8b6c7d8e9f0a1b2c"
```

**建议**：
- 高流量场景：使用 MD5
- 安全敏感场景：使用 SHA256

## 常见问题

### 问题 1：ETag 不匹配（总是返回 200）

**原因**：ETag 每次都不同

**排查**：
```cj
// 检查 ETag 是否稳定
r.get("/api/test", { ctx =>
    let content = "static content"
    let etag1 = generateETag(content)
    let etag2 = generateETag(content)

    println("ETag 1: ${etag1}")
    println("ETag 2: ${etag2}")
    // 应该相同

    ctx.json(HashMap<String, String>([
            ("data", content)
        ]))
})
```

**解决**：
- 确保生成 ETag 的内容是稳定的
- 避免包含时间戳、随机数等变化数据

### 问题 2：浏览器总是发送完整请求

**原因**：Cache-Control 配置不正确

**解决**：
```cj
r.use(cache([withConfig("public, max-age=3600")]))
r.use(etag())
```

确保 Cache-Control 的 max-age 足够长，浏览器会在有效期内使用缓存。

### 问题 3：动态内容不应该是 304

**场景**：每次请求都生成新的内容（时间戳、随机数）

**解决**：排除这些路径

```cj
r.use(etag([
    withExcludePath("/api/now/"),
    withExcludePath("/api/random/")
]))
```

## 相关链接

- **[Cache 中间件](cache.md)** - 缓存控制
- **[源码](../../../src/middleware/etag/etag.cj)** - ETag 源代码
