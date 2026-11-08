package json

import tang.*
import tang_ext_json_seajson.*
import seajson.*

/// 自定义类型：实现 seajson 的契约即可被 ctx.json 输出
///
/// JsonWriterEncodable 是流式写法（逐字段写进 writer，不物化整段字符串）；
/// 只实现 JsonEncodable（toJsonString 返回整段）也能用，但会多一次中间分配。
public class User <: JsonWriterEncodable {
    public var id: Int64 = 0
    public var name: String = ""

    public init(id: Int64, name: String) {
        this.id = id
        this.name = name
    }

    public func writeJson(w: JsonWriter): Unit {
        w.beginObject()
        w.name("id")
        w.value(id)
        w.name("name")
        w.value(name)
        w.endObject()
    }
}

main() {
    // 注册 JSON codec：核心不绑定任何 JSON 库，必须在处理请求前注册一次
    useSeaJson()

    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    let group = app.group("/api")

    // 返回实现了 JsonWriterEncodable 的类型
    group.get("/user/current", {
        ctx =>
        ctx.json(User(1, "张三"))
        // 指定状态码：ctx.jsonWithCode(201, User(1, "张三"))
    })

    app.listen()
}
