# 快速入门

本指南带你在几分钟内跑起一个 Tang 应用，并说明「哪些能力要用哪个模块」。

> 本分支（`feat/tachyon-backend`）把 HTTP 层换成了 [tachyon](https://atomgit.com/ystyle/tachyon)，
> 并把 tang 拆成 workspace 做到核心零 stdx。已发布的 `tang 1.0.6` 仍是 stdx.net.http 后端。

## 📋 前置要求

- **仓颉 SDK 1.2.0+**
- 编辑器（VS Code / IntelliJ IDEA 等）

**不需要 stdx** —— 只要你不引入 `tang_ext_crypto` / `tang_ext_stdx`。
（这两个成员本来就是 stdx 能力，用到时才需要 `eval "$(cjvs stdx-env zsh)"`。）

## 🚀 第一步：创建项目

```bash
mkdir my-tang-app && cd my-tang-app
cjpm init
```

`cjpm.toml`：

```toml
[dependencies]
  "tang" = { git = "https://github.com/ystyle/tang.git", branch = "feat/tachyon-backend" }
```

按需追加扩展成员：

| 你要用 | 加这个依赖 |
|---|---|
| `ctx.json` / JSON 绑定 | `tang_ext_json_seajson` |
| csrf / session / encryptcookie / etag / idempotency | `tang_ext_crypto` |
| 存量 stdx 风格 handler | `tang_ext_stdx` |

## ✍️ 第二步：第一个应用

`src/main.cj`：

```cj
import tang.*

main() {
    let app = Tang()

    app.get("/", { ctx =>
        ctx.writeString("Hello, Tang!")
    })

    app.get("/users/:id", { ctx =>
        ctx.writeString("user=" + ctx.param("id"))
    })

    app.listen(8080u16)
}
```

```bash
cjpm run
curl http://127.0.0.1:8080/
```

## 🔌 第三步：加中间件

```cj
import tang.*
import tang.middleware.requestid.*
import tang.middleware.cors.*

let app = Tang()
let root = app.group("")
root.use([requestid(), corsAllowAll()])
```

中间件清单见 [中间件概述](middleware/overview.md)。

## 🧩 第四步：返回 JSON

核心不绑定 JSON 库（要保持零 stdx），改用适配器模式：

```toml
[dependencies]
  "tang" = { ... }
  "tang_ext_json_seajson" = { ... }
```

```cj
import tang.*
import tang_ext_json_seajson.*

main() {
    useSeaJson()        // 注册全局 JSON codec，必须在处理请求前调用
    let app = Tang()
    app.get("/json", { ctx =>
        ctx.json(MyDto())   // MyDto 实现 seajson 的 JsonEncodable / JsonWriterEncodable
    })
    app.listen(8080u16)
}
```

反序列化（泛型约束在适配器里，所以是自由函数）：

```cj
import tang_ext_json_seajson.bindJson

app.post("/echo", { ctx =>
    match (bindJson<MyDto>(ctx)) {
        case Some(v) => ctx.json(v)
        case None => ctx.responseBuilder.status(400u16).body("bad json")
    }
})
```

## 🧪 第五步：写测试（不用起服务）

```cj
import tang.*
import tang.testing.*

@Test
class AppTest {
    @TestCase
    func testHello(): Unit {
        let app = Tang()
        app.get("/", { ctx => ctx.writeString("Hello, Tang!") })

        test(app, TestRequest.get("/"))
            .assertStatus(200)
            .assertBody("Hello, Tang!")
    }
}
```

原理见 [测试框架](testing.md)：tang 用 tachyon 的 detached ctx 构造请求、捕获响应，
不需要端口、不需要 HTTP 客户端。

## 📁 第六步：项目结构建议

```
my-tang-app/
  cjpm.toml
  src/
    main.cj          # 启动与路由注册
    handlers/        # 业务 handler
    middleware/      # 自定义中间件
```

## 🔄 从 1.0.x 升级

API 有变化（JSON 需注册 codec、加密中间件换 import 路径、`fromStd` 移到 `tang_ext_stdx` 等），
详见 [迁移指南](MIGRATION.md)。

## 接下来

- [框架概述](overview.md) —— 请求生命周期、模块划分
- [API 参考](api/app.md) —— App / Router / Group / Context
- [中间件](middleware/overview.md) —— 16 个核心中间件 + 6 个扩展/暂缺
- [性能](advanced/performance.md) —— 优化建议与实测数据
