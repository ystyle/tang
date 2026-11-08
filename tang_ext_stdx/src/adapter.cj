package tang_ext_stdx

import std.io.{ByteBuffer, InputStream}
import std.collection.HashMap
import stdx.net.http.{HttpContext, HttpRequestDistributor, HttpRequestHandler, FuncHandler, Server, ServerBuilder}
import tang.{Tang, TangHttpContext, HandlerFunc, Params}
import ystyle::tachyon.{newDetachedCtx, snapshotResponse, DetachedRequest, RequestCtx}

/**
 * tang 与 stdx 的兼容层。
 *
 * 为什么方向是「把 tang 跑在 stdx 的 server 上」，而不是「把 stdx handler 塞进 tang 的 server」：
 * stdx 的 `HttpContext` 构造器是 internal，外部无法伪造一个上下文，
 * 所以「以 HttpContext 为参数」的 handler 只有在 stdx 自己收包时才能拿到真上下文。
 * 反过来，tachyon 的 RequestCtx 可以用 DetachedRequest 手工构造，
 * 于是 tang 的路由/中间件可以原样跑在 stdx 的请求上。
 */

/// 把 stdx 风格的 handler 适配成 tang 的 handler
///
/// 只能在 `serve` / `serveAsync`（即 stdx server）下使用：
/// 它会从当前请求的适配器槽里取真的 stdx HttpContext。
public func fromStd(handler: (HttpContext) -> Unit): HandlerFunc {
    return { ctx: TangHttpContext =>
        match (ctx.compatContext()) {
            case Some(o) =>
                // Object 的向下转型结果是 Option（仓颉 as 返回 Option）
                match (o as HttpContext) {
                    case Some(hc) =>
                        handler(hc)
                        // stdx handler 已经直接写了响应，标记一下，外层不要再覆盖
                        ctx.markHandledByAdapter()
                    case None =>
                        throw Exception("fromStd: 适配器槽里不是 stdx HttpContext")
                }
            case None =>
                throw Exception("fromStd 只在使用 tang_ext_stdx.serve 时可用（当前是 tachyon server）")
        }
    }
}

/// 把 stdx 的 HttpContext 转成 tachyon 的请求快照
func toDetached(stdc: HttpContext): DetachedRequest {
    let req = stdc.request
    let d = DetachedRequest()
    d.method = req.method
    let rawPath = req.url.rawPath
    let path = if (rawPath.isEmpty()) { "/" } else { rawPath }
    d.target = match (req.url.rawQuery) {
        case Some(q) => if (q.isEmpty()) { path } else { path + "?" + q }
        case None => path
    }
    d.host = req.url.host
    for ((name, values) in req.headers) {
        for (v in values) {
            d.headers.add((name, v))
        }
    }
    d.body = readAll(req.body)
    return d
}

func readAll(stream: InputStream): Array<Byte> {
    let buf = ByteBuffer()
    let chunk = Array<Byte>(8192, repeat: 0)
    while (true) {
        let n = try {
            stream.read(chunk)
        } catch (e: Exception) {
            0
        }
        if (n <= 0) {
            break
        }
        buf.write(chunk[0..n])
    }
    return buf.bytes()
}

/// 把 tang 处理完的响应写回 stdx 的响应构造器
func writeBack(stdc: HttpContext, ctx: RequestCtx): Unit {
    let snap = snapshotResponse(ctx)
    stdc.responseBuilder.status(snap.statusCode)
    for ((k, v) in snap.headers) {
        // 这些由 stdx 自己算，重复设置会造成非法响应
        if (k.toAsciiLower() == "content-length") {
            continue
        }
        stdc.responseBuilder.header(k, v)
    }
    if (snap.body.size > 0) {
        stdc.responseBuilder.body(snap.body)
    }
}

/// 单个请求的桥接：stdx 收到的请求 → tachyon 上下文 → tang 路由 → 写回 stdx 响应
func bridge(app: Tang, stdc: HttpContext): Unit {
    let detached = toDetached(stdc)
    let ctx = newDetachedCtx(detached)
    let tangCtx = TangHttpContext(ctx, Params())
    tangCtx.setCompatContext(stdc)
    app.getRouter().handleWith(ctx, tangCtx)
    if (tangCtx.handledByAdapter()) {
        return
    }
    writeBack(stdc, ctx)
}

class TangDistributor <: HttpRequestDistributor {
    let app: Tang
    /// 兜底 handler：把请求整体桥接给 tang 路由
    let bridgeHandler: HttpRequestHandler
    /// stdx 风格的精确路径注册（distribute 时优先命中）
    let registered = HashMap<String, HttpRequestHandler>()

    init(app: Tang) {
        this.app = app
        this.bridgeHandler = FuncHandler({ stdc => bridge(app, stdc) })
    }

    /// 支持 stdx 风格的路径级注册：精确路径优先，其余交给 tang 路由
    public func register(path: String, handler: HttpRequestHandler): Unit {
        registered[path] = handler
    }

    public func distribute(path: String): HttpRequestHandler {
        match (registered.get(path)) {
            case Some(h) => h
            case None => bridgeHandler
        }
    }
}

/// 把 tang 应用跑在 stdx 的 server 上（阻塞）
public func serve(app: Tang, host: String, port: UInt16): Unit {
    let server = serveAsync(app, host, port)
    server.serve()
}

/// 把 tang 应用跑在 stdx 的 server 上（返回 server，调用方自己 serve / close）
public func serveAsync(app: Tang, host: String, port: UInt16): Server {
    return ServerBuilder()
        .addr(host)
        .port(port)
        .distributor(TangDistributor(app))
        .build()
}
