package json

import tang.*
import tang.middleware.logMiddleware
import net.http.ServerBuilder
import std.collection.HashMap
import serialization.serialization.*

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
    // 创建路由
    let r = Router(use(logMiddleware))
    // 创建分组
    let group = r.group("/api")
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

    // 构建并启动服务
    let server = ServerBuilder().distributor(r).addr("127.0.0.1").port(10000).build()
    println("listening on http://localhost:${server.port}")
    server.serve()
}
