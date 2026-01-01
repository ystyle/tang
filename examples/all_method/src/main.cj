package all_method

import stdx.net.http.ServerBuilder
import tang.*

main() {
    let app = Router()

    // 使用 all() 方法匹配所有 HTTP 方法
    // 适用于健康检查、CORS 预检等场景
    app.all("/health", { ctx =>
        let method = ctx.method()
        ctx.status(200)
           .contentType("application/json")
           .writeString("{\"status\":\"ok\",\"method\":\"${method}\"}")
    })

    // 可以在 Group 中使用 all()
    let apiGroup = app.group("/api")

    // API 版本信息 - 所有方法都返回相同的信息
    apiGroup.all("/version", { ctx =>
        ctx.writeString("{\"version\":\"1.0.0\",\"framework\":\"Tang Web Framework\"}")
    })

    // 启动服务器
    let server = ServerBuilder().distributor(app).addr("127.0.0.1").port(8080).build()
    println("Server listening on http://localhost:${server.port}")
    println("Try:")
    println("  curl http://localhost:8080/health")
    println("  curl -X POST http://localhost:8080/health")
    println("  curl -X PUT http://localhost:8080/health")
    println("  curl http://localhost:8080/api/version")
    server.serve()
}

