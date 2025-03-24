### tang
>一个仓颉的轻量级的web框架， 初始版本移植自[uptrace/bunrouter](https://github.com/uptrace/bunrouter)， 状态： 开发中[api不稳定, 不建议用于生产环境]

### 功能
- 中间件[middleware]： 可以把常见操作从 HTTP handler提取到可重用函数中
- 支持路由优先级： 静态路径 > 命名路径 > 通配符路径
- 支持路由分组
- 支持使用class返回json
- 支持绑定query参数到class
- 支持绑定json body到class
- 支持获取路径命名参数和通配符路径参数

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
       ctx.writeString("path: path")
    })
    // 构建并启动服务

    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
```

### 仓颉版本支持情况
master 当前配置0.59.6, 配置过的仓颉版本已用分支归档, 以仓颉版本号为分支名称.


### 更多示例
更多示例请查看 [examples](/examples/) 目录

### 中间件
- [log](/src/middleware/log.cj): 日志打印
- [basic auth](/src/middleware/basic_auth.cj): basic auth认证
- [exception](/src/middleware/exception.cj): 异常恢复，错误日志打印，并返回500错误
- [requestid](/src/middleware/requestid.cj): 在请求设置请求id的中间件