package basicauth

import tang.*
import tang.middleware.{logMiddleware, newBasicAuthMiddleware, withBasicAuthRealm, BasicAuth, exceptionMiddleware}
import net.http.{ServerBuilder, HttpRequest}

func authUser(ctx: TangHttpContext): Bool {
    if (let Some(userinfo) <- ctx.basicAuth()) {
        return userinfo.username() == "test" && userinfo.password() == "test"
    }
    return false
}

main() {
    let r = Router(
        use(
            exceptionMiddleware
            newBasicAuthMiddleware(authUser, [withBasicAuthRealm("Restricted")]),
            logMiddleware,
        )
    )
    let group = r.group("/api")
    group.get(
        "/user/current",
        {
            ctx => ctx.writeString("hello world!")
        }
    )
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
