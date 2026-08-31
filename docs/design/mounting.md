# tang × stdx.http 互相挂载方案（讨论稿）

> 状态：**已定稿并实施（feat/mounting 分支）** · 作者：ystyle · 2026-03
>
> 本文档梳理 tang 与 stdx.http 之间的挂载关系，按议题逐个讨论，每个议题给出
> 【现状】【问题】【候选方案】【推荐】【待讨论点】，确认一个落地一个。

## 讨论进度总览

| 议题 | 状态 | 结论摘要 |
|---|---|---|
| 1. 补全 `Router.register()` | ✅ 已定 | 恢复实现，`all()` 语义（radix tree 已有 `*` 兜底，`getWithFallBack` 现成支持）；路径支持 `:param`/`*`；不影响 405 |
| 2. 统一反向适配器 `fromStd` | ✅ 已定 | 3 旧函数直接删 → `fromStd` 两重载；`getHttpContext()` 删 → `public prop context`；`ctx.upgrade()` 保留 |
| 3. `listen(builder)` 透传 | ✅ 已定 | 单个 listen 回调（build 前拿 ServerBuilder）+ `setLogLevel` 独立字段，不做 with 选项 |
| 4. 挂进已有 Server | ✅ 已定 | 4A `tang.compose.ComposeDistributor`（最长前缀优先）+ 4B Fiber 风格 `Router.mount(prefix, router)`（注册展开）都做；放弃 toStdHandler |
| 5. Server 生命周期/多 Server | ⏸ 可选 | 本期可不做 |

---

## 0. 背景与现状

### 0.1 stdx.http 提供的官方挂载点（cangjie-docs 确认）

| 挂载点 | 签名 | 说明 |
|---|---|---|
| `HttpRequestDistributor` | `register(path, handler)` ×2<br>`distribute(path) → HttpRequestHandler` | Server 按 path 分发请求的**唯一主挂载点** |
| `HttpRequestHandler` | `handle(ctx: HttpContext)` | 一切 handler 的统一形态 |
| `FuncHandler` | 函数 → `HttpRequestHandler` | 函数式 handler 包装类 |
| 便捷 Handler 类 | `NotFoundHandler` / `RedirectHandler` / `FileHandler` / `OptionsHandler` | 官方预制能力，均为 `HttpRequestHandler` 子类型 |
| `ServerBuilder.distributor()` | `distributor(distributor)` | 把自定义分发器挂到 Server |
| `ServerBuilder` 高级配置 | `tlsConfig` / `readTimeout` / `servicePoolConfig` / HTTP2 settings / `onShutdown` / `afterBind` | tang 目前未透传 |
| `WebSocket.upgradeFromServer(ctx, ...)` | — | WebSocket 升级 |
| `HttpContext` | `request` / `responseBuilder` / `clientCertificate` / `isClosed()` | handler 拿到的全部能力 |

### 0.2 tang 现状

- **正向挂载（tang → stdx）**：`Router <: HttpRequestDistributor`，
  `Tang.listen()` 中 `ServerBuilder().distributor(this.router)`，
  `distribute()` 内把 stdx `HttpContext` 包装成 `TangHttpContext` 后走 radix tree + 中间件链。✅ 主链路通。
- **反向挂载（stdx → tang）**：3 个重复且命名混乱的转换函数：
  - `httpHandlerFunc(handle: FuncHandler)`（`request.cj:20`）
  - `withStdHandlr(fn: (HttpContext) -> Unit)`（`config.cj:56`，拼写错误 "Handlr"）
  - `withStdFunHandlr(handler: FuncHandler)`（`config.cj:62`，拼写错误）
- 另有 `ctx.getHttpContext()`、`ctx.upgrade()`（WebSocket）、`ctx.download()`（FileHandler 包装）、
  staticfile 中间件内部直接 new `FileHandler`。

### 0.3 生态参考（其他项目的实践）

- **mcp-cj**：`registerRoutes(distributor)` 注册到任意 stdx Server；`asHandler(): HttpRequestHandler` 供合并分发。
- **cjxt**：路由注册进 tang，`router(): HttpRequestDistributor` 把 tang Router 暴露给外部组合（指向 chronomem ComposeDistributor 思路）。
- **chronomem**：`transport.registerRoutes(httpServer.distributor)` 直接挂默认 distributor。

