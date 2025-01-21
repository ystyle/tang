package tang

import std.collection.ArrayList
import std.reflect.TypeInfo

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

    // public func withMiddleware(middleware:MiddlewareFunc):Group {
    //     return this.group("", opts: [withMiddleware([middleware])])
    // }
    // public func withGroup(path:String, fn: (Group) -> Unit) {
    //     fn(this.newGroup(path))
    // }
    public func handle(meth:String, path:String, handler:HandlerFunc) {
        if (let Some(r) <- this.router) {
            synchronized(r.mu) {
                checkPath(path)
                let p = this.path + path
                if (p.isEmpty()) {
                    throw Exception("path can't be empty")
                }
                println("${meth}\t|\t${p}")
                let tree = this.router?.tree
                let node =  tree?.addRoute(p)
                if (let Some(n) <- node) {
                    n.setHandler(meth, this.wrap(handler))
                    if (let None <- n.handleMap.notAllowed) {
                        let config = this.router?.config
                        if (let Some(fn) <- config?.methodNotAllowedHandler) {
                            n.handleMap.notAllowed = this.wrap(fn)
                        }
                    }
                }
            }
        }
    }

    func wrap(handler:HandlerFunc):HandlerFunc {
        var wrapHandle = handler
        for (st in this.stack) {
            wrapHandle = st(wrapHandle)
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