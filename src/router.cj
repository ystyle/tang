package tang

import std.sync.Mutex
import std.collection.HashMap
import std.collection.ArrayList
import stdx.net.http.{HttpContext, FuncHandler, RedirectHandler, NotFoundHandler, HttpRequestHandler, HttpRequestDistributor}
import stdx.net.http.HttpStatusCode
import stdx.encoding.url.URL
import tang.log.getLogger
import tang.radix.{RouteNode}

public class Router <: HttpRequestDistributor {
    var config: Config
    var _group: Group
    let tree: RouteNode
    let mu: Mutex = Mutex()
    var handlers: HashMap<String, HandlerFunc> = HashMap<String, HandlerFunc>()
    var patterns: HashMap<String, String> = HashMap<String, String>()  // 存储从实际路径到pattern的映射
    var rewriteRules: ArrayList<(String) -> String> = ArrayList<(String) -> String>()  // 路径重写规则

    public init() {
        this.tree = RouteNode("")
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

    public func register(path: String, _: HttpRequestHandler): Unit {
        getLogger().info("It is not recommended to use the register method to register the handler: ${path}")
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

        // 应用路径重写规则（在路由匹配之前）
        for (rule in this.rewriteRules) {
            let newPath = rule(path)
            if (newPath != path) {
                path = newPath
                break  // 只应用第一个匹配的规则
            }
        }

        let method = ctx.request.method.toString()

        // 使用 radix tree 查找
        var (node, radixParams) = this.tree.searchRoute(method, path)

        // HEAD 请求回退到 GET（HTTP 标准行为）
        if (let None <- node && method == "HEAD") {
            let (getNode, getParams) = this.tree.searchRoute("GET", path)
            if (let Some(n) <- getNode) {
                node = Some(n)
                radixParams = getParams
            }
        }

        if (let Some(n) <- node) {
            // 找到了路由节点，使用节点的 pattern 来查找 HandlerFunc
            let pattern = n.pattern
            let key = "${method}:${pattern}"

            // 优先查找具体方法（使用一次 get 查询）
            if (let Some(handler) <- this.handlers.get(key)) {
                let params = Params(radixParams)
                return (handler, params)
            }

            // 如果没找到，尝试查找 all() 方法（通配符 *）
            let allKey = "*:${pattern}"
            if (let Some(handler) <- this.handlers.get(allKey)) {
                let params = Params(radixParams)
                return (handler, params)
            }

            // HEAD 请求回退到 GET 处理器
            if (method == "HEAD") {
                let getKey = "GET:${pattern}"
                if (let Some(handler) <- this.handlers.get(getKey)) {
                    let params = Params(radixParams)
                    return (handler, params)
                }
            }
        }

        // 没找到
        let redir = this.redir(ctx.request.method.toString(), path)
        if (let Some(fn) <- redir) {
            return (fn, Params())
        }

        let fn = this.config.notFoundHandler
        return (fn, Params())
    }

    func redir(method: String, path: String): ?HandlerFunc {
        if (path == "/") {
            return None
        }
        var cleanPath = cleanPath(path)
        if (cleanPath != path) {
            let (node, _) = this.tree.searchRoute(method, cleanPath)
            if (let Some(_) <- node) {
                return redirectHandler(cleanPath)
            }
        }
        if (path.startsWith("/")) {
            let cleanPath = path[..path.size - 1]
            let (node, _) = this.tree.searchRoute(method, cleanPath)
            if (let Some(_) <- node) {
                return redirectHandler(cleanPath)
            }
        }
        cleanPath = path + "/"
        let (node, _) = this.tree.searchRoute(method, cleanPath)
        if (let Some(_) <- node) {
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

    /// 匹配所有 HTTP 方法
    public func all (path:String, handler:HandlerFunc) {
        this._group.handle("*", path, handler)
    }

    /// 添加路径重写规则（在路由匹配之前执行）
    public func addRewriteRule(rule: (String) -> String): Unit {
        this.rewriteRules.add(rule)
    }

    /// 打印启动 Banner
    public func printBanner(version!: String = TANG_VERSION, port!: UInt16 = 8080) {
        BannerPrinter.printBanner(version: version, port: port)
    }

    /// 打印所有注册的路由
    public func printRoutes() {
        BannerPrinter.printRoutes(this.handlers)
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
}
