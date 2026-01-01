package path_params

import std.collection.HashMap
import stdx.net.http.ServerBuilder
import tang.*

main() {
    // 创建路由
    let r = Router()
    // 创建分组
    let group = r.group("/api")
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

    // 构建并启动服务
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
