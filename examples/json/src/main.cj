from tang import tang.*
from tang import middleware.LogMiddleware
from net import http.Server, http.ResponseWriteStream
from std import collection.HashMap

func debugHandle(w:ResponseWriteStream, r:Request) {
    w.writeStatusCode(200)
    w.write("hello world".toUtf8Array())
    ()
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
        // 静态路由
        group.get("/user/current", {w, r => 
            let m = HashMap<String, String>()
            m.put("1", "1")
            m.put("2", "2")
            m.put("3", "3")
            // 可以返回实现了 Serializable 接口的类型
            tang.JSON(w, m)
            // 还有个可以返回 http status code的方法
            // tang.JSONWithCode(w, 201, m)
        })
    })

    r.group.get("/hello", debugHandle)

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}