

> **本分支变更**：
> - `ctx.bindJson<T>()` 已移到适配器，改为 `tang_ext_json_seajson.bindJson<T>(ctx)`
> - `ctx.bindQuery<T>(v)` 改为基于 core 的 `QueryBindable` 接口（不再依赖 stdx.serialization）
>
> 详见 [迁移指南](../../MIGRATION.md)。

# 请求处理

## 概述

TangHttpContext 提供了丰富的方法来读取和解析 HTTP 请求数据。包括查询参数、路径参数、请求体、JSON、表单等多种数据格式的处理。

**主要功能**：
- **查询参数**：`query()`, `queries()`, `queryInt()`, `queryBool()`, `queryFloat()`
- **路径参数**：`param()`, `params()`, `route()`
- **请求体**：`bodyRaw()`, `bindJson<T>()`, `bindQuery<T>()`
- **表单处理**：`multipartForm()`, `fromValue()`, `fromFile()`
- **认证信息**：`basicAuth()`

## 查询参数 (Query Parameters)

### 获取单个查询参数

使用 `query()` 方法获取 URL 查询字符串中的参数：

```cj
r.get("/search", { ctx =>
    // 请求: /search?q=tang&limit=10
    let q = ctx.query("q")      // 返回 ?String "tang"
    let limit = ctx.query("limit")  // 返回 ?String "10"

    match (q) {
        case Some(keyword) =>
            ctx.json(HashMap<String, String>([
                ("query", keyword),
                ("limit", limit ?? "10")
            ]))
        case None =>
            ctx.json(HashMap<String, String>([
                ("error", "Missing query parameter")
            ]))
    }
})
```

### 类型化查询参数

Tang 提供了类型化的查询参数方法：

#### `queryInt()` - 整数参数

```cj
r.get("/users", { ctx =>
    // 请求: /users?page=2&per_page=20
    let page = ctx.queryInt("page") ?? 1
    let perPage = ctx.queryInt("per_page") ?? 10

    ctx.json(HashMap<String, Int64>(
        ("page", page),
        ("perPage", perPage)
    ))
})
```

#### `queryBool()` - 布尔参数

```cj
r.get("/posts", { ctx =>
    // 请求: /posts?published=true&featured=false
    let published = ctx.queryBool("published") ?? false
    let featured = ctx.queryBool("featured") ?? false

    ctx.json(HashMap<String, String>([
            ("filter", "published=${published}, featured=${featured}")
        ]))
})
```

#### `queryFloat()` - 浮点参数

```cj
r.get("/products", { ctx =>
    // 请求: /products?price=99.99&discount=0.15
    let price = ctx.queryFloat("price") ?? 0.0
    let discount = ctx.queryFloat("discount") ?? 0.0

    ctx.json(HashMap<String, Float64>(
        ("price", price),
        ("discount", discount)
    ))
})
```

### 获取所有查询参数

使用 `queries()` 获取所有查询参数（返回 `HashMap<String, Array<String>>`）：

```cj
r.get("/debug", { ctx =>
    // 请求: /debug?a=1&b=2&a=3
    let allQueries = ctx.queries()

    // allQueries = {
    //   "a": ["1", "3"],
    //   "b": ["2"]
    // }

    ctx.json(allQueries)
})
```

> **💡 提示：查询参数最佳实践**
>
> ：
1. ：使用 `??` 运算符提供合理默认值
2. ：优先使用 `queryInt()`, `queryBool()` 等类型化方法
3. ：检查参数有效性（如分页范围、价格非负等）
4. ：使用 snake_case（per_page）或 camelCase（perPage）


## 路径参数 (Path Parameters)

### 获取单个路径参数

使用 `param()` 方法获取 URL 路径中的动态参数：

