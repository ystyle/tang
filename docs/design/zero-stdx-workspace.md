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

## 4. JSON 的四条路（2026-11-08 更新：SeaJSON 改变了结论）

### 4.0 先看 SeaJSON（`seajson` v1.5.1，中心仓）

- **纯 std，零 stdx**（实测：源码 6450 行无任何 `import stdx`，`[dependencies]` 为空）
- 契约与 stdx 几乎一一对应：

| stdx `json.stream` | SeaJSON |
|---|---|
| `JsonSerializable.toJson(JsonWriter)` | `JsonEncodable.toJsonString(): String`（另有 `JsonWriterEncodable.writeJson(JsonWriter)` 流式） |
| `JsonDeserializable<T>.fromJson(JsonReader)` | `JsonDecodable<T>.fromJsonString(String): T` |

- 已实测跑通适配形态（`probe-seajson`）：
  ```
  core 接口 encode(obj: Any) + 运行时下转型 JsonEncodable → {"name":"alice","age":30}
  JsonDecodable<T>.fromJsonString → 反序列化正常
  ```
  即 **core 定义 `JsonCodec` 接口（收 `Any`），适配器在运行时 `match (obj) { case e: JsonEncodable => ... }`**，方法风格 `ctx.json(v)` 可以保留在 core。

→ **用 SeaJSON 适配器可以做到 tang 全链路零 stdx**，这不是"少一个依赖"的程度，而是把 JSON 这个最后的硬依赖换掉了。

## 4.1 四条路对比

| 方案 | core 是否零 stdx | 用户接口是否要改 | `ctx.json(v)` 方法是否保留 | 备注 |
|---|---|---|---|---|
| **A. json 进 ext（stdx json.stream）** | ✅ | ❌ 不改 | ❌ 变函数式 `json.encode(ctx, v)` | 最简单，跟随 stdx 新主推 |
| **B. core 自定义 JSON 接口** | ✅ | ✅ 要改（实现 tang 的接口） | ✅ 保留 | 破坏性变更 |
| **C. core 反射实现 JSON** | ✅ | ❌ 不用实现 | ✅ 保留 | 实测：反射**写字段只对 class 生效**（struct 值语义改副本），且慢；**已否决** |
| **D. SeaJSON 适配器（新增，推荐）** | ✅ | ❌ 不改（实现 seajson 的契约，与 stdx 的写法几乎一样） | ✅ 保留（core 接口 + 运行时下转型） | 零 stdx；契约与 stdx 1:1；编解码走字符串，热路径可再优化到 `JsonWriterEncodable` |

方案 C 把「JSON 必须依赖接口」这个前提绕过去了 —— 因为反射能直接读成员。
代价是序列化比手写慢（预计 2–5 倍，待实测），换来零依赖 + 零迁移。

## 4.2 JSON 接口按"流式"重新设计（2026-11-08 追加）

结论：**编码接口要收 sink，不要返回 String。**

```cangjie
// core（零 stdx）
public interface JsonSink {
    func append(piece: String): Unit   // 与 seajson 的 JsonTextSink 同形，桥接成本最低
    func finish(): Unit
}

public interface JsonCodec {
    /// 把 value 增量写进 sink（不物化整段 JSON）
    func encodeTo(sink: JsonSink, value: Any): Unit
    func contentType(): String
}
```

core 提供两个 sink 实现：

| sink | 用途 |
|---|---|
| `BufferJsonSink` | 默认：内部 StringBuilder，最后一次成型 → `setBodyString` |
| `StreamJsonSink` | 大响应：直接喂 tachyon 的 `setBodyStream(stream, -1)`（chunked 直发） |

以及便利函数：`encodeToString(codec, value)` = BufferJsonSink + finish。

**为什么是"收 sink"而不是"传 writer"**：writer 类型属于各家 JSON 库（seajson 的 `JsonWriter`、
stdx 的 `JsonWriter`），core 不能引用；但各家都往"文本片段"上写，所以 core 定一个极小的
`JsonSink`，适配器把它桥接成自家的 sink 即可：

```cangjie
// tang_ext_json_seajson
class BridgeSink <: seajson.JsonTextSink {
    let sink: JsonSink
    init(s: JsonSink) { this.sink = s }
    public func append(text: String): Unit { sink.append(text) }
    public func finish(): Unit { sink.finish() }
}

public func encodeTo(sink: JsonSink, value: Any): Unit {
    match (value) {
        case e: JsonWriterEncodable =>            // 真流式：逐字段写
            e.writeJson(JsonWriter(sink: BridgeSink(sink)))
        case e: JsonEncodable =>                  // 退化为整段
            sink.append(e.toJsonString())
        case _ => throw Exception("value 未实现 seajson 契约")
    }
}
```

实测依据：seajson 的 `JsonWriter` 有 `public init(sink!: JsonTextSink, ...)`，
且 writer 内部就是逐片段 `sink.append(...)`，桥接成本几乎为零。

**解码接口不受影响**：泛型约束 `T <: JsonDecodable<T>` 必须出现在签名里，
所以解码留在适配器做自由函数（`bindJson<T>(ctx)`），core 不参与。

**注意的代价**：seajson 的 writer 是逐片段 append（引号、数字、字符串值分开写），
如果 sink 每次 append 都做一次 `String → Array<Byte>` 转换，会比"最后一次性 toString"更碎。
所以默认走 `BufferJsonSink`（内部 StringBuilder，finish 时一次成型）；
只有确实要边算边发（超大数组响应）才走 `StreamJsonSink`。

## 5. 建议落地顺序

1. **先拆 crypto**：把 csrf/session/encryptcookie/etag/idempotency 移到 `tang_ext_crypto`，
   core 里仅保留接口/注册点（这些中间件本来就要显式 `use()`，迁移成本低）。
2. **log 自写**：一个 40 行的零依赖 logger 替掉 stdx.log，accesslog 跟着换。
3. **JSON 走 D（SeaJSON）**：core 定义 `JsonCodec` 接口；`tang_ext_json_seajson` 提供实现
   （零 stdx，作为默认推荐）；`tang_ext_json_stdx` 保留给小半年内的迁移期。
   编解码先走 `toJsonString/fromJsonString`，后续可优化到 `JsonWriterEncodable` 的流式写。
4. **static / proxy / ws** 放扩展成员：static 用 tachyon FileServer，
   ws 用 hijack，proxy 需要 HTTP 客户端（tachyon 无客户端，可等 tachyon_ext 或保留 stdx）。

## 6. 迁移影响面

- 包路径变化：`tang.middleware.csrf` → `tang.ext.crypto.csrf` 等（用户 import 要改）
- 方法风格 API：只有 JSON 受影响（走方案 C 则可保住）
- 需提供一份 `MIGRATION.md`，列 old → new 的 import 对照