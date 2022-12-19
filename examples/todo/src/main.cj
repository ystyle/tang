from net import http.{Server, ResponseWriteStream}
from std import collection.{ HashMap, ArrayList }
from serialization import serialization.*
from std import convert.*
from tang import tang.*
from tang import middleware.{logMiddleware, exceptionMiddleware}

func getOneTodo(w:ResponseWriteStream, r:Request) {
    let id = r.params.int64("id") ?? -1
    for (todo in todoList) {
        if (id == todo.id) {
            json(w, todo)
            break
        }
    }
}

func createTodo(w:ResponseWriteStream, r:Request) {
    let m = r.bindJSON<HashMap<String,String>>()
    if (let Some(t) = m) {
        let content = t["content"]
        let todo = Todo(todoList.size + 1, content)
        todoList.append(todo)
        json(w, todo)
    } else {
        json(w, HashMap<String,String>([("msg", "请求参数错误")]))
    }
}

func updateTodo(w:ResponseWriteStream, r:Request) {
    let m = r.bindJSON<Todo>()
    if (let Some(temp) = m) {
        for (todo in todoList) {
            if (temp.id == todo.id) {
                todo.content = temp.content
                json(w, todo)
                break
            }
        }
    } else {
        json(w, HashMap<String,String>([("msg", "请求参数错误")]))
    }
}

func deleteTodo(w:ResponseWriteStream, r:Request) {
    let id = r.params.int64("id") ?? -1
     todoList.removeIf({todo => 
            return todo.id == id
    })
    json(w, HashMap<String,String>([("msg", "ok")]))
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
        // 获取指定id的todo
        group.get("/todo/:id", getOneTodo)
        // 获取所有的todoList
        group.get("/todo", {w, r => 
            json(w, todoList)
        })
        // 创建一个todo
        group.post("/todo", createTodo)
        // 更新一个todo
        group.put("/todo", updateTodo)
        // 删除一个todo
        group.delete("/todo/:id", deleteTodo)
    })
    
    // 构建并启动服务
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}