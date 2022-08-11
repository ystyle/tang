from tang import tang.*
from tang import middleware.LogMiddleware
from net import http.Server, http.ResponseWriteStream
from std import collection.HashMap

func debugHandle(w:ResponseWriteStream, r:Request) {
    PlainString(w, "hello world!")
}

main() {
    // 创建路由
    let r = Router([
        Use([
            LogMiddleware
        ])
    ])
    // 创建分组
    r.group.withGroup("/api", {group =>
        // 命名路由
        group.get("/user/:id", debugHandle)
        // 静态路由
        group.get("/user/current", {w, r => 
            PlainString(w, "current user: haha")
        })
        // 通配符路由
        group.get("/user/*path", debugHandle)
    })

    r.group.get("/hello", debugHandle)

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}