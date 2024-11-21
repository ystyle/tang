package tang

import std.sync.ReentrantMutex
import net.http.{HttpContext, FuncHandler, RedirectHandler, NotFoundHandler, HttpRequestHandler, HttpRequestDistributor}
import net.http.HttpStatusCode
import encoding.url.URL
import tang.log.getLogger

public class Router <: HttpRequestDistributor {
    var config: Config
    var _group: Group
    let tree: Node
    let mu: ReentrantMutex = ReentrantMutex()

    public init() {
        println("\tTang Web Frameworks")
        println("method\t|\tpath")
        this.tree = Node("/", "/")
        this._group = Group()
        this.config = Config(this._group)
        this._group.router = this
        this.config.group = this._group
    }

    public init(opts: Array<OptionFunc>) {
        this()
        for (opt in opts) {
            opt(this.config)
        }
    }

    // public func handle(ctx: HttpContext): Unit {
    //     this.serveHTTPError(ctx)
    // }

    // public func serveHTTPError(ctx: HttpContext): Unit {
    //     let (handler, params) = this.lookup(ctx)
    //     let rr = Request(ctx.request, params)
    //     handler(ctx)
    // }

    public func register(path: String, handler: HttpRequestHandler): Unit {
        getLogger().info("It is not recommended to use the register method to register the handler: ${path}")
        let fn: HandlerFunc = {
            ctx => handler.handle(ctx.context)
        }
        this._group.get(path, fn)
        this._group.post(path, fn)
        this._group.put(path, fn)
        this._group.delete(path, fn)
        this._group.patch(path, fn)
        this._group.head(path, fn)
        this._group.options(path, fn)
    }

    public func distribute(_: String): HttpRequestHandler {
        return FuncHandler(
            {
                ctx =>
                let (handler, params) = this.lookup(ctx)
                let tangctx = TangHttpContext(ctx, params)
                handler(tangctx)
            }
        )
    }

    public func group(path:String): Group {
        this._group.group(path)
    }

    func lookup(ctx: HttpContext): (HandlerFunc, Params) {
        var path = ctx.request.url.rawPath
        if (path == "") {
            path = ctx.request.url.path
        }
        let (node, handler, wildcardLen) = this.tree.findRoute(ctx.request.method.toString(), path)

        if (let None <- node) {
            // no found
            let redir = this.redir(ctx.request.method.toString(), path)
            if (let Some(fn) <- redir) {
                return (fn, Params())
            }
            let fn = this.config.notFoundHandler
            return (fn, Params())
        }
        var n = node.getOrThrow()
        var handlerfn: HandlerFunc
        if (let None <- handler) {
            let redir = this.redir(ctx.request.method.toString(), path)
            if (let Some(fn) <- redir) {
                return (fn, Params())
            }
            handlerfn = n.handleMap.notAllowed.getOrThrow()
        } else {
            handlerfn = handler.getOrThrow()
        }
        return (handlerfn, Params(path, n, wildcardLen))
    }

    func redir(method: String, path: String): ?HandlerFunc {
        if (path == "/") {
            return None
        }
        var cleanPath = cleanPath(path)
        if (cleanPath != path) {
            let (_, handler, _) = this.tree.findRoute(method, cleanPath)
            if (let Some(fn) <- handler) {
                return redirectHandler(cleanPath)
            }
        }
        if (path.startsWith("/")) {
            let cleanPath = path[..path.size - 1]
            let (_, handler, _) = this.tree.findRoute(method, cleanPath)
            if (let Some(fn) <- handler) {
                return redirectHandler(cleanPath)
            }
        }
        cleanPath = path + "/"
        let (_, handler, _) = this.tree.findRoute(method, cleanPath)
        if (let Some(fn) <- handler) {
            return redirectHandler(cleanPath)
        }
        return None
    }

    public func get (path:String, handler:HandlerFunc) {
        this._group.handle("GET", path, handler)
    }

    public func post (path:String, handler:HandlerFunc) {
        this._group.handle("POST", path, handler)
    }
    public func put (path:String, handler:HandlerFunc) {
        this._group.handle("PUT", path, handler)
    }
    public func delete (path:String, handler:HandlerFunc) {
        this._group.handle("DELETE", path, handler)
    }
    public func patch (path:String, handler:HandlerFunc) {
        this._group.handle("PATCH", path, handler)
    }
    public func head (path:String, handler:HandlerFunc) {
        this._group.handle("HEAD", path, handler)
    }
    public func options (path:String, handler:HandlerFunc) {
        this._group.handle("OPTIONS", path, handler)
    }
}

func redirectHandler(newPath: String): HandlerFunc {
    return {
        _ =>
        let newUrl = URL.parse(newPath)
        RedirectHandler(newUrl.toString(), HttpStatusCode.STATUS_MOVED_PERMANENTLY).handle
    }
}

func defaultMethodNotAllowedHandler(ctx: TangHttpContext): Unit {
    ctx.responseBuilder.status(HttpStatusCode.STATUS_METHOD_NOT_ALLOWED)
}

func defaultNoFoundHandler(ctx: TangHttpContext): Unit {
    NotFoundHandler().handle(ctx.context)
    ctx.responseBuilder.build().status
}
