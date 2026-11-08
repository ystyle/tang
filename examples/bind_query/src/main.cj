package bind_query

import tang.*
import tang_ext_json_seajson.*
import seajson.*

/// 查询参数绑定：实现 core 的 QueryBindable 接口
///
/// 旧版是 stdx.serialization 的 Serializable + ctx.bindQuery(User())；
/// 现在核心零依赖，绑定契约定义在 core（QueryBindable），
/// JSON 输出交给 tang_ext_json_seajson 的 codec。
public class User <: QueryBindable & JsonWriterEncodable {
    public var id: Int64 = 0
    public var name: String = ""

    public init() {}

    /// 从 query string 绑定字段（类型不对的字段保持默认值）
    public func bindQuery(params: QueryParams): Unit {
        match (params.int("id")) {
            case Some(v) => this.id = v
            case None => ()
        }
        match (params.value("name")) {
            case Some(v) => this.name = v
            case None => ()
        }
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
    useSeaJson()

    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    let group = app.group("/api")

    // ?id=7&name=cangjie  →  {"id":7,"name":"cangjie"}
    group.get(
        "/user",
        {
            ctx =>
            let query = ctx.bindQuery(User())
            ctx.json(query)
        }
    )

    app.listen()
}
