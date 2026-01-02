package banner_test

import std.collection.HashMap
import tang.*

func helloHandler(ctx: TangHttpContext): Unit {
    ctx.writeString("Hello, World!")
}

func userHandler(ctx: TangHttpContext): Unit {
    let id = ctx.param("id")
    ctx.json(HashMap<String, String>([
        ("userId", id)
    ]))
}

main() {
    // 创建 Tang 应用（自动打印 Banner 和路由）
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(8080u16),
        withShowBanner(),  // 显示启动 Banner
        withShowRoutes()   // 显示路由列表
    ])

    // 注册各种路由
    app.get("/", helloHandler)
    app.get("/users", helloHandler)
    app.get("/users/:id", userHandler)
    app.post("/users", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Created")
        ]))
    })
    app.put("/users/:id", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Updated")
        ]))
    })
    app.delete("/users/:id", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Deleted")
        ]))
    })
    app.patch("/users/:id", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Patched")
        ]))
    })

    // 路由组
    let api = app.group("/api")
    api.get("/posts", { ctx =>
        ctx.json(HashMap<String, String>([
            ("posts", "list")
        ]))
    })
    api.post("/posts", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Post created")
        ]))
    })

    let v1 = api.group("/v1")
    v1.get("/items", { ctx =>
        ctx.json(HashMap<String, String>([
            ("items", "v1 list")
        ]))
    })

    // 通配符路由
    app.get("/files/*path", { ctx =>
        let path = ctx.param("path")
        ctx.json(HashMap<String, String>([
            ("filePath", path)
        ]))
    })

    // 启动应用（自动打印 Banner 和路由）
    app.listen()
}