```cj
// 注册路由时定义路径参数
r.get("/users/:id", { ctx =>
    // 请求: /users/123
    let id = ctx.param("id")  // 返回 "123"

    ctx.json(HashMap<String, String>([
        ("userId", id)
    ]))
})

r.get("/users/:userId/posts/:postId", { ctx =>
    // 请求: /users/123/posts/456
    let userId = ctx.param("userId")   // "123"
    let postId = ctx.param("postId")   // "456"

    ctx.json(HashMap<String, String>([
        ("userId", userId),
        ("postId", postId)
    ]))
})
```

### 获取所有路径参数

使用 `params()` 获取所有路径参数：

```cj
r.get("/users/:userId/posts/:postId", { ctx =>
    // 请求: /users/123/posts/456
    let allParams = ctx.params()

    // allParams = {
    //   "userId": "123",
    //   "postId": "456"
    // }

    ctx.json(allParams)
})
```

### 获取路由模式

使用 `route()` 获取当前匹配的路由模式：

```cj
r.get("/users/:id", { ctx =>
    // 请求: /users/123
    let routePattern = ctx.route()  // 返回 "/users/:id"
    let id = ctx.param("id")        // "123"

    ctx.json(HashMap<String, String>([
        ("route", routePattern),
        ("id", id)
    ]))
})
```

> **💡 提示：路径参数 vs 查询参数选择**
>
> - **路径参数**：用于标识资源（如 `/users/:id`）
> - **查询参数**：用于过滤、排序、分页（如 `/users?page=1&limit=10`）
>
> **RESTful 最佳实践**：
```
GET  /users          - 获取所有用户
GET  /users/:id      - 获取特定用户
GET  /users?active=true - 获取活跃用户列表
```


## 请求体 (Body)

### 读取原始请求体

使用 `bodyRaw()` 获取原始字节流：

```cj
r.post("/webhook", { ctx =>
    // 读取原始请求体
    let bodyBytes = ctx.bodyRaw()

    // 转换为字符串
    let bodyStr = String.fromUtf8(bodyBytes)

    ctx.json(HashMap<String, String>([
        ("received", bodyStr),
        ("length", "${bodyBytes.size}")
    ]))
})
```

### 解析 JSON 请求体

使用 `bindJson<T>()` 解析 JSON 到自定义类型：

```cj
import stdx.serialization.json.*
import stdx.encoding.json.stream.{JsonSerializable, JsonDeserializable}

// 定义可序列化的数据模型
class UserData <: JsonDeserializable<UserData> {
    var name: String = ""
    var email: String = ""
    var age: Int64 = 0

    public static func deserialize(json: JsonValue): UserData {
        let user = UserData()
        if (let obj = json.asObject()) {
            user.name = obj.getOrDefault("name", "").asString().getOrThrow()
            user.email = obj.getOrDefault("email", "").asString().getOrThrow()
            user.age = obj.getOrDefault("age", 0).asInt64().getOrThrow()
        }
        return user
    }
}

r.post("/users", { ctx =>
    let userData = ctx.bindJson<UserData>()

    match (userData) {
        case Some(user) =>
            // JSON 解析成功
            ctx.status(201)
               .json(HashMap<String, String>([
                    ("message", "User created"),
                    ("age", "${user.age}")
                ]))
        case None =>
            // JSON 解析失败
            ctx.status(400)
               .json(HashMap<String, String>([
                    ("error", "Invalid JSON format")
                ]))
    }
})
```

### 从查询字符串绑定到结构体

使用 `bindQuery<T>()` 将查询参数绑定到结构体：

```cj
import stdx.serialization.Serializable

class QueryParams <: Serializable<QueryParams> {
    var page: Int64 = 1
    var limit: Int64 = 10
    var search: String = ""

    public func serialize(): DataModel {
        DataModelStruct()
            .add(field<Int64>("page", this.page))
            .add(field<Int64>("limit", this.limit))
            .add(field<String>("search", this.search))
    }

    public static func deserialize(data: DataModel): QueryParams {
        let params = QueryParams()
        if (let data = data.asStruct()) {
            if (let Some(page) = data.getField("page")?.asInt64()) {
                params.page = page
            }
            if (let Some(limit) = data.getField("limit")?.asInt64()) {
                params.limit = limit
            }
            if (let Some(search) = data.getField("search")?.asString()) {
                params.search = search
            }
        }
        return params
    }
}

r.get("/users", { ctx =>
    let empty = QueryParams()
    let params = ctx.bindQuery(empty)

    // 请求: /users?page=2&limit=20&search=tang
    // params.page = 2
    // params.limit = 20
    // params.search = "tang"

    ctx.json(HashMap<String, String>([
            ("page", "${params.page}"),
            ("limit", "${params.limit}")
        ]))
})
```