> 结论：多服务合并单端口是刚需，生态都在 stdx 的两个接口（distributor / handler）上做文章。
> tang 应把这两个方向的挂载都做成**一等公民**，以官方接口为唯一挂载协议。

---

## 议题 1：补全 `Router.register()` —— 修复接口契约破坏

### 现状与历史证据（git 追溯结论）

```cj
// router.cj:36 —— 参数连名字都没取
public func register(path: String, _: HttpRequestHandler): Unit {
    getLogger().info("It is not recommended to use the register method to register the handler: ${path}")
}
```

1. **这是重构遗漏而非设计决策**：bunrouter 时代（0.56.3 分支）`register()` 有**完整实现**——
   注册 GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS 七个方法（`handler.handle(ctx.context)` 包装成 HandlerFunc 后逐个注册）。
   `cfd0caa 实现 Radix Tree 路由系统` 重构时退化成空壳日志（参数名都没取 `_`），旧实现可直接恢复。
2. 目前 `register()` 在 tang 仓库内外**零调用**（契约要求但无人敢用，因为它是空壳）。

### 问题

`register()` 是 `HttpRequestDistributor` 接口的成员，**实现接口必须遵循契约**（注册 handler）。
现在任何按 stdx 风格 `distributor.register("/path", handler)` 的代码挂到 tang 上会**静默失效**，只剩一条日志。
这是隐藏地雷：tang 的 Router 无法无差别替换 stdx 默认 distributor。

### 候选方案

**1A（推荐）：恢复 bunrouter 时代完整实现，按 stdx 语义映射到 all()**

stdx 的 `register(path, handler)` 是**路径级**注册（不区分 method），对应 tang 的 `all()`。
比旧实现（7 个方法逐个注册）更简洁，语义等价：

```cj
public func register(path: String, handler: HttpRequestHandler): Unit {
    this._group.handle("*", path, fromStd(handler))   // fromStd 见议题 2
}

public func register(path: String, handler: (HttpContext) -> Unit): Unit {
    this.register(path, FuncHandler(handler))
}
```

> 注：`fromStd(handler)` 转换后走 `Group.wrap`，注册的 handler 自动享受所在 group 的中间件链。

**1B：register 只支持精确路径，走 group.handle("GET", ...)**
不符合 stdx "路径级"语义，会漏掉 POST 等其它方法。❌

### 结论（本次讨论定稿）

- **radix tree 的 `all` 支持是现成的**（`router_tree.cj`）：`MethodHandlers` 有专门 `all` 字段，
  `set("*", handler)` 存入；`getWithFallBack(method)` 实现"具体方法优先、`all` 兜底"；
  `searchRoute` 全程用 `getWithFallBack` 判定节点命中。
  故 `register()` 用 `all()` 语义在 radix tree 层面天然成立，与 stdx register 的
  "路径级、不区分 method"语义完全一致。
- **待讨论点结论**：
  1. register 路径支持 `:param` / `*` 语法 ✅（走同一条 `insertRoute`，pattern 照常进 Static/Param/Wildcard 分类）
  2. 注册到 `all()` 不影响 405 ✅（该路径对任意方法都命中 `all`，不存在"路径对、方法错"）
- **附带发现（独立问题，另行处理）**：tang 目前没有真正的 405 逻辑——`methodNotAllowedHandler`
  只配置未使用（lookup 中路径匹配方法不匹配时直接走 404）。不在本议题处理，记入待办。

---

## 议题 2：统一反向挂载适配器 `fromStd`

### 现状

3 个重复函数，命名混乱、有拼写错误、覆盖面不全（`withStdHandlr` 接不了对象式 handler）：

```cj
// request.cj:20
public func httpHandlerFunc(handle: FuncHandler): HandlerFunc
// config.cj:56
public func withStdHandlr(fn: (HttpContext) -> Unit): HandlerFunc      // 拼写错误
// config.cj:62
public func withStdFunHandlr(handler: FuncHandler): HandlerFunc        // 拼写错误
```

### 历史证据（git 追溯结论）

1. **三个函数全部是死代码**：`httpHandlerFunc` / `withStdHandlr` / `withStdFunHandlr`
   从引入至今（含 examples、middleware、工作区其它项目 cjxt 等）**零调用点**。
   它们是 0.56.3（bunrouter 时代 `79730a8 调整api`）与 `e914e1c 适配新的http库` 时加的"试验品"，
   从未被任何真实代码使用。
