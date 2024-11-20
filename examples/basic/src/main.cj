package basic

import tang.*
import tang.middleware.{logMiddleware, exceptionMiddleware, requestid}
import net.http.{ServerBuilder, HttpContext}
import std.collection.HashMap

func helloHandle(ctx: TangHttpContext): Unit {
    ctx.writeString("hello world!")
}

main() {
    // 创建路由
    let r = Router(
        use(
            exceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            logMiddleware, // 访问日志记录
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
    group.get("/user/*path", helloHandle)
    // 构建并启动服务

    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
