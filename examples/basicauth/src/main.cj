from tang import tang.*
from tang import middleware.{LogMiddleware, NewBasicAuthMiddleware, WithBasicAuthRealm}
from net import http.Server, http.ResponseWriteStream, http.BasicAuth

func debugHandle(w:ResponseWriteStream, r:Request) {
    w.writeStatusCode(200)
    w.write("hello world".toUtf8Array())
    ()
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
        Use([
            LogMiddleware,
            NewBasicAuthMiddleware(authUser, [WithBasicAuthRealm("test:test")])
        ])
    ])
    r.group.withGroup("/api", {group =>
        group.get("/user/current", {w, r => 
            w.writeStatusCode(200)
            println(w.header().getKeysToString())
            w.write("current user: haha\n".toUtf8Array())
        })
    })

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}