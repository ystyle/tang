package tang

import std.collection.ArrayList
import tang.radix.{RouteHandler, RouteParams}

public class Group {
    var router:?Router
    let path:String
    var stack = ArrayList<MiddlewareFunc>()

    init(router:Router, path:String, stack:Array<MiddlewareFunc>) {
        this.router = router
        this.path = path
        this.stack.add(all:stack)
    }

    init(path:String, stack!:Array<MiddlewareFunc> = []) {
        this.router = None
        this.path = path
        this.stack.add(all:stack)
    }
    init() {
        this.router = None
        this.path = ""
    }

    public func group(path:String, opts!:Array<GroupOptionFunc>=Array()):Group {
        let group = if (let Some(route) <- this.router) {
            Group(route, joinPath(this.path, path) , this.stack.toArray())
        } else {
            Group(joinPath(this.path, path), stack: this.stack.toArray())
        }
        let cfg = Config(group)
        for (opt in opts) {
            opt(cfg)
        }
        return group
    }

    public func use (middlewares:Array<MiddlewareFunc>):Group {
        this.stack.add(all:middlewares)
        return this
    }
    
    public func handle(meth:String, path:String, handler:HandlerFunc) {
        if (let Some(r) <- this.router) {
            synchronized(r.mu) {
                checkPath(path)
                let p = this.path + path
                if (p.isEmpty()) {
                    throw Exception("path can't be empty")
                }
                println("${meth}\t|\t${p}")

                // 使用 radix tree 注册路由
                let wrappedHandler = this.wrap(handler)
                let radixHandler: RouteHandler = { _: RouteParams => () }
                if (let Some(r) <- this.router) {
                    r.tree.insertRoute(meth, p, radixHandler)
                }

                // 存储 HandlerFunc 到 Router 的 handlers 映射中
                let key = "${meth}:${p}"
                if (let Some(router) <- this.router) {
                    router.handlers[key] = wrappedHandler
                }
            }
        }
    }

    func wrap(handler:HandlerFunc):HandlerFunc {
        var wrapHandle = handler
        var i = 0
        while (i < this.stack.size) {
            let st = this.stack[this.stack.size -1 - i]
            wrapHandle = st(wrapHandle)
            i++
        }
        return wrapHandle
    }

    public func get (path:String, handler:HandlerFunc) {
        this.handle("GET", path, handler)
    }

    public func post (path:String, handler:HandlerFunc) {
        this.handle("POST", path, handler)
    }
    public func put (path:String, handler:HandlerFunc) {
        this.handle("PUT", path, handler)
    }
    public func delete (path:String, handler:HandlerFunc) {
        this.handle("DELETE", path, handler)
    }
    public func patch (path:String, handler:HandlerFunc) {
        this.handle("PATCH", path, handler)
    }
    public func head (path:String, handler:HandlerFunc) {
        this.handle("HEAD", path, handler)
    }
    public func options (path:String, handler:HandlerFunc) {
        this.handle("OPTIONS", path, handler)
    }

    /// 匹配所有 HTTP 方法
    public func all (path:String, handler:HandlerFunc) {
        this.handle("*", path, handler)
    }
}

func joinPath(base:String, path:String):String {
    checkPath(path)
    let p = (base + path).toRuneArray()
    if (p.size > 1 && p[p.size-1] == r'/') {
        return String(p[..p.size-1])
    }
    return String(p)
}

func checkPath(path:String) {
    if (path.size > 0 && path.toRuneArray()[0] != r'/') {
        throw Exception("path ${path} must start with a slash")
    }
}