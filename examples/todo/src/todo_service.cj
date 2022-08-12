
// 存储todo
let todoList = ArrayList<Todo>([
    Todo(1, "cangjie"),
    Todo(2, "tang")
])

// todo 结构
class Todo <: Serializable<Todo>  {
    let id:Int64
    var content:String
    init(id:Int64, content:String) {
        this.id = id
        this.content = content
    }
    public func serialize(): DataModel {
        return DataModelStruct().add(field<Int64>("id", this.id)).add(field<String>("content", this.content))
    }
    public static func deserialize(dm: DataModel): Todo {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let content = String.deserialize(dms.get("content"))
        let id = Int64.deserialize(dms.get("id"))
        return Todo(id,content)
    }
}