2. **真实被使用的"反向挂载"路径是 `ctx.upgrade()`（WebSocket）**：cjxt 的 upgradeWS
   即 `ctx.upgrade()` 用法（`tangApp.get(".../ws", { ctx => this.upgradeWS(ctx) })`）。
   而 `ctx.getHttpContext()` 与 internal 字段 `context` 语义重复，**全工作区零调用**
   ——应改为 `public prop context`（见结论）。
3. **`context` 从未是 prop（非重构丢失）**：遍历所有改过 `request.cj` 的提交
   （`e914e1c 适配http库` → `68ec5f6`），`context` 字段在所有版本都是 `let context: HttpContext`（internal），
   历史上不存在 `public prop context`。与 `register()` 的"重构搞没"不同，这是历史遗留的 internal 字段 + 补丁式 getter。

### 候选方案

**2A（推荐）：收敛为 `fromStd` 两个重载，放 request.cj**

```cj
/// 把 stdx 函数式 handler（方法形态）转成 tang handler
public func fromStd(fn: (HttpContext) -> Unit): HandlerFunc {
    { ctx => fn(ctx.context) }
}

/// 把任意 stdx HttpRequestHandler（类形态：FuncHandler/FileHandler/NotFoundHandler/...）转成 tang handler
public func fromStd(handler: HttpRequestHandler): HandlerFunc {
    { ctx => handler.handle(ctx.context) }
}
```

**直接删除** `httpHandlerFunc` / `withStdHandlr` / `withStdFunHandlr`
（三个函数零调用、拼写错误、命名不清，tang 是个人产品 1.x 内直接删，不 deprecate；
同步清理文档与示例中的引用）。

关键收益：转成 `HandlerFunc` 后自动走 `Group.wrap`，**stdx handler 挂进 tang 即享受中间件链**。

用法示例：

```cj
app.get("/files/*", fromStd(FileHandler("./public", handlerType: FileHandlerType.DownLoad)))
app.get("/mcp", fromStd(mcpTransport.asHandler()))
app.use(fromStd(OptionsHandler()))
```

**2B：不合并，只修拼写** —— 保留三函数但改名。重复 API 依旧混乱。❌

### 结论（本次讨论定稿）

按使用方法（真实调用点）判定的保留清单：

| API | 判定 | 依据 |
|---|---|---|
| `httpHandlerFunc` | ❌ 删 | 与 `withStdFunHandlr` 纯重复，零调用 |
| `withStdHandlr` | ❌ 删（函数式形态并入 `fromStd(fn)`） | 零调用，拼写错误 |
| `withStdFunHandlr` | ❌ 删（对象式形态并入 `fromStd(handler)`） | 零调用，拼写错误 |
| `fromStd(fn)` / `fromStd(handler)` | ✅ 新增（继承两个形态） | 转换能力是刚需（FileHandler / MCP asHandler 挂进 tang 路由） |
| `register(path, handler)` | ✅ 恢复 bunrouter 时代的完整实现 | 重构遗漏，契约要求（见议题 1） |
| `ctx.getHttpContext()` | ❌ 删（改为 `public prop context`，内部字段改名 `_context`） | 与 internal 字段 `context` 语义重复，全工作区零调用；按现有 `request`/`responseBuilder` prop 风格统一 |
| `ctx.upgrade()` | ✅ 保留 | cjxt 真实使用（upgradeWS） |

`context` prop 化精确改动（全部在 request.cj 内，外部调用零改动）：

```cj
public class TangHttpContext {
    ...
    let _context: HttpContext                      // ① 字段改名（prop 不能与字段同名）
    init(context: HttpContext, params: Params) {
        this._context = context                    // ② init 赋值改
        this._params = params
    }
    /// 底层 stdx HttpContext（WebSocket upgrade、协议级操作等高级能力）
    public prop context: HttpContext {             // ③ 新增 public prop
        get() {
            this._context
        }
    }
    // ④ 删除 getHttpContext()；upgrade() 内 this.context → this._context；
    //    三个透传 prop（request/responseBuilder/clientCertificate）内部同步改
}
```

### 待讨论点

