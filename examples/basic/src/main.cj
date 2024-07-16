package basic

import tang.*
import tang.middleware.{logMiddleware, exceptionMiddleware}
import net.http.{ServerBuilder, HttpContext}
import std.collection.HashMap

func debugHandle(ctx: TangHttpContext): Unit {
    ctx.writeString("hello world!")
}

main() {
    // 创建路由
    let r = Router(
        use(
            exceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            logMiddleware // 访问日志记录
        )
    )
    let group = r.newGroup("/apiv2")
    group.get("/hello", debugHandle)
    // 创建分组
    r.group.withGroup(
        "/api",
        {
            group =>
            // 命名路由
            group.get(
                "/user/:id",
                {
                    ctx => ctx.responseBuilder.body("测试")
                }
            )
            // 静态路由
            group.get(
                "/user/current",
                {
                    ctx => ctx.responseBuilder.body("current user: haha")
                }
            )
            group.get(
                "/user/exception",
                {
                    ctx => throw Exception("出现异常啦！")
                }
            )
            // 通配符路由
            group.get("/user/*path", debugHandle)
        }
    )

    r.group.get("/hello", debugHandle)

    // 构建并启动服务
    
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
