package path_params

import std.collection.HashMap
import tang.*

main() {
    // 创建 Tang 应用
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    // 创建分组
    let group = app.group("/api")
    // 获取路径参数
    group.get(
        "/user/:id",
        {
            ctx =>
            let id = ctx.param("id")
            println("id: ${id}")
            ctx.writeString(id)
        }
    )
    // 获取通配符参数
    group.get(
        "/user/*path",
        {
            ctx =>
            let path = ctx.param("path")
            println("path: ${path}")
            ctx.writeString(path)
        }
    )

    // 启动应用
    app.listen()
}