> 命名已定稿：`fromStd`（转换方向明确、与 From 惯例一致，2026-03 讨论确认）。
> 无剩余待讨论点。

---

## 议题 3：`Tang.listen()` 透传 ServerBuilder 配置

### 现状

```cj
// tang.cj:82 —— 硬编码
let server = ServerBuilder()
    .distributor(this.router)
    .addr(this.host)
    .port(this.port)
    .build()
server.logger.level = LogLevel.ERROR
```

TLS、超时、协程池、HTTP/2 参数、`afterBind` 等 ServerBuilder 能力**全部用不上**（tang 开不了 HTTPS）。

### 候选方案

**3A（推荐）：listen 增加 builder 钩子重载**

```cj
public func listen(builder: (ServerBuilder) -> Unit): Unit {
    let sb = ServerBuilder().distributor(this.router).addr(this.host).port(this.port)
    builder(sb)                 // 用户可配 tlsConfig / readTimeout / servicePoolConfig / ...
    let server = sb.build()
    ...
}

// 用法
app.listen({ sb => sb.tlsConfig(tlsCfg).readTimeout(5 * Second) })
```

**3B：走 TangOption**（`withServerBuilder(...)` 选项）
与 `listen` 钩子等价，但选项数组适合"声明式配置"，listen 钩子适合"过程式"。可两者都要（listen 钩子内部也是先应用选项再应用钩子）。见待讨论点。

### 结论（本次讨论定稿）

**单个 listen 回调（build 前）+ logger level 独立字段，不做 with 选项**：

```cj
public class Tang {
    var logLevel: LogLevel = LogLevel.ERROR   // ① 公开可配字段，默认安静（压 stdx 连接噪音）

    public func listen(builder: (ServerBuilder) -> Unit): Unit {
        let sb = ServerBuilder().distributor(this.router).addr(this.host).port(this.port)
        builder(sb)                             // ② build 前钩子：TLS/超时/协程池/HTTP2
        let server = sb.build()
        server.logger.level = this.logLevel     // ③ 用字段而非硬编码，用户可改
        ...
    }
    public func setLogLevel(level: LogLevel): Tang { ... }   // ④ 便捷 setter
}
```

**决策依据**：
- **回调放 build 前（拿 ServerBuilder）**：TLS/超时等必须在 build 前配置；
  build 后需求（logger level / onShutdown）由公开字段（setLogLevel）与现有 `app.onShutdown()` 覆盖，
  不需要 build 后回调。
- **不做 with 选项**：TangOption 是构造期配置而 Server 是 listen 期构建，配置生效延迟；
  与 listen 回调重复，两个机制解决同一件事无增量价值；也避免"选项 vs 回调谁覆盖谁"的顺序问题。
- **logger level 独立字段而非回调配置**：回调里 `sb.logger(...)` 会被 tang 内部
  `server.logger.level = ...` 默认设置覆盖（ServerBuilder 无法查询用户是否配过 logger），
  独立字段 build 后统一设置，天然无冲突。
- **默认 ERROR 保留**：压掉 stdx 的 `Socket is closed`/`Broken pipe` 噪音（chronomem 同款做法），
  需要日志的用户显式 setLogLevel 打开。
- 补充事实：`ServerBuilder` 是 stdx.net.http 的公开类，配置方法链式返回自身，`build()` 返回 `Server`；
  `Logger` 是抽象类，`getGlobalLogger()` 拿默认实现、`NoopLogger` 为空实现，`Logger.level` 为 mut prop。

---

## 议题 4：把 tang 挂进已有 Server —— `toStdHandler` 的替代方案 ⭐重点

### 原方案（上一版讨论稿）：`Router.toStdHandler(prefix)`

```cj
public func toStdHandler(prefix!: String = "/"): HttpRequestHandler {
    FuncHandler({ ctx =>
        let path = ctx.request.url.rawPath
        this.distribute(path).handle(ctx)
    })
}
```

用法：`server.distributor.register("/api", app.getRouter().toStdHandler("/api"))`

### 为什么这个方案不好（三个硬伤）

1. **依赖未知的默认 distributor 匹配语义**：stdx 文档未说明默认 distributor 的 `register(path, ...)`
   是**精确匹配**还是**前缀匹配**（cangjie-docs 接口文档无此说明，本地 stdx 又只有编译产物）。
   若是精确匹配，注册 `/api` 只命中 `/api` 本身，`/api/users` 全部 404 —— toStdHandler 形同虚设。
