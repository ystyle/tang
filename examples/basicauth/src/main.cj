package basicauth

import tang.*
import tang.middleware.accesslog.newAccessLog
import tang.middleware.exception.newRecovery
import tang.middleware.basicauth.newBasicAuth

func authUser(ctx: TangHttpContext): Bool {
    if (let Some(userinfo) <- ctx.basicAuth()) {
        return userinfo.username == "test" && userinfo.password == "test"
    }
    return false
}

main() {
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    // 中间件挂在根分组上，对随后注册的路由生效
    let root = app.group("")
    root.use([newRecovery(), newBasicAuth(authUser), newAccessLog()])

    app.group("/api").get(
        "/user/current",
        { ctx => ctx.writeString("hello world!") }
    )

    app.listen()
}
