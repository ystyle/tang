### Tang
> 一个仓颉的轻量级 Web 框架，初始版本移植自 [uptrace/bunrouter](https://github.com/uptrace/bunrouter)
>
> **状态**：开发中（API 不稳定，不建议用于生产环境）

### 特性
- **Radix Tree 路由**：基于基数树的高效路由实现，支持复杂路由规则
- **路由优先级**：静态路径 > 命名参数 > 通配符，智能匹配
- **路由分组**：支持分组路由，便于组织 API
- **中间件系统**：可复用的中间件机制
- **参数绑定**：支持 query 参数和 JSON body 绑定到 class
- **JSON 响应**：支持直接使用 class 返回 JSON

### 安装依赖
```toml
[dependencies]
  tang = { git = "https://github.com/ystyle/tang", branch = "master"}
```

### 示例
```cj
import tang.*
import tang.middleware.{accesslog.logger, exception.exception, requestid.requestid}
import stdx.net.http.ServerBuilder
import std.collection.HashMap

func helloHandle(ctx: TangHttpContext): Unit {
    ctx.writeString("hello world!")
}

main() {
    // 创建路由
    let r = Router(
        use(
            exception, // 放第一位，保证其它中间件也能正常执行
            logger, // 访问日志记录
            requestid
        )
    )
    // 声明接口
    r.get("/hello", helloHandle)

    // 创建分组
    let group = r.group("/api")
    // 命名路由
    group.get(
        "/user/:id",
        {
            ctx => 
            let id = ctx.param("id")
            ctx.responseBuilder.body("current id: ${id}")
        }
    )
    // 静态路由
    group.get(
        "/user/current",
        {
            ctx => ctx.responseBuilder.body("current user: ystyle")
        }
    )
    group.get(
        "/user/exception",
        {
            ctx => throw Exception("出现异常啦！")
        }
    )
    // 通配符路由
    group.get("/user/*path", {ctx =>
       let path = ctx.param("path")
       ctx.writeString("path: ${path}")
    })
    // 构建并启动服务

    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
```

### 路由规则

Tang 使用 Radix Tree（基数树）实现高效路由匹配，支持以下路由类型：

#### 1. 静态路由
精确匹配的路径，优先级最高：
```cj
r.get("/user/current", { ctx => ... })
r.get("/api/users", { ctx => ... })
```

#### 2. 命名参数路由
使用 `:name` 语法捕获路径参数：
```cj
r.get("/user/:id", { ctx =>
    let id = ctx.param("id")  // 获取参数值
    // ...
})
```
匹配示例：
- `/user/123` → `id = "123"`
- `/user/abc` → `id = "abc"`

#### 3. 通配符路由
使用 `*name` 语法捕获剩余所有路径：
```cj
r.get("/files/*path", { ctx =>
    let path = ctx.param("path")  // 获取剩余路径
    // ...
})
```
匹配示例：
- `/files/docs/file.txt` → `path = "docs/file.txt"`
- `/files/a/b/c` → `path = "a/b/c"`

#### 4. 路由优先级

当多个路由可能匹配同一路径时，按以下优先级选择：

1. **静态路由**（最高）
   - `/user/current` 优先于 `/user/:id`

2. **命名参数路由**
   - 单段路径（如 `/user/123`）优先匹配参数路由

3. **通配符路由**（最低）
   - 多段路径（如 `/user/files/docs`）匹配通配符路由

示例：
```cj
// 假设注册了以下路由
r.get("/user/current", { ... })      // 静态路由
r.get("/user/:id", { ... })          // 参数路由
r.get("/user/*path", { ... })        // 通配符路由

// 匹配结果：
// /user/current  → 静态路由（优先级最高）
// /user/123      → 参数路由（单段路径）
// /user/a/b      → 通配符路由（多段路径）
```

#### 5. 性能特性

- **时间复杂度**：O(k)，其中 k 为路径长度
- **空间优化**：Radix Tree 自动压缩公共前缀
- **快速查找**：树形结构，避免线性遍历

### 仓颉版本支持情况
master 当前配置0.59.6, 配置过的仓颉版本已用分支归档, 以仓颉版本号为分支名称.


### 部署

生产环境部署建议请查看 [部署文档](docs/deployment.md)，包括：
- Gzip 压缩配置
- 反向代理配置
- 性能优化建议
- 安全配置建议

### 更多示例
更多示例请查看 [examples](/examples/) 目录

### 中间件

#### 内置中间件

Tang 提供以下中间件：

- **[accesslog](/src/middleware/accesslog/)**: HTTP 访问日志记录
  - 记录请求方法、路径、延迟、状态码
  - 自动集成 requestid（如果启用）
  - 支持结构化日志输出

- **[requestid](/src/middleware/requestid/)**: 请求 ID 生成
  - 为每个请求生成唯一 ID（使用 Sonyflake 算法）
  - 存储到 Context 的 KV 存储中
  - 其他中间件可通过 `ctx.requestid()` 访问

- **[exception](/src/middleware/exception/)**: 全局异常处理
  - 捕获未处理的异常
  - 记录错误日志
  - 返回 500 错误响应

- **[basicauth](/src/middleware/basicauth/)**: HTTP Basic 认证
  - 标准的 Basic 认证支持
  - 可自定义认证逻辑
  - 支持 realm 配置

- **[cors](/src/middleware/cors/)**: CORS 跨域支持
  - 支持自定义允许的来源、方法、头
  - 支持预检请求（OPTIONS）
  - 支持凭证模式

- **[security](/src/middleware/security/)**: 安全响应头
  - 提供常见安全响应头（X-Frame-Options, X-Content-Type-Options 等）
  - 支持预设安全策略
  - 可自定义安全头

> **💡 提示**：Gzip 压缩推荐在 Nginx 或反向代理层配置，参见 [部署建议](docs/deployment.md)

#### Context 扩展机制

Tang 使用仓颉的**同包直接扩展**机制提供便捷的 Context 方法：

```cj
// src/context_extensions.cj
extend TangHttpContext {
    public func requestid(): ?String {
        return this.kvGet<String>("requestid")
    }
}
```

**扩展规则：**
- 同包扩展自动导出，无需导入接口
- 中间件通过 `ctx.kvSet(key, value)` 存储数据
- 其他中间件通过扩展方法（如 `ctx.requestid()`）访问数据
- 企业级框架可在自己的包中使用接口扩展 TangHttpContext

**中间件通信示例：**
```cj
// requestid 中间件存储数据
ctx.kvSet("requestid", "${id}")

// accesslog 中间件读取数据
let rid = ctx.requestid()
if (let Some(v) <- rid) {
    attrs.add(("requestid", v))
}
```