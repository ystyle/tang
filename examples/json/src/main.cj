package json

import std.collection.HashMap
import stdx.serialization.serialization.*
import tang.*

class User <: Serializable<User>  {
    let id:Int64
    var name:String
    init(id:Int64, name:String) {
        this.id = id
        this.name = name
    }
    public func serialize(): DataModel {
        return DataModelStruct().add(field<Int64>("id", this.id)).add(field<String>("name", this.name))
    }
    public static func deserialize(dm: DataModel): User {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let id = Int64.deserialize(dms.get("id"))
        let name = String.deserialize(dms.get("name"))
        return User(id,name)
    }
}

main() {
    // 创建 Tang 应用
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    // 创建分组
    let group = app.group("/api")
    // 静态路由
    group.get(
        "/user/current",
        {
            ctx =>
            let u = User(1, "张三")
            // 可以返回实现了 Serializable 接口的类型
            ctx.json(u)
            // 还有个可以返回 http status code的方法
            // ctx.jsonWithCode(201, u)
        }
    )

    // 启动应用
    app.listen()
}
