package todo

import serialization.serialization.*
import std.collection.{ArrayList, HashMap}
import std.convert.*
import tang.*

// 存储todo
let todoList = ArrayList<Todo>([Todo(1, "cangjie"), Todo(2, "tang")])

// todo 结构
class Todo <: Serializable<Todo> {
    let id: Int64
    var content: String
    init(id: Int64, content: String) {
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
        return Todo(id, content)
    }
}

func getOneTodo(ctx: TangHttpContext) {
    let id = ctx.param("id")
    for (todo in todoList) {
        if (Int64.parse(id) == todo.id) {
            ctx.json(todo)
            return
        }
    }
    ctx.json<HashMap<String, String>>(HashMap<String, String>([("msg", "请求数据不存在")]))
}

func createTodo(ctx: TangHttpContext) {
    let m = ctx.bindJSON<HashMap<String, String>>()
    if (let Some(t) <- m) {
        let content = t["content"]
        let todo = Todo(todoList.size + 1, content)
        todoList.append(todo)
        ctx.json(todo)
    } else {
        ctx.json<HashMap<String, String>>(HashMap<String, String>([("msg", "请求参数错误")]))
    }
}

func updateTodo(ctx: TangHttpContext) {
    let m = ctx.bindJSON<Todo>()
    if (let Some(temp) <- m) {
        for (todo in todoList) {
            if (temp.id == todo.id) {
                todo.content = temp.content
                ctx.json(todo)
                break
            }
        }
    } else {
        ctx.json<HashMap<String, String>>(HashMap<String, String>([("msg", "请求参数错误")]))
    }
}

func deleteTodo(ctx: TangHttpContext) {
    let id = Int64.parse(ctx.param("id"))
    todoList.removeIf({
        todo => return todo.id == id
    })
    ctx.json<HashMap<String, String>>(HashMap<String, String>(("msg", "ok")))
}

func listTodo(ctx: TangHttpContext) {
    ctx.json(todoList)
}
