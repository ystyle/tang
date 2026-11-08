# 与 stdx 互操作

## 概述

**本分支的 tang 核心不再构建在 `stdx.net.http` 之上**（HTTP 层是 tachyon，核心零 stdx）。
与 stdx 的互操作集中在独立成员 `tang_ext_stdx` 里。

完整用法见 [stdx 兼容层](../stdx-compat.md)，这里只列要点与「旧文档里那些 API 现在在哪」。

## 能力现状

| 旧能力（1.0.x） | 现在 | 说明 |
|---|---|---|
| `Router` 实现 `HttpRequestDistributor`，当 stdx Server 的分发器 | ❌ 不再提供 | 核心不认识 stdx 类型 |
| `fromStd(handler)` 把 stdx handler 挂进 tang 路由 | ✅ `tang_ext_stdx.fromStd` | 需要配合 `serve()`（跑在 stdx server 上） |
| `Router.register(path, stdxHandler)`（stdx 风格注册） | ❌ 不再提供 | 用 `fromStd` + tang 路由替代 |
| `ComposeDistributor` 多服务共享端口 | ❌ 不再提供 | 依赖 stdx distributor 协议；tang 侧用 `mount` 组合路由 |
| `ctx.context` 直接拿 stdx `HttpContext` | ✅ `ctx.compatContext()` | 仅在 `tang_ext_stdx.serve` 下非空，返回 `?Object` 需自行转型 |
| `Router.mount()` / `Tang.mount()` 子应用挂载 | ✅ 保留 | 纯 tang 侧能力，不涉及 stdx |

## 为什么方向变了

stdx 的 `HttpContext` **构造器是 internal**，外部无法伪造上下文。所以：

- 「把 stdx handler 塞进 tang 的 server」不可行 —— handler 拿不到 stdx 上下文
- 「把 tang 跑在 stdx 的 server 上」可行 —— tachyon 的 `RequestCtx` 可以用
  `DetachedRequest` 手工构造，tang 的路由与中间件原样跑

于是兼容层的形式是 `serve(app, host, port)` + `fromStd(handler)`。

## 示例

```cj
import tang.*
import tang_ext_stdx.*
import stdx.net.http.HttpContext

main() {
    let app = Tang()

    // tang 原生路由
    app.get("/hello", { ctx => ctx.writeString("hi") })

    // stdx 风格 handler（存量代码几乎不用改）
    app.get("/legacy", fromStd({ ctx: HttpContext =>
        ctx.responseBuilder.body("from stdx handler")
    }))

    serve(app, "0.0.0.0", 8080)   // 跑在 stdx 的 server 上
}
```

## 迁移建议

存量项目先 `serve` 起来，再逐个把 `fromStd` handler 改成 tang 写法，
全部改完切回 `app.listen()` 拿 tachyon 的性能收益。详见 [迁移指南](../MIGRATION.md)。
