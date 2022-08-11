package tang

from std import sync.ReentrantMutex
from net import http.{ notFound as HttpNotFound, Request as HttpRequest, ResponseWriteStream, redirect, Handler }
from net import http.HttpStatusCode
from encoding import url.URL

public class Router <: Handler {
    public var config:Config
    public var group:Group
    let tree:Node
    let mu:ReentrantMutex = ReentrantMutex()

    public init() {
        this.tree = Node("/","/")
        this.group = Group()
        this.config = Config(this.group)
        this.group.router = this
        this.config.group = this.group
    }
    
    public init(opts:Array<OptionFunc>) {
        this()
        for (opt in opts) {
            opt(this.config)
        }
    }

    public func serveHTTP(w: ResponseWriteStream, r: HttpRequest):Unit {
        this.ServeHTTPError(w, r)
    }

    public func ServeHTTPError(w: ResponseWriteStream, r:HttpRequest):Unit {
        let (handler, params) = this.lookup(w, r)
        let rr = Request(r, params)
        handler(w, rr)
    }

    func lookup(w: ResponseWriteStream, req: HttpRequest):(HandlerFunc, Params)  {
        var path = req.url.rawPath
        if (path == "") {
            path = req.url.path
        }
        let (node, handler, wildcardLen) = this.tree.findRoute(req.method.toString(), path)
        
        if (let None = node) {
            let redir = this.redir(req.method.toString(), path)
            if (let Some(fn) = redir) {
                return (fn, Params())
            }
            let fn = this.config.notFoundHandler
            return (fn, Params())
        }
        var n = node.getOrThrow()
        var handlerfn:HandlerFunc
        if (let None = handler) {
            let redir = this.redir(req.method.toString(), path)
            if (let Some(fn) = redir) {
                return (fn, Params())
            }
            handlerfn = n.handleMap.notAllowed.getOrThrow()
        } else {
            handlerfn = handler.getOrThrow()
        }
        return (handlerfn, Params(path, n, wildcardLen))
    }

    func redir(method:String, path:String):?HandlerFunc {
        if (path == "/") {
            return None
        }
        var cleanPath  = CleanPath(path)
        if (cleanPath != path) {
           let (_, handler, _) =  this.tree.findRoute(method, cleanPath)
           if (let Some(fn) = handler) {
               return redirectHandler(cleanPath)
           }
        }
        if (path.startsWith("/")) {
            let cleanPath  = path[..path.size() - 1]
            let (_, handler, _) =  this.tree.findRoute(method, cleanPath)
            if (let Some(fn) = handler) {
                return redirectHandler(cleanPath)
            }
        }
        cleanPath  = path + "/"
        let (_, handler, _) =  this.tree.findRoute(method, cleanPath)
        if (let Some(fn) = handler) {
            return redirectHandler(cleanPath)
        }
        return None
    }

    public func Compat(): CompatRouter {
        return CompatRouter(this)
    }
}

public class  CompatRouter {
    CompatRouter(let router:Router){}
}

func redirectHandler(newPath:String):HandlerFunc {
    return {w, r =>
        let newUrl = URL.parse(newPath)
        newUrl.fragment = r.request.url.fragment
        newUrl.rawQuery = r.request.url.rawQuery
        redirect(w, r.request, newUrl.toString(), HttpStatusCode.STATUS_MOVED_PERMANENTLY)
    }
}

func defaultMethodNotAllowedHandler(w:ResponseWriteStream, req:Request) {
    w.writeStatusCode(HttpStatusCode.STATUS_METHOD_NOT_ALLOWED)
}

func defaultNoFoundHandler(w:ResponseWriteStream, req:Request):Unit {
    HttpNotFound(w, req.request)
}

