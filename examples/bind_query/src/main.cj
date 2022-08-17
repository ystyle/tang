from tang import tang.*
from tang import middleware.{LogMiddleware, ExceptionMiddleware}
from net import http.Server, http.ResponseWriteStream
from serialization import serialization.*

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
        let name = String.deserialize(dms.get("name"))
        let id = Int64.deserialize(dms.get("id"))
        return User(id,name)
    }
}

main() {
    // 创建路由
    let r = Router([
        Use([
            ExceptionMiddleware, // 放第一位，保证其它中间件也能正常执行
            LogMiddleware // 访问日志记录
        ])
    ])
    // 创建分组
    r.group.withGroup("/api", {group =>
        // 绑定query参数
        group.get("/user", {w, r => 
            let query = r.bindQuery(User(0, ""))
            JSON(w, query)
        })
    })

    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}