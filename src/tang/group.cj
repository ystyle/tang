package tang

from std import collection.ArrayList

public class Group {
    var router:?Router
    let path:String
    var stack = ArrayList<MiddlewareFunc>()

    public init(router:Router, path:String, stack:ArrayList<MiddlewareFunc>) {
        this.router = router
        this.path = path
        this.stack = stack
    }

    public init(path:String, stack!:ArrayList<MiddlewareFunc> = ArrayList()) {
        this.router = None
        this.path = path
        this.stack = stack

    }
    public init() {
        this.router = None
        this.path = ""
    }

    public func newGroup(path:String, opts!:Array<GroupOptionFunc>=Array()):Group {
        let group = if (let Some(route) = this.router) {
            Group(route, joinPath(this.path, path) , ArrayList(this.stack))
        } else {
            Group(joinPath(this.path, path), stack: ArrayList(this.stack))
        }
        let cfg = Config(group)
        for (opt in opts) {
            opt(cfg)
        }
        return group
    }

    public func use (middlewares:Array<MiddlewareFunc>):Group {
        let mdds = tang.use(middlewares)
        return this.newGroup("", opts: [mdds])
    }

    public func withMiddleware(middleware:MiddlewareFunc):Group {
        return this.newGroup("", opts: [withMiddleware([middleware])])
    }
    public func withGroup(path:String, fn: (Group) -> Unit) {
        fn(this.newGroup(path))
    }
    public func handle(meth:String, path:String, handler:HandlerFunc) {
        if (let Some(r) = this.router) {
            synchronized(r.mu) {
                checkPath(path)
                let p = this.path + path
                if (p.isEmpty()) {
                    throw Exception("path can't be empty")
                }
                let tree = this.router?.tree
                let node =  tree?.addRoute(p)
                if (let Some(n) = node) {
                    n.setHandler(meth, this.wrap(handler))
                    if (let None = n.handleMap.notAllowed) {
                        let config = this.router?.config
                        if (let Some(fn) = config?.methodNotAllowedHandler) {
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
    let p = base + path
    if (p.size > 1 && p[p.size-1] == '/') {
        return p[..p.size-1]
    }
    return p
}

func checkPath(path:String) {
    if (path.size > 0 && path[0] != '/') {
        throw Exception("path ${path} must start with a slash")
    }
}