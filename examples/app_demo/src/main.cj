package app_demo

import std.collection.HashMap
import tang.*

func helloHandler(ctx: TangHttpContext): Unit {
    ctx.writeString("Hello, Tang!")
}

func userHandler(ctx: TangHttpContext): Unit {
    let id = ctx.param("id")
    ctx.json(HashMap<String, String>(
        ("userId", id),
        ("name", "Alice")
    ))
}

main() {
    // 方式一：使用默认配置
    // let app = Tang()
    // app.get("/", helloHandler)
    // app.get("/users/:id", userHandler)
    // app.listen()

    // 方式二：使用选项配置
    let app = Tang([
        withHost("0.0.0.0"),          // 监听所有接口
        withPort(3000),                // 使用 3000 端口
        withShowBanner(),              // 显示 Banner（默认）
        withShowRoutes()               // 显示路由（默认）
    ])

    // 注册路由 - 链式调用
    app.get("/", helloHandler)
      .get("/users", helloHandler)
      .get("/users/:id", userHandler)
      .post("/users", { ctx =>
          ctx.json(HashMap<String, String>([
              ("message", "User created")
          ]))
      })
      .put("/users/:id", { ctx =>
          ctx.json(HashMap<String, String>([
              ("message", "User updated")
          ]))
      })
      .delete("/users/:id", { ctx =>
          ctx.json(HashMap<String, String>([
              ("message", "User deleted")
          ]))
      })

    // 使用路由组
    let api = app.group("/api")
    api.get("/posts", { ctx =>
        ctx.json(HashMap<String, String>([
            ("posts", "list")
        ]))
    })

    // 启动应用（自动打印 Banner 和路由）
    app.listen()
}
