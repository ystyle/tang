# tang 零 stdx 化：工作空间拆分方案

> 状态：设计稿（2026-11-08）
> 前置：HTTP 层已切到 tachyon（分支 `feat/tachyon-backend`），当前 tang 仍是单包，
> 仅 `stdx.net.http` 已清零，其余 stdx 依赖（crypto / json / log / encoding）仍在。

## 1. 两个实测结论（决定方案形态）

### 1.1 `extend` 跨包不可见 —— 扩展模块加不了"方法"

```
包 b：extend Ctx { public func hello(): String { ... } }
包 main：import b.*; c.hello()     // 编译错误：'hello' is not a member of class 'Ctx'
```

仓颉的扩展成员只在**声明它的包内**可见。这意味着：**把能力拆到扩展成员后，
`ctx.json(...)` / `ctx.bindJson()` 这类方法风格 API 无法保留**，只能变成
`json.encode(ctx, v)` 这种函数式调用，或者在 core 里保留方法并要求接口定义在 core。

### 1.2 `std.reflect` 可用 —— JSON 不一定要绑定接口

```cangjie
let ti = TypeInfo.of(u)                       // struct / class 均可
case st: StructTypeInfo =>
    for (f in st.instanceVariables) {
        let v = f.getValue(u)                 // 读值，可 match 下转型
        // -> "field name type=String value=alice"
    }
    st.getInstanceVariable("age").setValue(u, 42)   // 也能写
```

即：**可以用反射直接枚举类型成员来做 JSON 编解码，用户类型不需要实现任何接口。**

## 2. 现状分类（src 实测行数）

| 类别 | 文件 | 行数 |
|---|---|---:|
| **零 stdx** | banner/config/context_*/group/path/radix/*/router/tang + 13 个中间件（basicauth, bodylimit, cache, cors, exception, favicon, healthcheck, keyauth, ratelimit, redirect, requestid, rewrite, security, timeout） | **≈ 3900** |
| **crypto**（digest/crypto/hex/base64） | csrf 320, encryptcookie 304, etag 173, idempotency 331, session 346 | **≈ 1474** |
| **json** | request.cj 内的 bindJson / json / jsonWithCode / bindQuery | **≈ 120** |
| **log** | log/log.cj 40, accesslog 182 | 222（可自写零依赖） |
| **encoding.url/base64** | request.cj 少量（compat 已接管大半） | 小 |

## 3. 建议的工作空间布局

```
tang/                         [workspace] 根：不含任何 stdx
  tang/                       核心，零 stdx —— 依赖 ystyle::tachyon
    src/                      router + radix + ctx + 13 个零依赖中间件
  tang_ext_crypto/            csrf / session / encryptcookie / etag / idempotency
                                （stdx.crypto.digest / crypto / encoding.hex|base64）
  tang_ext_json/              json 绑定（若走方案 A/B）
  tang_ext_log/               accesslog（或自写，零依赖）
  tang_ext_static/            静态文件（tachyon FileServer）
  tang_ext_proxy/             proxy
  tang_ext_ws/                WebSocket（tachyon hijack）
```

收益：只依赖 `tang` 的用户**完全不需要配置 `CANGJIE_STDX_PATH`**；
需要哪块能力再引入对应成员，与 tachyon 扩展成员是同一套思路。

## 4. JSON 的三条路（核心分歧）

| 方案 | core 是否零 stdx | 用户接口是否要改 | `ctx.json(v)` 方法是否保留 | 备注 |
|---|---|---|---|---|
| **A. json 进 ext（stdx json.stream）** | ✅ | ❌ 不改 | ❌ 变函数式 `json.encode(ctx, v)` | 最简单，跟随 stdx 新主推 |
| **B. core 自定义 JSON 接口** | ✅ | ✅ 要改（实现 tang 的接口） | ✅ 保留 | 破坏性变更 |
| **C. core 反射实现 JSON** | ✅ | ❌ **完全不用实现**（连泛型约束都没有） | ✅ 保留 | 反射性能待测；需覆盖嵌套/集合/Option/enum |

方案 C 把「JSON 必须依赖接口」这个前提绕过去了 —— 因为反射能直接读成员。
代价是序列化比手写慢（预计 2–5 倍，待实测），换来零依赖 + 零迁移。

## 5. 建议落地顺序

1. **先拆 crypto**：把 csrf/session/encryptcookie/etag/idempotency 移到 `tang_ext_crypto`，
   core 里仅保留接口/注册点（这些中间件本来就要显式 `use()`，迁移成本低）。
2. **log 自写**：一个 40 行的零依赖 logger 替掉 stdx.log，accesslog 跟着换。
3. **JSON 选 C 起步**：core 用反射实现 `ctx.json` / `ctx.bindJson`，
   同时保留 `tang_ext_json`（json.stream 快速路径）供性能敏感场景；
   两者接口一致，可切换。
4. **static / proxy / ws** 放扩展成员：static 用 tachyon FileServer，
   ws 用 hijack，proxy 需要 HTTP 客户端（tachyon 无客户端，可等 tachyon_ext 或保留 stdx）。

## 6. 迁移影响面

- 包路径变化：`tang.middleware.csrf` → `tang.ext.crypto.csrf` 等（用户 import 要改）
- 方法风格 API：只有 JSON 受影响（走方案 C 则可保住）
- 需提供一份 `MIGRATION.md`，列 old → new 的 import 对照
