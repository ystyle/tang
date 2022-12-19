from tang import tang.*
from tang import middleware.{logMiddleware, exceptionMiddleware}
from net import http.Server, http.ResponseWriteStream
from std import collection.HashMap

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
        // 获取路径参数
        group.get("/user/:id", {w, r => 
            let id = r.params.get("id") ?? "None"
            println("id: ${id}")
            plainString(w, id)
        })
        // 获取通配符参数
        group.get("/user/*path", {w, r => 
            let path = r.params.get("path") ?? "not path value"
            let m = r.params.map()
            json(w, m)
        })
    })

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}