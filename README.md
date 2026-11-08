# Tang

> 一个基于仓颉语言的高性能 Web 框架，受 [Fiber](https://github.com/gofiber/fiber) 启发
> HTTP 层构建在 [tachyon](https://atomgit.com/ystyle/tachyon) 之上（fasthttp 风格、零分配、仅依赖 std）

[![License](https://img.shields.io/badge/license-MulanPSLv2-blue.svg)](LICENSE)
[![Cangjie](https://img.shields.io/badge/Cangjie-1.2.0+-orange.svg)](https://cangjie-lang.cn)

## ✨ 特性

- **🚀 高性能** - HTTP 层换成 tachyon 后，同机实测吞吐约为原 stdx 后端的 **2.1 倍**，每请求 CPU 约为 **1/2.2**
- **🎯 零 stdx 核心** - `tang` 核心只依赖 `std` + `tachyon`，下游**不需要配置 `CANGJIE_STDX_PATH`**
- **⛓️ 链式 API** - Fiber 风格的流畅 API
- **🔌 中间件生态** - 16 个零依赖中间件 + 5 个加密类（扩展成员）
- **🧪 内置测试框架** - `tang.testing` 不上网络、不占端口就能测路由（对标 Go `httptest`）
- **📦 按能力拆成员** - 用不到 JSON / 加密 / stdx 兼容就不引入对应模块

## 📦 模块结构

本仓是 cjpm workspace，四个成员，按需引入：

| 成员 | 依赖 | 说明 |
|---|---|---|
| **`tang`** | std + tachyon | 核心：路由、上下文、16 个中间件、测试框架、日志门面。**零 stdx** |
| `tang_ext_json_seajson` | + [seajson](https://pkg.cangjie-lang.cn/package/SeaJson) | JSON 编解码（SeaJSON，零 stdx） |
| `tang_ext_crypto` | + stdx.crypto | csrf / session / encryptcookie / etag / idempotency |
| `tang_ext_stdx` | + stdx.net.http | stdx 兼容层：tang 应用跑在 stdx server 上，复用 stdx 风格 handler |

> **本分支（`feat/tachyon-backend`）尚未发布**。已发布的 `tang 1.0.6` 仍是 stdx.net.http 后端。

## ⚙️ 环境要求

- 仓颉 1.2.0+

只依赖核心时**不需要 stdx**；引入 `tang_ext_crypto` / `tang_ext_stdx` 才需要：

```bash
eval "$(cjvs env zsh)" && eval "$(cjvs stdx-env zsh)"
```

## 🚀 快速开始

### Hello World

```cj
import tang.*

main() {
    let app = Tang()
    app.get("/", { ctx => ctx.writeString("Hello, Tang!") })
    app.listen(8080u16)
}
```

`cjpm.toml`：

```toml
[dependencies]
  "tang" = { git = "https://github.com/ystyle/tang.git", branch = "feat/tachyon-backend" }
```

### 返回 JSON

JSON 需要注册编解码器（适配器模式，核心不绑定具体 JSON 库）：

```cj
import tang.*
import tang_ext_json_seajson.*

public class User <: seaJsonEncodable {   // 实际请实现 seajson 的 JsonEncodable / JsonWriterEncodable
    ...
}

main() {
    useSeaJson()          // 注册为全局默认 codec
    let app = Tang()
    app.get("/users/:id", { ctx =>
        let u = User(...)
        ctx.json(u)       // 走注册的 codec 输出，Content-Type: application/json
    })
    app.listen(8080u16)
}
```

### 中间件

```cj
import tang.*
import tang.middleware.requestid.*
import tang.middleware.cors.*

let app = Tang()
let root = app.group("")
root.use([requestid(), corsAllowAll()])

app.get("/hello", { ctx => ctx.writeString("hi") })
app.listen(8080u16)
```

### 写测试（不上网络）

```cj
import tang.*
import tang.testing.*

@Test
class ApiTest {
    @TestCase
    func testHello(): Unit {
        let app = Tang()
        app.get("/hello", { ctx => ctx.writeString("hi") })

        test(app, TestRequest.get("/hello"))
            .assertStatus(200)
            .assertBody("hi")
    }
}
```

详见 [docs/testing.md](docs/testing.md)。

## 📚 文档

| 文档 | 内容 |
|---|---|
| [快速入门](docs/getting-started.md) | 从零建项目、依赖配置、第一个应用 |
| [框架概述](docs/overview.md) | 架构、请求生命周期、成员划分 |
| [API 参考](docs/api/app.md) | App / Router / Group / Context |
| [中间件](docs/middleware/overview.md) | 16 个核心中间件 + 扩展成员 |
| [测试框架](docs/testing.md) | `tang.testing`（对标 Go `httptest`） |
| [stdx 兼容层](docs/stdx-compat.md) | 存量 stdx 项目平滑迁移 |
| [从 1.0.x 迁移](docs/MIGRATION.md) | 旧 API → 新 API 对照 |
| [零 stdx 化方案](docs/design/zero-stdx-workspace.md) | 为什么拆成员、JSON/日志怎么解耦 |
| [性能](docs/advanced/performance.md) | 优化建议与实测数据 |

## 🎯 路由特性

```cj
app.get("/static", handler)              // 静态路由
app.get("/user/:id", handler)            // 路径参数 → ctx.param("id")
app.get("/files/*", handler)             // 通配符 → ctx.param("*")
app.group("/api").use([middleware])      // 路由分组
app.mount("/sub", subApp.getRouter())    // 子应用挂载
```

## 📁 示例

`examples/` 下有可运行示例（basic / json / bind_query / middleware / ...）。
注意：部分示例仍在旧 API 上，迁移中。

## 🔗 相关链接

- [tachyon](https://atomgit.com/ystyle/tachyon) — 底层 HTTP 服务端
- [SeaJSON](https://pkg.cangjie-lang.cn/package/SeaJson) — 零 stdx JSON 库
- [为什么比 stdx.net.http 快](https://github.com/ystyle/cangjie-runtime-issue-3577-repro)

## 📝 许可证

Mulan PSL v2
