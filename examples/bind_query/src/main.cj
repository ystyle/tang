package bind_query

import std.collection.HashMap
import stdx.net.http.{ServerBuilder}
import stdx.serialization.serialization.*
import tang.*

class User <: Serializable<User> {
    User(var id!: Int64 = 0, var name!: String = "") {}

    public func serialize(): DataModel {
        return DataModelStruct().add(field<Int64>("id", this.id)).add(field<String>("name", this.name))
    }
    public static func deserialize(dm: DataModel): User {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let l_id = Int64.deserialize(dms.get("id"))
        let l_name = String.deserialize(dms.get("name"))
        return User(id: l_id, name: l_name)
    }
}

main() {
    // 创建路由
    let r = Router()
    // 创建分组
    let group = r.group("/api")
    // 绑定query参数
    group.get(
        "/user",
        {
            ctx =>
            let query = ctx.bindQuery(User())
            ctx.json(query)
        }
    )
    group.get(
        "/user/current",
        {
            ctx =>
            let query = ctx.bindQuery(User())
            ctx.json(query)
        }
    )
    // 构建并启动服务
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