2. **前缀剥离破坏 tang 内部语义**：tang 注册的是完整路径（`/api/users/:id`，group 语义如此）。
   外部传入完整路径时不能剥前缀；一旦需要剥，路径参数、404、中间件语义全部错位。两头不讨好。
3. **tang 被降级为单个 handler**：失去 distributor 身份，无法参与"多个服务组合分发"的平等协作，
   404 兜底、匹配顺序等语义割裂。

### 更好的方案

#### 4A（推荐）：`ComposeDistributor` —— 组合分发器，tang 以完整 distributor 身份挂载

思路：stdx 的挂载协议是 `HttpRequestDistributor`。tang 已经是完整 distributor，
与其降级成 handler，不如提供一个**组合分发器**，把多个完整 distributor 按前缀组合，
**路径不剥离**，tang 内部原样工作（参数、404、中间件全部保留）。

```cj
package tang.compose

import std.collection.ArrayList
import stdx.net.http.{HttpRequestDistributor, HttpRequestHandler, FuncHandler, NotFoundHandler}

/// 组合分发器：按路径前缀把请求委派给多个子分发器（最长前缀优先）
public class ComposeDistributor <: HttpRequestDistributor {
    var mounts: ArrayList<(String, HttpRequestDistributor)> = ArrayList()
    var fallback: HttpRequestDistributor = NotFoundDistributor()   // 默认 404

    public func mount(prefix: String, distributor: HttpRequestDistributor): ComposeDistributor {
        this.mounts.add((prefix, distributor))
        this
    }

    public func setFallback(distributor: HttpRequestDistributor): ComposeDistributor {
        this.fallback = distributor
        this
    }

    public func register(path: String, handler: HttpRequestHandler): Unit {
        this.fallback.register(path, handler)   // 组合层不收 handler，转发给 fallback
    }

    public func register(path: String, handler: (HttpContext) -> Unit): Unit {
        this.fallback.register(path, FuncHandler(handler))
    }

    public func distribute(path: String): HttpRequestHandler {
        var best: ?(String, HttpRequestDistributor) = None
        for (m in this.mounts) {
            let prefix = m[0]
            if (path == prefix || path.startsWith("${prefix}/")) {
                if (let None <- best || prefix.size > best.getOrThrow()[0].size) {
                    best = Some(m)          // 最长前缀优先
                }
            }
        }
        if (let Some((_, d)) <- best) {
            return d.distribute(path)
        }
        return this.fallback.distribute(path)
    }
}
```

使用场景（多服务合并单端口）：

```cj
let compose = ComposeDistributor()
    .mount("/api", tangApp.getRouter())     // tang 处理 /api/*（注册的就是完整路径）
    .mount("/mcp", mcpTransport)            // MCP 处理 /mcp/*
    .setFallback(tangApp2.getRouter())      // 其余路径走另一个 tang

let server = ServerBuilder().distributor(compose).build()
server.serve()
```

关键点：
- **路径不剥离**：挂载时注册的路径就是完整路径，tang 的 group 语义天然一致。
- **可嵌套**：ComposeDistributor 自身也是 `HttpRequestDistributor`，可再被组合。
- **不依赖 stdx 默认 distributor 的匹配语义**，匹配逻辑完全由组合层控制。

#### 4B（定稿）：`Router.mount(prefix, router)` —— Fiber 风格 tang 子应用挂载

**注册展开**（挂载时把子 Router 的 handlers 重注册到父 Router，Fiber 的 `app.Mount` 同款语义）：

```cj
// Router.mount —— 子 Router 挂到父 Router
public func mount(prefix: String, router: Router): Unit {
    for ((key, handler) in router.handlers) {
        // key 格式 "METHOD:pattern"（router.cj 的存储格式，* 表示 all()）
        let idx = key.indexOf(":")
        let method = key[..idx]
        let pattern = key[idx + 1..]
        this._group.handle(method, prefix + pattern, handler)
    }
}

// Tang.mount —— 代理到 Router
public func mount(prefix: String, router: Router): Tang {
    this.router.mount(prefix, router)
    this
}
```

