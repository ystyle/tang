from tang import tang.*
from tang import middleware.{logMiddleware, newBasicAuthMiddleware, withBasicAuthRealm}
from net import http.Server, http.ResponseWriteStream, http.BasicAuth

func debugHandle(w:ResponseWriteStream, r:Request) {
    plainString(w, "hello world!")
}

func authUser (r:Request):Bool {
    let basicAuth:?BasicAuth = r.request.basicAuth()
    if (let Some(basic) = basicAuth) {
        return basic.username == "test" && basic.password == "test"
    } else {
        return false
    }

}

main() {
    let r = Router([
        use([
            newBasicAuthMiddleware(authUser, [withBasicAuthRealm("test:test")]),
            logMiddleware
        ])
    ])
    r.group.withGroup("/api", {group =>
        group.get("/user/current", {w, r => 
            plainString(w, "hello world!")
        })
    })

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}