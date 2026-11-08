package tang

import std.fs.{Path, File}
import std.convert.*
import std.collection.{ArrayList, HashMap, HashSet}
import std.io.{ByteBuffer, InputStream}
import ystyle::tachyon.{RequestCtx, Server}
import opencj::multipart.*
import tang.radix.RouteParams

public type HandlerFunc = (TangHttpContext) -> Unit

public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

public class TangHttpContext {
    var kv: ?HashMap<String, Any> = None  // 延迟初始化，减少 GC 压力
    let _ctx: RequestCtx
    var _params: Params
    var _req: ?TCRequest = None
    var _resp: ?TCResponseBuilder = None
    var bodyraw: ?Array<Byte> = None
    var _multipartForm: ?MulitpartForm = None
    var _multipartFormBoundary:?String = None
    /// 适配器槽：让扩展成员把「外来上下文」（如 stdx 的 HttpContext）挂在当前请求上。
    /// 用 Object 而不是具体类型，core 才能保持零依赖。
    var _compatContext: ?Object = None
    /// 由适配器（如 fromStd）标记：响应已经由适配器自己写出，core 不要再用快照覆盖。
    var _handledByAdapter: Bool = false
    var _requestId: ?String = None  // 独立的 requestId 字段，避免使用 HashMap
    var _csrfToken: ?String = None  // 独立的 csrfToken 字段，避免使用 HashMap

    public init(ctx: RequestCtx, params: Params) {
        this._ctx = ctx
        this._params = params
    }

    /// 底层 tachyon 请求上下文（hijack、setBodyStream 等高级操作用）
    public prop raw: RequestCtx {
        get() {
            this._ctx
        }
    }

    public prop request: TCRequest {
        get() {
            match (this._req) {
                case Some(r) => r
                case None =>
                    let r = TCRequest(this._ctx)
                    this._req = Some(r)
                    r
            }
        }
    }

    public prop responseBuilder: TCResponseBuilder {
        get() {
            match (this._resp) {
                case Some(r) => r
                case None =>
                    let r = TCResponseBuilder(this._ctx)
                    this._resp = Some(r)
                    r
            }
        }
    }

    public func kvGet<T>(key: String): ?T {
        if (let Some(map) <- this.kv) {
            let v = map.get(key)
            if (let None <- v) {
                return None
            }
            let vv = v.getOrThrow()
            return vv as T
        }
        return None
    }

    public func kvSet(key: String, value: Any): Unit {
        if (let None <- this.kv) {
            this.kv = HashMap<String, Any>()
        }
        if (let Some(map) <- this.kv) {
            map[key] = value
        }
    }
    public func param(key: String): String {
        return this._params.byName(key)
    }
    public func params(): HashMap<String, String> {
        return this._params.map()
    }
    public func route(): String {
        return this._params.route() ?? "/"
    }

    public func baseURL(): String {
        let host = this.request.url.host
        let schema = this.request.url.scheme
        return "${schema}://${host}"
    }

    public func hostName(): String {
        return this.request.url.hostName
    }

    public func ip(): String {
        return this.request.remoteAddr
    }
    public func ips(): ArrayList<String> {
        return ArrayList<String>(this.request.headers.get("X-Forwarded-For"))
    }

    public func bodyRaw():Array<Byte> {
        if (let Some(v) <- this.bodyraw) {
            return v 
        }
        let total = this.request.bodySize ?? 0
        var bs = Array<UInt8>(total, repeat: 0)
        // 必须**循环**读到 total 字节：网络流的 read() 允许短读（返回实际读到的字节数），
        // 只调一次会让剩余部分保持 0 填充 → 请求体被静默损坏。
        // 实测症状：cjreg 的 `POST /pkg` 发布，3KB 的包侥幸通过、21KB 的包尾部全变 0
        // → 服务端算出的 tarball sha256 与客户端声明不符，发布永远 400。
        // 注：bodySize 为 None（chunked 无长度）时 total=0，此处读不到内容——属既有行为。
        var off: Int64 = 0
        let chunk: Int64 = 8192
        let buf = Array<UInt8>(chunk, repeat: 0)
        while (off < total) {
            let n = this.request.body.read(buf)
            if (n <= 0) {
                break   // 对端提前结束：只能拿到已读部分（保持既有尽力而为语义）
            }
            let rest = total - off
            let take = if (n < rest) { n } else { rest }
            for (i in 0..take) {
                bs[off + i] = buf[i]
            }
            off += take
        }
        this.bodyraw = bs
        return bs
    }

    // bindJson 已移到扩展成员（如 tang_ext_json_seajson 的 bindJson<T>(ctx)）

    /// 按 QueryBindable 接口绑定查询参数（core 零依赖；适配器版本见扩展成员）
    public func bindQuery<T>(value: T): T where T <: QueryBindable {
        let form = this.request.url.queryForm
        let params = QueryParams({ k: String =>
            form.get(k)
        })
        value.bindQuery(params)
        return value
    }

    public func basicAuth(): Option<UserInfo> {
        if (let Some(v) <- this.request.headers.getFirst("Authorization")) {
            if (v.startsWith("Basic ")) {
                var line = v.removePrefix("Basic ")
                if (let Some(bs) <- fromBase64String(line)) {
                    line = String.fromUtf8(bs)
                    let splits = line.split(":")
                    if (splits.size == 2) {
                        let username = splits[0]
                        let pwd = splits[1]
                        return UserInfo(username, pwd)
                    }
                }
            }
        }
        return None
    }