## 表单处理 (Multipart Form)

### 解析 Multipart 表单

使用 `multipartForm()` 处理文件上传和复杂表单：

```cj
r.post("/upload", { ctx =>
    let form = ctx.multipartForm()

    match (form) {
        case Some(f) =>
            // 获取表单字段
            let username = f.values.get("username")?[0] ?? "anonymous"
            let description = f.values.get("description")?[0] ?? ""

            // 获取上传的文件
            let file = f.files.get("file")?[0]

            match (file) {
                case Some(f) =>
                    ctx.json(HashMap<String, String>([
                        ("message", "File uploaded"),
                        ("size", "${f.content.size}")
                    ]))
                case None =>
                    ctx.status(400).json(HashMap<String, String>([
                        ("error", "No file uploaded")
                    ]))
            }
        }
        case None =>
            ctx.status(400).json(HashMap<String, String>([
                ("error", "Invalid form data")
            ]))
    }
})
```

### 快捷方法：获取表单字段

使用 `fromValue()` 快速获取表单字段值：

```cj
r.post("/submit", { ctx =>
    let name = ctx.fromValue("name")
    let email = ctx.fromValue("email")
    let message = ctx.fromValue("message") ?? "No message"

    match (name, email) {
        case (Some(n), Some(e)) =>
            ctx.json(HashMap<String, String>([
                ("name", n),
                ("email", e),
                ("message", message)
            ]))
        case _ =>
            ctx.status(400).json(HashMap<String, String>([
                ("error", "Missing required fields")
            ]))
    }
})
```

### 快捷方法：获取上传文件

使用 `fromFile()` 快速获取上传的文件：

```cj
r.post("/avatar", { ctx =>
    let file = ctx.fromFile("avatar")

    match (file) {
        case Some(f) =>
            // 保存文件...
            ctx.json(HashMap<String, String>([
                ("message", "Avatar uploaded"),
                ("size", "${f.content.size}")
            ]))
        case None =>
            ctx.status(400).json(HashMap<String, String>([
                ("error", "No avatar file")
            ]))
    }
})
```

## 认证信息

### 获取 Basic Auth 信息

使用 `basicAuth()` 解析 HTTP Basic Authentication：

```cj
r.get("/protected", { ctx =>
    let authInfo = ctx.basicAuth()

    match (authInfo) {
        case Some(userInfo) =>
            // userInfo.username 和 userInfo.password
            if (userInfo.username == "admin" && userInfo.password == "secret") {
                ctx.json(HashMap<String, String>([
                    ("message", "Authenticated")
                ]))
            } else {
                ctx.status(401).json(HashMap<String, String>([
                    ("error", "Invalid credentials")
                ]))
            }
        case None =>
            // 没有 Authorization 头
            ctx.responseBuilder
                .status(401u16)
                .header("WWW-Authenticate", "Basic realm=\"Restricted\"")
                .body("")
    }
})
```

## 完整示例

### REST API 路由处理

