package tang

import std.io.{InputStream, ByteBuffer}
import std.collection.{ArrayList, HashMap}
import ystyle::tachyon.{RequestCtx, Bytes, ArgsView}

// ============================================================================
// stdx.net.http 的最小兼容层
//
// 目的：让 tang 的 HTTP 层脱离 stdx.net.http，改由 tachyon 承载。
// 这里只实现 tang 自身（含内置中间件）实际用到的那部分成员，
// 成员名与 stdx 保持一致，从而把改动限制在 import 与适配点上。
// ============================================================================

/// HTTP 协议版本
public enum Protocol {
    | HTTP1_0
    | HTTP1_1
    | HTTP2_0
    | UNKNOWN
}

public func toString(p: Protocol): String {
    match (p) {
        case HTTP1_0 => return "HTTP/1.0"
        case HTTP1_1 => return "HTTP/1.1"
        case HTTP2_0 => return "HTTP/2.0"
        case UNKNOWN => return "UNKNOWN"
    }
}

/// 状态码常量
///
/// 用 class + static let 而不是 enum：tang 里既有 .status(HttpStatusCode.X) 的用法，
/// 也有 var defaultStatus: UInt16 = HttpStatusCode.X 的用法，
/// 直接暴露成 UInt16 可以让两处都不必改写。
public class HttpStatusCode {
    public static let STATUS_OK: UInt16 = 200
    public static let STATUS_MOVED_PERMANENTLY: UInt16 = 301
    public static let STATUS_FOUND: UInt16 = 302
    public static let STATUS_BAD_REQUEST: UInt16 = 400
    public static let STATUS_UNAUTHORIZED: UInt16 = 401
    public static let STATUS_FORBIDDEN: UInt16 = 403
    public static let STATUS_NOT_FOUND: UInt16 = 404
    public static let STATUS_METHOD_NOT_ALLOWED: UInt16 = 405
    public static let STATUS_REQUEST_CONTENT_TOO_LARGE: UInt16 = 413
    public static let STATUS_TOO_MANY_REQUESTS: UInt16 = 429
    public static let STATUS_INTERNAL_SERVER_ERROR: UInt16 = 500
}


// ----------------------------------------------------------------------------
// 请求头
// ----------------------------------------------------------------------------

/// 请求头视图。名字大小写不敏感。
///
/// 兼容点：stdx 的 HttpHeaders 允许中间件往"请求头"里塞自定义字段
/// （tang 的 timeout 中间件就这么用），这些字段不属于原始报文，
/// 因此单独存在 added 里，读取时优先生效。
public class TCHeaders {
    let ctx: RequestCtx
    var added: ?HashMap<String, String> = None

    init(ctx: RequestCtx) {
        this.ctx = ctx
    }

    /// 取第一个值（不存在返回 None）
    public func getFirst(name: String): ?String {
        match (added) {
            case Some(m) =>
                match (m.get(name)) {
                    case Some(v) => return Some(v)
                    case None => ()
                }
            case None => ()
        }
        let v = ctx.headerGet(name)
        if (v.isEmpty()) {
            return None
        }
        return Some(v.toStr())
    }

    /// 取全部同名值（多值头）
    public func get(name: String): ArrayList<String> {
        let out = ArrayList<String>()
        match (added) {
            case Some(m) =>
                match (m.get(name)) {
                    case Some(v) => out.add(v)
                    case None => ()
                }
            case None => ()
        }
        let v = ctx.headerGet(name)
        if (!v.isEmpty()) {
            out.add(v.toStr())
        }
        return out
    }

    /// 追加一个"请求头"（供中间件传递上下文用；不进入原始报文）
    public func add(name: String, value: String): Unit {
        let m = match (added) {
            case Some(x) => x
            case None =>
                let x = HashMap<String, String>()
                added = Some(x)
                x
        }
        m[name] = value
    }
}

// ----------------------------------------------------------------------------
// URL
// ----------------------------------------------------------------------------

/// 查询表单（惰性解析）
public class TCForm {
    let args: ArgsView

    init(args: ArgsView) {
        this.args = args
    }

    public func get(key: String): ?String {
        let v = args.get(key)
        if (v.isEmpty()) {
            return None
        }
        return Some(v.toStr())
    }

    /// 全部键（签名与 stdx 的 Form 对齐）
    public func keys(): ArrayList<String> {
        let out = ArrayList<String>()
        let n = args.count()
        var i: Int64 = 0
        while (i < n) {
            out.add(args.keyAt(i).toStr())
            i += 1
        }
        return out
    }

    /// 取同名全部值
    public func getAll(key: String): ArrayList<String> {
        let out = ArrayList<String>()
        let v = args.get(key)
        if (!v.isEmpty()) {
            out.add(v.toStr())
        }
        return out
    }
}

/// URL 视图（由 tachyon 的解析结果即时构造，不额外分配）
public class TCUrl {
    let ctx: RequestCtx

    init(ctx: RequestCtx) {
        this.ctx = ctx
    }

    /// 解码后的路径
    public prop path: String {
        get() {
            ctx.path().toStr()
        }
    }

    /// 原始（未解码）路径。tachyon 在解析时已规范化 dot-segment 与多余斜杠，
    /// 所以这里与 path 相同；保留该成员是为了兼容 tang 的调用点。
    public prop rawPath: String {
        get() {
            ctx.path().toStr()
        }
    }

    /// 查询串（不含 '?'）
    public prop query: String {
        get() {
            let uri = ctx.requestURI().toStr()
            let idx = uri.indexOf("?")
            match (idx) {
                case Some(i) => return uri[i + 1..]
                case None => return ""
            }
        }
    }

