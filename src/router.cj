package tang

import std.sync.ReentrantMutex
import net.http.{HttpContext, FuncHandler, RedirectHandler, NotFoundHandler, HttpRequestHandler, HttpRequestDistributor}
import net.http.HttpStatusCode
import encoding.url.URL

public class Router <: HttpRequestDistributor {
    public var config: Config
    public var group: Group
    let tree: Node
    let mu: ReentrantMutex = ReentrantMutex()

    public init() {
        this.tree = Node("/", "/")
        this.group = Group()
        this.config = Config(this.group)
        this.group.router = this
        this.config.group = this.group
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
        let fn: HandlerFunc = {
            ctx => handler.handle(ctx.context)
        }
        this.group.get(path, fn)
        this.group.post(path, fn)
        this.group.put(path, fn)
        this.group.delete(path, fn)
        this.group.patch(path, fn)
        this.group.head(path, fn)
        this.group.options(path, fn)
    }

    public func distribute(path: String): HttpRequestHandler {
        return FuncHandler(
            {
                ctx =>
                let (handler, params) = this.lookup(ctx)
                let tangctx = TangHttpContext(ctx, params)
                handler(tangctx)
            }
        )
    }

    public func newGroup(path:String): Group {
        this.group.newGroup(path)
    }

    func lookup(ctx: HttpContext): (HandlerFunc, Params) {
        var path = ctx.request.url.rawPath
        if (path == "") {
            path = ctx.request.url.path
        }
        let (node, handler, wildcardLen) = this.tree.findRoute(ctx.request.method.toString(), path)

        if (let None <- node) {
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

    public func compat(): CompatRouter {
        return CompatRouter(this)
    }
}

public class CompatRouter {
    CompatRouter(let router: Router) {}
}

func redirectHandler(newPath: String): HandlerFunc {
    return {
        _ =>
        let newUrl = URL.parse(newPath)
        RedirectHandler(newPath.toString(), HttpStatusCode.STATUS_MOVED_PERMANENTLY).handle
    }
}

func defaultMethodNotAllowedHandler(ctx: TangHttpContext): Unit {
    ctx.responseBuilder.status(HttpStatusCode.STATUS_METHOD_NOT_ALLOWED)
}

func defaultNoFoundHandler(ctx: TangHttpContext): Unit {
    NotFoundHandler().handle(ctx.context)
    ctx.responseBuilder.build().status
}