```cj
import tang.*
import stdx.serialization.Serializable

main() {
    let r = Router()

    // 获取用户列表（带分页和搜索）
    r.get("/users", { ctx =>
        let page = ctx.queryInt("page") ?? 1
        let limit = ctx.queryInt("limit") ?? 10
        let search = ctx.query("search") ?? ""

        ctx.json(HashMap<String, String>([
            ("page", "${page}"),
            ("limit", "${limit}")
        ]))
    })

    // 获取单个用户
    r.get("/users/:id", { ctx =>
        let id = ctx.param("id")
        ctx.json(HashMap<String, String>([
            ("userId", id),
            ("name", "User ${id}")
        ]))
    })

    // 创建用户（JSON 请求体）
    r.post("/users", { ctx =>
        // 简化示例（实际应该使用 bindJson）
        let body = String.fromUtf8(ctx.bodyRaw())

        ctx.status(201).json(HashMap<String, String>([
            ("message", "User created")
        ]))
    })

    // 上传文件
    r.post("/upload", { ctx =>
        let file = ctx.fromFile("file")
        let description = ctx.fromValue("description") ?? "No description"

        match (file) {
            case Some(f) =>
                ctx.json(HashMap<String, String>([
                    ("filename", f.filename),
                    ("description", description)
                ]))
            case None =>
                ctx.status(400).json(HashMap<String, String>([
                    ("error", "No file")
                ]))
        }
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

## API 参考

### 查询参数方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `query(key: String)` | `?String` | 获取单个查询参数 |
| `queryInt(key: String)` | `?Int64` | 获取整数查询参数 |
| `queryBool(key: String)` | `?Bool` | 获取布尔查询参数 |
| `queryFloat(key: String)` | `?Float64` | 获取浮点查询参数 |
| `queries()` | `HashMap<String, Array<String>>` | 获取所有查询参数 |

### 路径参数方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `param(key: String)` | `String` | 获取路径参数 |
| `params()` | `HashMap<String, String>` | 获取所有路径参数 |
| `route()` | `String` | 获取路由模式 |

### 请求体方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `bodyRaw()` | `Array<Byte>` | 获取原始请求体 |
| `bindJson<T>()` | `?T` | 解析 JSON 到泛型类型 |
| `bindQuery<T>(value: T)` | `T` | 绑定查询参数到结构体 |

### 表单方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `multipartForm()` | `?MulitpartForm` | 获取 multipart 表单 |
| `fromValue(key: String)` | `?String` | 获取表单字段值 |
| `fromFile(key: String)` | `?MultipartFile` | 获取上传文件 |

### 认证方法

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `basicAuth()` | `Option<UserInfo>` | 获取 Basic Auth 信息 |

## 注意事项

### 1. 参数验证

始终验证用户输入：

```cj
r.get("/users", { ctx =>
    let page = ctx.queryInt("page") ?? 1

    // 验证分页范围
    if (page < 1 || page > 1000) {
        ctx.status(400).json(HashMap<String, String>([
            ("error", "Invalid page number")
        ]))
        return
    }

    // 处理逻辑...
})
```

### 2. Option 类型处理

所有 `?T` 返回类型都需要处理 `None` 情况：

```cj
// ✅ 推荐：使用 match 或 ??
let id = ctx.query("id")
match (id) {
    case Some(value) =>  /* 处理 */ 
    case None =>  /* 处理缺失 */ 
}

// 或使用默认值
let id = ctx.query("id") ?? "default"

// ❌ 避免：直接使用可能为 None 的值
let id = ctx.query("id").getOrThrow()  // 可能崩溃
```

### 3. 大文件上传

对于大文件上传，建议使用流式处理：

```cj
r.post("/upload-large", { ctx =>
    let file = ctx.fromFile("large-file")

    match (file) {
        case Some(f) =>
            // 检查文件大小
            if (f.content.size > 100_000_000) {  // 100MB
                ctx.status(413).json(HashMap<String, String>([
                    ("error", "File too large")
                ]))
                return
            }

            // 处理文件...
        case None => /* 处理错误 */
    }
})
```

## 相关链接

- **[响应操作](response.md)** - 发送响应的方法
- **[Cookie 操作](cookie.md)** - Cookie 读写方法
- **[辅助方法](utils.md)** - 请求信息获取方法
- **[源码](../../src/request.cj)** - TangHttpContext 源代码
