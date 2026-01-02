package basic

import std.collection.HashMap
import tang.*

func helloHandle(ctx: TangHttpContext): Unit {
    ctx.writeString("hello world!")
}

main() {
    // 创建 Tang 应用
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16),
        withShowBanner(),
        withShowRoutes()
    ])

    // 声明接口
    app.get("/hello", helloHandle)

    // 创建分组
    let group = app.group("/api")

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

    // 启动应用
    app.listen()
}