    public prop queryForm: TCForm {
        get() {
            TCForm(ctx.queryArgs())
        }
    }

    public prop scheme: String {
        get() {
            if (ctx.isTLS()) {
                return "https"
            }
            return "http"
        }
    }

    /// host[:port]
    public prop host: String {
        get() {
            ctx.host().toStr()
        }
    }

    /// 仅主机名
    public prop hostName: String {
        get() {
            let h = ctx.host().toStr()
            let idx = h.lastIndexOf(":")
            match (idx) {
                case Some(i) => return h[0..i]
                case None => return h
            }
        }
    }

    public prop port: String {
        get() {
            let h = ctx.host().toStr()
            let idx = h.lastIndexOf(":")
            match (idx) {
                case Some(i) => return h[i + 1..]
                case None => return ""
            }
        }
    }
}

// ----------------------------------------------------------------------------
// 请求
// ----------------------------------------------------------------------------

public class TCRequest {
    let ctx: RequestCtx
    let u: TCUrl
    let h: TCHeaders

    init(ctx: RequestCtx) {
        this.ctx = ctx
        this.u = TCUrl(ctx)
        this.h = TCHeaders(ctx)
    }

    /// 方法名，如 "GET"（stdx 里是 Method 枚举，这里用 String，toString() 同样可用）
    public prop method: String {
        get() {
            ctx.method().toStr()
        }
    }

    public prop url: TCUrl {
        get() {
            u
        }
    }

    public prop headers: TCHeaders {
        get() {
            h
        }
    }

    /// 请求体（视图，不复制）
    public prop body: InputStream {
        get() {
            ByteBuffer(ctx.body().toArray())
        }
    }

    public prop bodySize: ?Int64 {
        get() {
            Some(ctx.body().size())
        }
    }

    public prop remoteAddr: String {
        get() {
            match (ctx.remoteAddress()) {
                case Some(a) => return a.toString()
                case None => return ""
            }
        }
    }

    public prop version: Protocol {
        get() {
            if (ctx.isHTTP11()) {
                return Protocol.HTTP1_1
            }
            return Protocol.HTTP1_0
        }
    }
}

// ----------------------------------------------------------------------------
// 响应
// ----------------------------------------------------------------------------

/// 响应构造器（链式）。真正的写出由 tachyon 的 Server 在 handler 返回后完成。
public class TCResponseBuilder {
    let ctx: RequestCtx

    init(ctx: RequestCtx) {
        this.ctx = ctx
    }

    public func status(code: UInt16): TCResponseBuilder {
        ctx.setStatusCode(code)
        return this
    }

    public func header(key: String, value: String): TCResponseBuilder {
        ctx.setHeader(key, value)
        return this
    }

    public func body(s: String): TCResponseBuilder {
        ctx.setBodyString(s)
        return this
    }

    public func body(b: Bytes): TCResponseBuilder {
        ctx.setBody(b)
        return this
    }

    public func body(b: Array<Byte>): TCResponseBuilder {
        ctx.setBodyArray(b)
        return this
    }

    public func body(s: InputStream): TCResponseBuilder {
        // 流式源：读到 EOF 后按定长写（json 等路径会走到这里）
        let data = ArrayList<Byte>()
        let buf = Array<Byte>(8192, repeat: 0)
        while (true) {
            let n = try {
                s.read(buf)
            } catch (e: Exception) {
                0
            }
            if (n <= 0) {
                break
            }
            var i: Int64 = 0
            while (i < n) {
                data.add(buf[i])
                i += 1
            }
        }
        let out = Array<Byte>(data.size, repeat: 0)
        var k: Int64 = 0
        while (k < data.size) {
            out[k] = data[k]
            k += 1
        }
        ctx.setBodyArray(out)
        return this
    }

    /// 与 stdx 对齐：build() 只是取最终响应对象，tachyon 在 handler 返回时统一写出
    public func build(): Unit {
        ()
    }
}

// ----------------------------------------------------------------------------
// Cookie
// ----------------------------------------------------------------------------

/// Set-Cookie 构造（原 stdx.net.http.Cookie 的最小替身）
public class Cookie {
    public var name: String
    public var value: String
    public var maxAge: ?Int64 = None
    public var path: String = ""
    public var domain: String = ""
    public var httpOnly: Bool = false
    public var secure: Bool = false
    public var sameSite: String = ""

    public init(name: String, value: String, maxAge!: ?Int64 = None, path!: String = "",
                domain!: String = "", httpOnly!: Bool = false, secure!: Bool = false,
                sameSite!: String = "") {
        this.name = name
        this.value = value
        this.maxAge = maxAge
        this.path = path
        this.domain = domain
        this.httpOnly = httpOnly
        this.secure = secure
        this.sameSite = sameSite
    }

    /// 生成 Set-Cookie 头的值
    public func toSetCookieString(): String {
        var sb = StringBuilder()
        sb.append(name)
        sb.append("=")
        sb.append(value)
        if (!path.isEmpty()) {
            sb.append("; Path=")
            sb.append(path)
        }
        if (!domain.isEmpty()) {
            sb.append("; Domain=")
            sb.append(domain)
        }
        match (maxAge) {
            case Some(v) =>
                sb.append("; Max-Age=")
                sb.append(v.toString())
            case None => ()
        }
        if (httpOnly) {
            sb.append("; HttpOnly")
        }
        if (secure) {
            sb.append("; Secure")
        }
        if (!sameSite.isEmpty()) {
            sb.append("; SameSite=")
            sb.append(sameSite)
        }
        return sb.toString()
    }
}