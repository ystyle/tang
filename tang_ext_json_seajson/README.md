# tang_ext_json_seajson

**tang 的 JSON 适配器：基于 [SeaJSON](https://pkg.cangjie-lang.cn/package/SeaJson)，零 stdx。**

tang 核心不绑定任何 JSON 库（为了保持零 stdx），JSON 能力通过适配器接入：

```toml
[dependencies]
  "tang" = "2.0.0"
  "tang_ext_json_seajson" = "2.0.0"
```

```cangjie
import tang.*
import tang_ext_json_seajson.*

main() {
    useSeaJson()            // 注册全局 JSON codec，必须在处理请求前调用
    let app = Tang()
    app.get("/json", { ctx => ctx.json(MyDto()) })
    app.post("/echo", { ctx =>
        match (bindJson<MyDto>(ctx)) {
            case Some(v) => ctx.json(v)
            case None => ctx.responseBuilder.status(400u16).body("bad json")
        }
    })
    app.listen(8080u16)
}
```

## 提供什么

| 能力 | 说明 |
|---|---|
| `useSeaJson()` | 把 SeaJsonCodec 注册为 tang 的默认 codec |
| `ctx.json(v)` | 走注册的 codec 输出，Content-Type: application/json |
| `bindJson<T>(ctx)` | 从请求体反序列化（泛型约束在适配器，所以是自由函数） |
| `SeaJsonCodec` | 类型实现了 `JsonWriterEncodable` 走流式逐字段写；只实现 `JsonEncodable` 则整段物化后写入 |

MulanPSL-2.0
