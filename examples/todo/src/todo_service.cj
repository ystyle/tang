package todo

import std.convert.*
import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.stream.*
import tang.*

// 存储todo
let todoList = ArrayList<Todo>([Todo(1, "cangjie"), Todo(2, "tang")])

class Result<T> <: JsonSerializable where T <: JsonSerializable {
    let code:Int64
    let msg:?String
    let data:?T
    init(code:Int64, data:T){
        this.code = code 
        this.data = data
        this.msg = None
    }
    init(code:Int64, msg:String){
        this.code = code 
        this.data = None
        this.msg = msg
    }
    init(code:Int64, msg:?String, data:?T){
        this.code = code 
        this.data = data
        this.msg = msg
    }
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("code").writeValue(this.code)
        w.writeName("msg").writeValue(this.msg)
        w.writeName("data").writeValue(this.data)
        w.endObject()
    }
}

// todo 结构
class Todo <: JsonDeserializable<Todo> & JsonSerializable {
    var id: Int64
    var content: String
    init(id: Int64, content: String) {
        this.id = id
        this.content = content
    }
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("id").writeValue(this.id)
        w.writeName("content").writeValue(this.content)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): Todo {
        let res = Todo(0, "")
        fromJsonObject(
            r,
            [
                ("id", {=> res.id = r.readValue<Int64>()}),
                ("content", {=> res.content = r.readValue<String>()})
            ])
        return res
    }
}

func fromJsonObject(r: JsonReader, list: Array<(String, () -> Unit)>) {
    let refs = HashMap<String, () -> Unit>(list)
    while (let Some(v) <- r.peek()) {
        match (v) {
            case BeginObject =>
                r.startObject()
                while (r.peek() != EndObject) {
                    let n = r.readName()
                    if (refs.contains(n)) {
                        refs[n]()
                    } else {
                        r.skip()
                    }
                }
                r.endObject()
                break
            case _ => throw Exception()
        }
    }
}

func getOneTodo(ctx: TangHttpContext) {
    let id = ctx.param("id")
    for (todo in todoList) {
        if (Int64.parse(id) == todo.id) {
            ctx.json(Result(1, todo))
            return
        }
    }
    ctx.json(Result<Todo>(-1,"请求数据不存在"))
}

func createTodo(ctx: TangHttpContext) {
    let m = ctx.bindJson<HashMap<String, String>>()
    if (let Some(t) <- m) {
        let content = t["content"]
        let todo = Todo(todoList.size + 1, content)
        todoList.add(todo)
        ctx.json(Result(1, todo))
    } else {
        ctx.json(Result<Todo>(-1,"请求参数错误"))
    }
}

func updateTodo(ctx: TangHttpContext) {
    let m = ctx.bindJson<Todo>()
    if (let Some(temp) <- m) {
        for (todo in todoList) {
            if (temp.id == todo.id) {
                todo.content = temp.content
                ctx.json(Result(1, todo))
                break
            }
        }
    } else {
        ctx.json(Result<Todo>(-1,"请求参数错误"))
    }
}

func deleteTodo(ctx: TangHttpContext) {
    let id = Int64.parse(ctx.param("id"))
    todoList.removeIf({
        todo => return todo.id == id
    })
    ctx.json(Result<Todo>(1,"ok"))
}

func listTodo(ctx: TangHttpContext) {
    ctx.json(Result<ArrayList<Todo>>(1, todoList))
}
