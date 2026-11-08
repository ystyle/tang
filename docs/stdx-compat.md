# stdx 兼容层（tang_ext_stdx）

给存量 stdx 项目一条平滑迁移路：**tang 应用可以跑在 stdx 的 server 上**，
原有的 stdx 风格 handler（参数是 `stdx.net.http.HttpContext`）继续可用。

## 为什么方向是「跑在 stdx server 上」

stdx 的 `HttpContext` 构造器是 **internal** —— 外部既造不出上下文，也接不住响应。
所以想让 handler 拿到真的 `HttpContext`，只有一条路：让 stdx 自己收包。

反过来，tachyon 的 `RequestCtx` 可以用 `DetachedRequest` 手工构造，
所以 tang 的路由与中间件可以原样跑在 stdx 的请求上。

```
stdx server 收包
   ↓ stdx HttpContext（真的）
   转成 tachyon DetachedRequest → newDetachedCtx
   ↓ tang Router.handle（tang 的中间件、路由、参数全部生效）
   ↓ snapshotResponse
写回 stdx HttpResponseBuilder
```

## 用法

```cangjie
import tang.*
import tang_ext_stdx.*

let app = Tang()

// ① tang 原生路由（写法不变）
app.get("/hello", { ctx => ctx.writeString("hello from tang") })

// ② stdx 风格 handler：拿真 HttpContext，迁移时几乎不用改
app.get("/legacy", fromStd({ stdc: stdx.net.http.HttpContext =>
    stdc.responseBuilder.header("X-From", "stdx")
    stdc.responseBuilder.body("hello from stdx handler")
}))

// ③ 跑在 stdx 的 server 上
serve(app, "0.0.0.0", 8080)
```

- `serve(app, host, port)`：阻塞运行
- `serveAsync(app, host, port): stdx.net.http.Server`：自己管生命周期（测试/嵌入式用）
- `fromStd(handler)`：把 `(HttpContext) -> Unit` 适配成 tang 的 `HandlerFunc`

## 能力对照

| 能力 | 在 tachyon server 上 | 在 stdx server 上（本模块） |
|---|---|---|
| tang 路由 / 中间件 / 参数 | ✅ | ✅ |
| `ctx.json` / `tang.testing` | ✅ | ✅ |
| stdx 风格 handler（`fromStd`） | ❌（拿不到 stdx 上下文） | ✅ |
| 性能 | 高（tachyon 主循环） | 取决于 stdx server |

**建议**：新项目 / 已迁移项目用 tachyon server；存量项目先 `serve` 跑起来，
再把 handler 逐个从 `fromStd` 换成 tang 写法，全部换完后切回 tachyon server。

## 实现要点

- 请求转换：方法、`rawPath` + `rawQuery`、Host、全部头、body（按 `bodySize` 读全）
- 响应回写：状态码、除 `Content-Length` 外的所有头、body
  （`Content-Length` 交给 stdx 自己算，重复设置会产生非法响应）
- `fromStd` 执行后会调用 `markHandledByAdapter()`，外层不再用快照覆盖响应
- `Router.handleWith(ctx, prebuilt)`：复用外部构造的 `TangHttpContext`，
  适配器才能把 stdx 上下文挂上去（见 `setCompatContext`）

## 边界

- `fromStd` 只在 `serve` / `serveAsync` 下可用；在 tachyon server 上会明确抛异常，
  不会静默降级
- 本模块**依赖 stdx**（这正是它的职责），tang core 依然零 stdx
