from tang import tang.*
from tang import middleware.{logMiddleware, exceptionMiddleware}
from net import http.Server, http.ResponseWriteStream
from serialization import serialization.*
import std.collection.HashMap

class User <: Serializable<User>  {
    
    User(var id!:Int64 = 0, var name!:String = "") {}

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
    let r = Router([
        use([
            exceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            logMiddleware // 访问日志记录
        ])
    ])
    // 创建分组
    r.group.withGroup("/api", {group =>
        // 绑定query参数
        group.get("/user", {w, r =>
            var query = Box<User>(User())
            r.bindQuery(query)
            json(w, query.value)
        })
        group.get("/user/current", {w, r =>
            let query = r.bindQuery(User())
            json(w, query)
        })
    })

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}
