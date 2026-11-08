# ComposeRouter — 按前缀组合多个子系统

`Router.mount()` 是**注册展开**（把子路由逐条注册进父 Router，中间件在注册时固定）；
`ComposeRouter` 是**运行时委派**（子 Router 保持独立，各自的路由表、中间件、404 语义完整保留）。

适合多个子系统共用一个端口，或把非 tang 的 handler 挂进来。

## 快速开始

```cj
import tang.*
import tang.compose.ComposeRouter

let app = Tang()

let api = Tang()
api.get("/api/users/:id", { ctx => ctx.writeString("user-" + ctx.param("id")) })

let mcp = Tang()
mcp.get("/mcp/health", { ctx => ctx.writeString("ok") })

let compose = ComposeRouter()
    .mount("/api", api.getRouter())
    .mount("/mcp", mcp.getRouter())
    .setFallback({ ctx => ctx.writeString("fallback") })
compose.install(app)   // 未命中 tang 自身路由的请求交给 compose

app.listen(8080u16)
```

## 语义

- **前缀不剥离**：子 Router 按完整路径注册（上例里 API 路由是 `/api/users/:id`）
- **段边界匹配**：`/api` 匹配 `/api`、`/api/users`，不匹配 `/apix`
- **最长前缀优先**：`/api/v1` 优先于 `/api`
- **fallback**：未命中任何前缀时使用，默认返回 404
- **可嵌套**：`mount` 也可以挂任意 handler（非 tang 子系统包一层即可）

## 与 `Router.mount()` 怎么选

| | `Router.mount()` | `ComposeRouter` |
|---|---|---|
| 机制 | 注册展开（启动时逐条注册） | 运行时委派 |
| 子 Router 独立性 | 中间件在注册时固定 | 完全独立，各自 404/中间件语义保留 |
| 路径 | 自动加前缀 | 子方自己写完整路径 |
| 适用 | 同一应用内拆子模块 | 多子系统 / 多框架共用端口 |
