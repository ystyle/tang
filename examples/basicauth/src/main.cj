package basicauth

import tang.*
import tang.middleware.accesslog.logger
import tang.middleware.exception.exception
import tang.middleware.basicauth.newBasicAuth

func authUser(ctx: TangHttpContext): Bool {
    if (let Some(userinfo) <- ctx.basicAuth()) {
        return userinfo.username() == "test" && userinfo.password() == "test"
    }
    return false
}

main() {
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    // 应用中间件
    app.use(exception())
    app.use(newBasicAuth(authUser))
    app.use(logger())

    let group = app.group("/api")
    group.get(
        "/user/current",
        {
            ctx => ctx.writeString("hello world!")
        }
    )

    // 启动应用
    app.listen()
}
