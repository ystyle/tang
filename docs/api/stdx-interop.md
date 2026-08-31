# 与 stdx.http 互操作

## 概述

Tang 构建在 [stdx.net.http](https://docs.cangjie-lang.cn/libs/stdx/net/http/) 之上，以官方接口为挂载协议，支持双向互操作：

- **正向（tang → stdx）**：`Router` 实现 `HttpRequestDistributor` 接口，作为 stdx `Server` 的分发器
- **反向（stdx → tang）**：`fromStd()` 把 stdx 的 handler 挂进 tang 路由
- **组合（多服务共享端口）**：`ComposeDistributor` 按前缀组合多个完整分发器
- **子应用（tang ↔ tang）**：`Router.mount()` / `Tang.mount()` 挂载子应用
- **上下文透传**：`ctx.context` 直接访问底层 `HttpContext`

## 正向挂载：Router 作为 HttpRequestDistributor

`Tang.listen()` 内部自动把 `Router` 作为 distributor 构建 stdx `Server`，无需手动配置。

### stdx 风格注册 register()

`Router` 实现了 `HttpRequestDistributor.register()`，可按 stdx 风格**路径级注册**（不区分 HTTP 方法）：

```cj
import stdx.net.http.{HttpContext}

let app = Tang()

// stdx 风格注册：GET/POST/PUT/DELETE 等所有方法都能命中
app.getRouter().register("/ping", { ctx: HttpContext =>
    ctx.responseBuilder.body("pong")
})

// 类式重载：任意 HttpRequestHandler
app.getRouter().register("/file", fromStd(FileHandler("./public", handlerType: FileHandlerType.DownLoad)))
```

- 注册路径支持 tang 的 `:param` / `*` 语法
- 注册后自动享受所在 group 的中间件链
- 路径级语义与 stdx 默认 distributor 一致，可无差别替换

### 接入已有 stdx Server

需要把 tang 挂进**已有**的 stdx Server 时，直接把 Router 作为 distributor：

```cj
let server = ServerBuilder().distributor(app.getRouter()).addr("127.0.0.1").port(8080).build()
server.serve()
```

## 反向挂载：fromStd()

把 stdx 的 handler 转成 tang 的 `HandlerFunc` 挂进 tang 路由。支持两种形态：

```cj
import tang.*
import stdx.net.http.{HttpContext, HttpRequestHandler}

// ① 函数式（方法形态）
app.get("/std-fn", fromStd({ ctx: HttpContext =>
    ctx.responseBuilder.body("hello from std fn")
}))

// ② 类式：任意实现了 HttpRequestHandler 的类型
app.get("/files/*", fromStd(FileHandler("./public", handlerType: FileHandlerType.DownLoad)))
app.get("/404", fromStd(NotFoundHandler()))
```

**关键收益**：转成 `HandlerFunc` 后自动走 `Group.wrap`，**stdx handler 挂进 tang 即享受中间件链**。

典型场景——MCP 服务合并进 tang：

```cj
app.get("/mcp", fromStd(mcpTransport.asHandler()))
```

## 组合分发器：ComposeDistributor

`tang.compose.ComposeDistributor` 把多个**完整分发器**按前缀组合，多框架共享一个端口。路径不剥离，子分发器内部语义（参数、404、中间件）完整保留。

```cj
import tang.compose.ComposeDistributor

let compose = ComposeDistributor()
    .mount("/api", app1.getRouter())      // tang 处理 /api/*（注册完整路径 /api/xxx）
    .mount("/mcp", mcpTransport)          // MCP 处理 /mcp/*
    .setFallback(app2.getRouter())        // 其余路径走兜底分发器（默认 404）

let server = ServerBuilder().distributor(compose).build()
server.serve()
```

匹配规则：

- **段边界**：`/api` 匹配 `/api`、`/api/users`，**不匹配** `/apix`
- **最长前缀优先**：`/api/v1` 的挂载优先于 `/api`
- **fallback 兜底**：未命中任何 mount 前缀时使用 `setFallback()` 设置的分发器，默认 404
- **可嵌套**：`ComposeDistributor` 自身也是 `HttpRequestDistributor`，可再被组合

## 子应用挂载：Router.mount / Tang.mount

Fiber 风格的 `app.Mount`，把子应用（Router）的路由以前缀注册到父应用（**注册展开**）：

```cj
let app = Tang()
let subApp = Tang()
subApp.get("/users/:id", { ctx => ctx.writeString("user-" + ctx.param("id")) })

app.mount("/api", subApp.getRouter())   // 实际路径 /api/users/:id
app.listen()
```

- **中间件保留**：子应用 mount 前注册的中间件原样生效
- **路径参数照常**：走父应用同一条 radix tree
- **快照语义**：mount 后子应用新增路由不生效（与 Fiber `app.Mount` 一致）
- **404 兜底**：子应用未命中的路径由父应用处理
- `Tang.mount()` 返回 `Tang`，可链式调用

## 上下文透传：ctx.context

`TangHttpContext.context` 是 `public prop`，直接返回底层 `stdx.net.http.HttpContext`，用于协议级高级操作（WebSocket 升级、socket 信息、`isClosed()` 检查等）：

```cj
app.get("/debug", { ctx =>
    let raw = ctx.context   // stdx HttpContext
    ctx.writeString(raw.request.method.toString())
})
```

WebSocket 升级推荐使用封装的 `ctx.upgrade()`，见 [WebSocket 升级](context/websocket.md)。

## 相关链接

- **[设计文档](../design/mounting.md)** - 挂载方案完整讨论与决策记录
- **[WebSocket 升级](context/websocket.md)** - 双向通信
- **[Router API](router.md)** - register / mount 完整参考
- **[Tang 应用](app.md)** - listen(builder) / setLogLevel / mount