用法（tang<->tang 互相挂）：
```cj
let app = Tang()
let subApp = Tang()
subApp.get("/users/:id", { ctx => ctx.json(...) })
app.mount("/api", subApp.getRouter())   // 实际路径 /api/users/:id
app.listen()
```

**关键点**：
- **子 Router 的中间件链原样保留**（group stack 已 wrap 进 HandlerFunc，重注册时直接带走）
- **路径参数/通配符照常**（走父 Router 同一条 radix tree）
- **快照语义**（mount 后子 Router 新增路由不生效，Fiber 同款）
- 子 Router 的 404 由父 Router 兜底（Fiber 同款行为）
- 与 4A 区别：4A 是平级组合（tang 不一定为主），4B 是 tang 为主体挂子应用
- **与 fromStd 分工**：`fromStd` 挂任意 stdx handler/外部 distributor（MCP/FileHandler）；
  `mount` 挂 tang 子应用（Router 到 Router，注册展开）。两者并存，各司其职。

#### 4C（对比，不新增代码）：反向挂载解决部分场景

"已有 Server"如果其实就是"将要新建的 Server"，那根本不需要组合——
tang 作为主分发器，其他服务用 `fromStd`（议题 2）挂进 tang 路由即可：

```cj
app.get("/mcp", fromStd(mcpTransport.asHandler()))
app.listen()   // tang 自起 Server，单分发器
```

这只覆盖"tang 为唯一分发器"的场景，覆盖不了"已有/共享 stdx Server"。

### 对比

| 方案 | 场景 | 路径语义 | 依赖默认 distributor 匹配 | 复杂度 |
|---|---|---|---|---|
| ~~toStdHandler~~ | 单路径挂载 | 剥离/不剥都别扭 | **是（致命）** | 低 |
| **4A ComposeDistributor** | 多框架共享端口，平级组合 | 不剥离，完整路径 | 否 | 中 |
| **4B Router.mount** | tang 为主体，挂 tang 子应用 | 不剥离，完整路径（注册展开） | 否 | 低 |
| 4C 反向挂载 | tang 为唯一分发器 | — | 否 | 无 |

### 结论（本次讨论定稿）

- **4A 与 4B 都做**。
- **4A `ComposeDistributor` 放 tang 包内（`tang.compose`）**：官方 stdx.http 无任何合成/组合/multi 类
  （完整类清单确认，唯一组合点是 `HttpRequestDistributor` 接口，官方不给实现），
  生态里 chronomem 也是自写 ComposeDistributor；独立小包无价值，放 tang 开箱即用。
- **匹配策略：前缀归属 + 最长前缀优先**。ComposeDistributor 只决定"哪个前缀归谁"，
  子 distributor 内部优先级（tang 的 radix tree 静态>参数>通配符）由自己管；fallback 兜底；
  重叠前缀取最长。
- **前缀边界：`path == prefix || path.startsWith(prefix + "/")`**，天然不匹配 `/apix`，
  不引入 radix tree（mount 数量个位数，线性扫描足够；radix tree 的 pattern 分段存储反而绕）。
- **4B 改为 Fiber 风格 `Router.mount(prefix, router)`**（注册展开），不再做通用的
  `mount(prefix, distributor)`（那个场景用 fromStd 包装即可）。
- **放弃 toStdHandler**；4C 是 fromStd 现状能力，无新代码。

---

## 议题 5（可选）：Server 生命周期与多 Server 管理

### 现状

`Tang` 只持有一个 `server: Option<Server>`，`getStdServer()` 返回它。

### 候选方向

- **5A**：`Tang.attach(server: Server)` —— 外部已构建的 Server 交给 tang 管理
  （stop / onShutdown 统一处理），分发仍走 tang Router。
  （价值弱：用户可直接持引用操作，本期不做。）
- **5B**：HTTP + HTTPS 双 Server 共享同一 Router。
  候选实现 `listenMulti(...)`：传多个端口 + 各自的 builder 回调，
  tang 用同一 Router 分别 build 多个 Server 并统一管理：

  ```cj
  public func listenMulti(ports: Array<UInt16>, builders: Array<(ServerBuilder) -> Unit>): Unit {
      for (i in 0..ports.size) {
          let sb = ServerBuilder().distributor(this.router).addr(this.host).port(ports[i])
          builders[i](sb)          // 80 端口给 redirect builder，443 给 tlsConfig builder
          // build + serve（spawn）+ 记录到 servers 列表统一 stop/onShutdown
      }
  }
  ```
  与议题 4 维度正交（多端口 vs 单端口多服务）。依赖议题 3 的 builder 钩子形态。

