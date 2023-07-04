from tang import tang.*
from tang import middleware.{logMiddleware, exceptionMiddleware}
from net import http.Server, http.ResponseWriteStream
from std import collection.HashMap

func debugHandle(w:ResponseWriteStream, r:Request) {
    plainString(w, "hello world!")
}

main() {
    // 创建路由
    let r = Router([
        use([
            exceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            logMiddleware // 访问日志记录
        ])
    ])
    // 创建分组
    r.group.withGroup("/api", {group =>
        // 命名路由
        group.get("/user/:id", {w, r => 
            let id = r.params.get("id") ?? "None"
            println("id: ${id}")
            plainString(w, r.request.requestURI)
        })
        // 静态路由
        group.get("/user/current", {w, _ => 
            plainString(w, "current user: haha")
        })
        group.get("/user/exception", {w,r=>
            throw Exception("出现异常啦！")
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