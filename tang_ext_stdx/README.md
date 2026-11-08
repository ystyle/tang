# tang_ext_stdx

**tang 的 stdx 兼容层：让 tang 应用跑在 stdx 的 server 上，复用 stdx 风格 handler。**

stdx 的 `HttpContext` 构造器是 internal，外部无法伪造上下文，所以想让 stdx 风格 handler
拿到真上下文，只能让 stdx 自己收包。方向因此是「tang 跑在 stdx server 上」，而不是反过来。

```toml
[dependencies]
  "tang" = "2.0.0"
  "tang_ext_stdx" = "2.0.0"
```

```cangjie
import tang.*
import tang_ext_stdx.*
import stdx.net.http.HttpContext

main() {
    let app = Tang()
    app.get("/hello", { ctx => ctx.writeString("hi") })          // tang 原生路由
    app.get("/legacy", fromStd({ ctx: HttpContext =>               // stdx 风格 handler
        ctx.responseBuilder.body("from stdx handler")
    }))
    serve(app, "0.0.0.0", 8080u16)                                 // 跑在 stdx server 上
}
```

## 能力对照

| 能力 | tachyon server | stdx server（本包） |
|---|---|---|
| tang 路由 / 中间件 / 参数 | 支持 | 支持 |
| `ctx.json` / `tang.testing` | 支持 | 支持 |
| stdx 风格 handler（`fromStd`） | 不支持 | 支持 |
| 性能 | 高 | 取决于 stdx server |

迁移建议：先 `serve` 跑起来，再逐个把 `fromStd` handler 换成 tang 写法，全部换完后切回
`app.listen()` 拿 tachyon 的性能收益。

MulanPSL-2.0
