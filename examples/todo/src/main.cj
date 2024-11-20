package todo

import net.http.ServerBuilder
import tang.*
import tang.middleware.{logMiddleware, exceptionMiddleware}


main() {
    // 创建路由
    let r = Router(
        use(
            exceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            logMiddleware // 访问日志记录
        )
    )
    // 创建分组
    let group = r.group("/api")
    // 获取指定id的todo
    group.get("/todo/:id", getOneTodo)
    // 获取所有的todoList
    group.get("/todo", listTodo)
    // 创建一个todo
    group.post("/todo", createTodo)
    // 更新一个todo
    group.put("/todo", updateTodo)
    // 删除一个todo
    group.delete("/todo/:id", deleteTodo)

    // 构建并启动服务
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
