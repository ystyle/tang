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
import tang.middleware.{log.logger, exception.exception, requestid.requestid}
import net.http.{ServerBuilder, HttpContext}
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


### 更多示例
更多示例请查看 [examples](/examples/) 目录

### 中间件
- [log](/src/middleware/log.cj): 日志打印
- [basic auth](/src/middleware/basic_auth.cj): basic auth认证
- [exception](/src/middleware/exception.cj): 异常恢复，错误日志打印，并返回500错误
- [requestid](/src/middleware/requestid.cj): 在请求设置请求id的中间件