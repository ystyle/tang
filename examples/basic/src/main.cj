package basic

import std.collection.HashMap
import stdx.log.LogLevel
import tang.middleware.{log.logger, exception.exception, requestid.requestid}
import stdx.net.http.{ServerBuilder, HttpContext}
import tang.*

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
    
    group.post("/user/create", {ctx =>
        let name = ctx.fromValue("username")
        ctx.responseBuilder.body(name ?? "null")
    })

    
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
            _ => throw Exception("出现异常啦！")
        }
    )
    
    // 命名路由
    group.get(
        "/user/:id",
        {
            ctx => 
            let id = ctx.param("id")
            ctx.responseBuilder.body("current id: ${id}")
        }
    )

    // 通配符路由
    group.get("/user_file/*path", {ctx => 
       let mypath = ctx.param("path")
       ctx.writeString("path: ${mypath}")
    })
    // 构建并启动服务

    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    server.logger.level = LogLevel.ERROR
    println("listening on http://localhost:${server.port}")
    server.serve()
}
