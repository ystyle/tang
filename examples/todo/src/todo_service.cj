package todo

import std.convert.*
import std.collection.ArrayList
import tang.*
import tang_ext_json_seajson.bindJson
import seajson.*

// 内存存储
let todoList = ArrayList<Todo>([Todo(1, "cangjie"), Todo(2, "tang")])

/// 待办项：实现 seajson 的编码与解码契约
public class Todo <: JsonWriterEncodable & JsonDecodable<Todo> {
    public var id: Int64 = 0
    public var content: String = ""

    public init(id: Int64, content: String) {
        this.id = id
        this.content = content
    }

    public static func fromJsonString(json: String): Todo {
        let v = parseJson(json)
        return Todo(jsonFieldInt(v, "id") ?? 0, jsonFieldString(v, "content") ?? "")
    }

    public func writeJson(w: JsonWriter): Unit {
        w.beginObject()
        w.name("id")
        w.value(id)
        w.name("content")
        w.value(content)
        w.endObject()
    }
}

/// 待办列表的 JSON 形态（数组）
public class TodoArray <: JsonWriterEncodable {
    let items: ArrayList<Todo>

    public init(items: ArrayList<Todo>) {
        this.items = items
    }

    public func writeJson(w: JsonWriter): Unit {
        w.beginArray()
        for (t in items) {
            w.writerEncodableValue(t)
        }
        w.endArray()
    }
}

/// 统一响应外壳
///
/// 泛型参数限定为可 JSON 编码的类型，编码时直接写进去（不物化中间字符串）。
public class Result<T> <: JsonWriterEncodable where T <: JsonWriterEncodable {
    let code: Int64
    let msg: ?String
    let data: ?T

    public init(code: Int64, data: T) {
        this.code = code
        this.data = Some(data)
        this.msg = None
    }

    public init(code: Int64, msg: String) {
        this.code = code
        this.data = None
        this.msg = Some(msg)
    }

    public func writeJson(w: JsonWriter): Unit {
        w.beginObject()
        w.name("code")
        w.value(code)
        w.name("msg")
        match (msg) {
            case Some(m) => w.value(m)
            case None => w.nullValue()
        }
        w.name("data")
        match (data) {
            case Some(d) => w.writerEncodableValue(d)
            case None => w.nullValue()
        }
        w.endObject()
    }
}

func getOneTodo(ctx: TangHttpContext) {
    let id = Int64.parse(ctx.param("id"))
    for (todo in todoList) {
        if (todo.id == id) {
            ctx.json(Result<Todo>(1, todo))
            return
        }
    }
    ctx.json(Result<Todo>(-1, "请求数据不存在"))
}

func createTodo(ctx: TangHttpContext) {
    match (bindJson<Todo>(ctx)) {
        case Some(t) =>
            let todo = Todo(todoList.size + 1, t.content)
            todoList.add(todo)
            ctx.json(Result<Todo>(1, todo))
        case None => ctx.json(Result<Todo>(-1, "请求参数错误"))
    }
}

func updateTodo(ctx: TangHttpContext) {
    match (bindJson<Todo>(ctx)) {
        case Some(temp) =>
            var found = false
            for (todo in todoList) {
                if (temp.id == todo.id) {
                    todo.content = temp.content
                    ctx.json(Result<Todo>(1, todo))
                    found = true
                    break
                }
            }
            if (!found) {
                ctx.json(Result<Todo>(-1, "请求数据不存在"))
            }
        case None => ctx.json(Result<Todo>(-1, "请求参数错误"))
    }
}

func deleteTodo(ctx: TangHttpContext) {
    let id = Int64.parse(ctx.param("id"))
    todoList.removeIf({todo => todo.id == id})
    ctx.json(Result<Todo>(1, "ok"))
}

func listTodo(ctx: TangHttpContext) {
    ctx.json(Result<TodoArray>(1, TodoArray(todoList)))
}