> **状态：本期不做，先记录**。5B 真实需求（HTTP+HTTPS 双开），但优先级低于议题 1-4；
> 议题 3（`listen(builder)` 透传 TLS）落地后重新评估——届时 listenMulti 可复用同一 builder 钩子形态。

---

## 实施顺序建议（TDD，每步带单元测试）

**第一步（议题 2，独立可交付）：反向挂载统一**
1. 新增 `fromStd(fn)` / `fromStd(handler)` 两个重载 + 测试
   （FileHandler / NotFoundHandler / 函数式挂进 tang 路由，且走中间件链）
2. 删除 `httpHandlerFunc` / `withStdHandlr` / `withStdFunHandlr` + 测试
   （确认无残留引用，编译通过）
3. `context` prop 化（字段改名 `_context` + `public prop context`，删 `getHttpContext()`）+ 测试
   （包外 `ctx.context` 可用；`upgrade()` 不受影响）

**第二步（议题 1）：补全 `Router.register()`** + 测试
（stdx 风格 register 后能走 tang 路由，GET/POST 等全方法生效，路径参数可用）

**第三步（议题 3）：`listen(builder)` 钩子** + 测试（builder 被调用、logger 配置可覆盖）

**第四步（议题 4A）：`tang.compose.ComposeDistributor`** + 测试
（前缀委派、最长前缀优先、fallback 兜底、段边界 `/api` 不匹配 `/apix`）

**第五步（议题 4B）：`Router.mount(prefix, router)`** + 测试
（注册展开、子 Router 中间件保留、路径参数、快照语义）

**第六步（议题 5，可选）：Server 生命周期/双 Server**

---

## 变更记录

- 2026-03：初稿。议题 4 由 toStdHandler 改为 ComposeDistributor 主推方案。
- 2026-03：议题 1、2 讨论定稿——
  - git 追溯确认：三个反向适配函数（`httpHandlerFunc`/`withStdHandlr`/`withStdFunHandlr`）与
    `getHttpContext()` 均零调用；`register()` 完整实现在 `cfd0caa`（Radix Tree 重构）时被删成空壳（重构遗漏）；
    `context` 字段从未是 prop（非重构丢失）。
  - 结论：3 旧函数直接删 → `fromStd` 两重载；`register()` 恢复（all 语义）；`getHttpContext()` 删 → `public prop context`；
    `ctx.upgrade()` 保留。文档头部新增讨论进度总览。
- 2026-03：议题 3、4 讨论定稿——
  - 议题 3：单个 listen 回调（build 前拿 ServerBuilder）+ `setLogLevel` 独立字段，不做 with 选项；
    logger 独立字段避免"回调配置被默认 ERROR 覆盖"的坑。
  - 议题 4：4A `tang.compose.ComposeDistributor` 与 4B Fiber 风格 `Router.mount(prefix, router)`
    （注册展开）都做。官方 stdx.http 确认无合成/组合/multi 类；
    前缀边界用段边界 `startsWith(prefix + "/")` 解决，不引入 radix tree；
    mount 语义为前缀归属 + 最长前缀优先，子 distributor 内部优先级自管。
  - 议题 5：确认本期不做。5B 候选实现 `listenMulti(ports, builders)`（多端口共享 Router，
    复用议题 3 的 builder 钩子形态），议题 3 落地后重新评估。
- 2026-03：**全部实施完成（feat/mounting 分支，24 个测试通过）**——
  - 议题 2：`fromStd` 两重载（65a2429）、删 3 废弃函数（00ae500）、`context` prop 化（dd5f4f2）
  - 议题 1：`Router.register()` 恢复（8e95a1b）
  - 议题 3：`listen(builder)` + `setLogLevel`（144f8c5）
  - 议题 4A：`tang.compose.ComposeDistributor` + `startTestServer(HttpRequestDistributor)` 重载
  - 议题 4B：`Router.mount(prefix, router)` + `Tang.mount` 代理（b7a1a72）
