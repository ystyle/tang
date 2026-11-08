package todo

import tang.*
import tang.middleware.accesslog.newAccessLog
import tang.middleware.exception.newRecovery
import tang.middleware.requestid.requestid
import tang_ext_json_seajson.useSeaJson

main() {
    // JSON 走适配器：核心零 stdx，启动时注册一次 codec
    useSeaJson()

    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16),
        withShowBanner(),
        withShowRoutes()
    ])

    // 中间件挂在根分组上（放在路由注册之前，对后续路由生效）
    let root = app.group("")
    root.use([newRecovery(), newAccessLog(), requestid()])

    let group = app.group("/api")

    group.get("/todo/:id", getOneTodo)
    group.get("/todo", listTodo)
    group.post("/todo", createTodo)
    group.put("/todo", updateTodo)
    group.delete("/todo/:id", deleteTodo)

    app.listen()
}