    public func queries(): HashMap<String, Array<String>> {
        let map = HashMap<String, Array<String>>()
        let query = this.request.url.query
        if (query.size > 0) {
            let splits = query.split('&')
            for (spilt in splits) {
                if (spilt.contains(';')) {
                    println("invalid semicolon separator in query")
                    continue
                }
                let values = spilt.split('=')
                var key: String = ""
                if (values.size > 0) {
                    key = values[0]
                }
                var value: String = ""
                if (values.size > 1) {
                    value = values[1]
                }
                if (map.contains(key)) {
                    let v = map[key]
                    var vv = Array<String>(v.size + 1, repeat: "")
                    v.copyTo(vv, 0, 0, v.size)
                    vv[v.size] = value
                    map[key] = vv
                } else {
                    map[key] = Array<String>(1, repeat: value)
                }
            }
        }
        return map
    }

    public func contentType():?String {
        return this.getHeader("Content-Type")
    }

    public func multipartFormBoundary():?String {
        let contentTypeOpt = this.contentType()
        let contentType = if(contentTypeOpt.isNone()) {
            return None
        } else {
            contentTypeOpt.getOrThrow()
        }
        if (!contentType.startsWith("multipart/form-data")) {
            return None
        }
        return contentType.trimStart("multipart/form-data; boundary=")
    }

    public func multipartForm(): ?MulitpartForm {
        if (this._multipartForm.isSome()) {
            return this._multipartForm
        }
        this._multipartFormBoundary = this.multipartFormBoundary()
        if (let None <- this._multipartFormBoundary) {
            throw Exception("request Content-Type has bad boundary or is not multipart/form-data")
        }
        let multipartFormBoundary = this._multipartFormBoundary ?? ""
        let mr = MulitpartReader(this.request.body, multipartFormBoundary.toArray())
        this._multipartForm = mr.form
        return this._multipartForm
    }

    public func fromValue(key:String, defaultvalue!:?String = None):?String {
        let formopt = this.multipartForm()
        if (formopt.isNone()) {
            return None
        }
        let form = formopt.getOrThrow()
        let v = form.values.get(key)
        return v?[0] ?? defaultvalue
    }

    public func fromFile(key:String):?MultipartFile {
        let formopt = this.multipartForm()
        if (formopt.isNone()) {
            return None
        }
        let form = formopt.getOrThrow()
        return form.files.get(key)?[0]
    }

    public func query(key:String):?String {
        return this.request.url.queryForm.get(key)
    }

    public func queryBool(key:String):?Bool {
        let v = this.request.url.queryForm.get(key)
        if (let None <- v) {
            return None
        }
        return Bool.tryParse(v??"")
    }

    public func queryFloat(key:String): ?Float64 {
        let v = this.request.url.queryForm.get(key)
        if (let None <- v) {
            return None
        }
        return Float64.tryParse(v??"")
    }

    public func queryInt(key:String):?Int64 {
        let v = this.request.url.queryForm.get(key)
        if (let None <- v) {
            return None
        }
        return Int64.tryParse(v??"")
    }

    /// 用注册的 JSON codec 输出 JSON（codec 未注册时抛异常，便于尽早发现漏装适配器）
    public func json<T>(value: T): Unit {
        this.jsonWithCode(200, value)
    }

    public func jsonWithCode<T>(code: UInt16, value: T): Unit {
        let codec = match (getJsonCodec()) {
            case Some(c) => c
            case None => throw Exception("没有注册 JSON codec：启动时调用 useSeaJson() 等适配器")
        }
        let sink = BufferJsonSink()
        codec.encodeTo(sink, value)
        sink.finish()
        this.responseBuilder.status(code)
        this.responseBuilder.header("Content-Type", codec.contentType())
        this.responseBuilder.body(sink.toString())
    }
    /// 只写 body，不动状态码（否则 ctx.status(400).writeString(...) 会被重置成 200）
    public func writeString<T>(value: T): Unit where T <: ToString {
        this.responseBuilder.body(value.toString())
    }

    public func writeStringWithCode<T>(code: UInt16, value: T): Unit where T <: ToString {
        this.responseBuilder.status(code).body(value.toString())
    }

    public func write(bs:Array<Byte>):Unit {
        this.responseBuilder.body(bs)
    }

    public func download(path:Path):Unit {
        // 下载：读文件内容 + Content-Disposition（tachyon 无 FileHandler，直接读字节）
        try {
            let content = File.readFrom(path)
            let q = "\"\""
            this.responseBuilder.header("Content-Disposition", "attachment; filename=" + q + path.fileName + q)
            this.responseBuilder.body(content)
        } catch (e: Exception) {
            this.responseBuilder.status(HttpStatusCode.STATUS_NOT_FOUND).body("404 page not found")
        }
    }

    public func getHeader(key:String):?String {
        return this.request.headers.getFirst(key)
    }
}

public class Params {
    var values: HashMap<String, String> = HashMap<String, String>()

    public init() {
    }

    public init(routeParams: RouteParams) {
        routeParams.forEach({ key, value =>
            this.values[key] = value
        })
    }

    public func isZero(): Bool {
        return this.values.size == 0
    }

    public func route(): ?String {
        return None
    }

    public func get(name: String): ?String {
        if (this.values.contains(name)) {
            return Some(this.values[name])
        }
        return None
    }

    public func byName(name: String): String {
        return this.get(name) ?? ""
    }

    public func int64(name: String): ?Int64 {
        let i = this.get(name)
        if (let Some(v) <- i) {
            return Int64.tryParse(v)
        }
        return None
    }

    public func map(): HashMap<String, String> {
        return this.values
    }
}

