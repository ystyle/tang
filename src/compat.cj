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

/// 状态码（只枚举 tang 用到的常量）
public enum HttpStatusCode {
    | STATUS_OK
    | STATUS_MOVED_PERMANENTLY
    | STATUS_FOUND
    | STATUS_BAD_REQUEST
    | STATUS_UNAUTHORIZED
    | STATUS_FORBIDDEN
    | STATUS_METHOD_NOT_ALLOWED
    | STATUS_REQUEST_CONTENT_TOO_LARGE
    | STATUS_TOO_MANY_REQUESTS
    | STATUS_INTERNAL_SERVER_ERROR
}

public func toUInt16(s: HttpStatusCode): UInt16 {
    match (s) {
        case STATUS_OK => return 200
        case STATUS_MOVED_PERMANENTLY => return 301
        case STATUS_FOUND => return 302
        case STATUS_BAD_REQUEST => return 400
        case STATUS_UNAUTHORIZED => return 401
        case STATUS_FORBIDDEN => return 403
        case STATUS_METHOD_NOT_ALLOWED => return 405
        case STATUS_REQUEST_CONTENT_TOO_LARGE => return 413
        case STATUS_TOO_MANY_REQUESTS => return 429
        case STATUS_INTERNAL_SERVER_ERROR => return 500
    }
}

/// 日志级别（原 stdx.log.LogLevel 的最小替身）
public enum LogLevel {
    | OFF
    | FATAL
    | ERROR
    | WARN
    | INFO
    | DEBUG
    | TRACE
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
            match (ctx.remoteAddr) {
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

    public func status(code: HttpStatusCode): TCResponseBuilder {
        ctx.setStatusCode(toUInt16(code))
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

    /// 与 stdx 对齐：build() 只是取最终响应对象，tachyon 在 handler 返回时统一写出
    public func build(): Unit {
        ()
    }
}