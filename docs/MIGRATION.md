# 从 1.0.x 迁移到 tachyon 后端（本分支）

本分支把 HTTP 层从 `stdx.net.http` 换成 [tachyon](https://atomgit.com/ystyle/tachyon)，
同时把 tang 拆成 workspace 以做到**核心零 stdx**。以下是逐项对照。

> 已发布的 `tang 1.0.6` 不受影响；本分支完成后的大版本以 master 合并时的版本号为准。

## 一、依赖配置

**旧**

```toml
[dependencies]
  tang = "1.0.6"
```

外加环境变量 `CANGJIE_STDX_PATH`。

**新**

```toml
[dependencies]
  "tang" = { git = "https://github.com/ystyle/tang.git", branch = "feat/tachyon-backend" }
  # 按需追加
  "tang_ext_json_seajson" = { ... }   # 要用 ctx.json / JSON 绑定
  "tang_ext_crypto" = { ... }         # 要用 csrf / session / encryptcookie / etag / idempotency
  "tang_ext_stdx" = { ... }           # 存量 stdx handler 或要跑在 stdx server 上
```

- 只依赖核心：**不需要** `CANGJIE_STDX_PATH`
- 依赖扩展成员：仍需要（它们本来就是 stdx 能力）

## 二、API 对照

| 旧写法 | 新写法 | 说明 |
|---|---|---|
| `ctx.json(v)` | `ctx.json(v)` + 启动时 `useSeaJson()` | 核心不再内置 JSON 实现，走注册的 codec |
| `ctx.bindJson<T>()` | `tang_ext_json_seajson.bindJson<T>(ctx)` | 泛型约束落适配器，方法形式保留不了 |
| `ctx.bindQuery<T>(v)` （stdx.serialization） | `ctx.bindQuery<T>(v) where T <: QueryBindable` | 改为实现 core 的 `QueryBindable` 接口；旧的 datamodel 版不再提供 |
| `ctx.jsonWithCode(code, v)` | 同左（走 codec） | 行为一致 |
| `import tang.middleware.csrf.*` | `import tang_ext_crypto.csrf.*` | 加密类中间件整体搬到扩展成员 |
| `import tang.middleware.session.*` | `import tang_ext_crypto.session.*` | 同上 |
| `import tang.middleware.encryptcookie.*` | `import tang_ext_crypto.encryptcookie.*` | 同上 |
| `import tang.middleware.etag.*` | `import tang_ext_crypto.etag.*` | 同上 |
| `import tang.middleware.idempotency.*` | `import tang_ext_crypto.idempotency.*` | 同上 |
| `import tang.middleware.staticfile.*` | 不变 | 已用 tachyon `FileServer`（std.fs）重写，仍属核心 |
| `tang.log.LogLevel`（来自 stdx） | `import tang.log.LogLevel` | 自写日志门面，类型同名但归属 core |
| `stdx.log.LogValue` | `tang.log.LogValue` | 变成枚举：`VString/VInt/VFloat/VBool` |
| `setLogLevel(LogLevel.X)` | 不变 | `LogLevel` 现在来自 `tang.log` |
| `fromStd(fn)` | `tang_ext_stdx.fromStd(fn)` + `serve(app, host, port)` | 需要 stdx 的 server（stdx 上下文构造器 internal，见下） |
| `app.getRouter().register(path, stdxHandler)` | — | 不再提供；用 `fromStd` + tang 路由，或直接在 stdx server 上分发 |
| `ComposeDistributor` | `tang.compose.ComposeRouter` | 语义不变（最长前缀委派、fallback），但基于 tachyon RequestCtx；子 Router 仍按完整路径注册 |
| `app.getStdServer()` | `app.getStdServer()` 仍在 | 返回的已是 tachyon `Server`（类型变化） |
| `ctx.context`（底层 stdx HttpContext） | 核心无此字段 | stdx 兼容模式下用 `ctx.compatContext()` 取回 |
| `ctx.request.headers`（stdx HttpHeaders） | `ctx.request.headers`（`TCHeaders`） | `getFirst/add` 等同形，类型自研 |
| `ctx.responseBuilder` | 同左（`TCResponseBuilder`） | `status/header/body/build` 同形 |

## 三、行为变化（要注意的）

| 变化 | 影响 |
|---|---|
| **`writeString` 不再重置状态码** | 旧版 `ctx.status(400).writeString(...)` 实际返回 200，现在返回 400。依赖旧行为的地方要显式设 200 |
| **requestid 改为 `<启动秒>-<自增>`** | 格式变化，不再是 sonyflake 的 18 位数字；旧实现还有每 10ms 只能出 256 个 ID 的硬上限（≈2.5 万/秒） |
| **Cookie 类型换为 `tang.Cookie`** | 与 stdx Cookie 同形（name/value/path/domain/maxAge/httpOnly/secure/sameSite），构造器参数名一致 |
| **HTTP 状态码常量 `HttpStatusCode.*`** | 现在是 `UInt16` 常量（原来是 stdx 的类型），可直接传 `status(...)` |
| **WebSocket 升级** | 本分支暂未提供（`hijack` 能力在 tachyon 侧，待接） |
| **proxy 中间件** | 已回归核心：用自带极简 HTTP 客户端转发（零 stdx），只支持 http:// 上游，WebSocket 返回 426 |

## 四、迁移顺序建议

1. 改依赖与 import：核心 + 需要的扩展成员
2. 启动时注册 JSON codec（`useSeaJson()`）
3. 加密类中间件的 import 路径换成 `tang_ext_crypto.*`
4. `fromStd` 的存量 handler：换成 `tang_ext_stdx`，先 `serve()` 跑在 stdx server 上
5. 逐条把这些 handler 改成 tang 原生写法
6. 全部改完后切回 tachyon `app.listen()`，享受性能收益
7. 用 `tang.testing` 给关键路由补测试（不上网络，跑得快）

## 五、性能对照（同机实测）

| 后端 | QPS | p50 | p99 | 每请求 CPU |
|---|---:|---:|---:|---:|
| stdx.net.http | 256,800 / 244,994 | 410 / 430 µs | 1.99 / 2.07 ms | 27.5 / 28.6 µs |
| tachyon | **537,095 / 522,024** | 215 / 220 µs | **0.92 / 0.94 ms** | **12.3 / 12.7 µs** |

条件：同机 128 连接 20s，两轮；应用代码完全相同（`/hello` 返回固定字符串）。
