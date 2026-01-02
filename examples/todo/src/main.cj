package todo

import tang.*
import tang.middleware.accesslog.logger
import tang.middleware.exception.exception
import tang.middleware.requestid.requestid

main() {
    // 创建 Tang 应用
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16),
        withShowBanner(),
        withShowRoutes()
    ])

    // 全局中间件
    app.use(exception())  // 放第一位，保证其它中间件也能正常执行
    app.use(logger())      // 访问日志记录
    app.use(requestid())   // 请求id

    // 创建分组
    let group = app.group("/api")

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

    // 启动应用
    app.listen()
}
