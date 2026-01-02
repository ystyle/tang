package tang

import std.fs.Path
import std.convert.*
import std.collection.{ArrayList, HashMap, HashSet}
import std.io.{ByteBuffer, InputStream}
import stdx.net.http.{FuncHandler, HttpStatusCode, HttpContext, HttpRequest, HttpResponseBuilder, FileHandler, FileHandlerType}
import stdx.encoding.url.{UserInfo, Form}
import stdx.crypto.x509.X509Certificate
import stdx.serialization.serialization.*
import stdx.encoding.json.stream.{JsonSerializable, JsonDeserializable, JsonWriter, JsonReader}
import stdx.encoding.base64.fromBase64String
import multipart.*
import tang.radix.RouteParams

public type HandlerFunc = (TangHttpContext) -> Unit

public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

public func httpHandlerFunc(handle: FuncHandler): HandlerFunc {
    return {
        ctx => handle.handle(ctx.context)
    }
}

public class TangHttpContext {
    var kv: ?HashMap<String, Any> = None  // 延迟初始化，减少 GC 压力
    let context: HttpContext
    let _params: Params
    var bodyraw: ?Array<Byte> = None
    var _multipartForm: ?MulitpartForm = None
    var _multipartFormBoundary:?String = None
    var _requestId: ?String = None  // 独立的 requestId 字段，避免使用 HashMap
    var _csrfToken: ?String = None  // 独立的 csrfToken 字段，避免使用 HashMap

    init(context: HttpContext, params: Params) {
        this.context = context
        this._params = params
    }
    public prop request: HttpRequest {
        get() {
            this.context.request
        }
    }
    public prop responseBuilder: HttpResponseBuilder {
        get() {
            this.context.responseBuilder
        }
    }
    public prop clientCertificate: Option<Array<X509Certificate>> {
        get() {
            this.context.clientCertificate
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
        var bs = Array<UInt8>(this.request.bodySize ?? 0, repeat: 0)
        this.request.body.read(bs)
        this.bodyraw = bs
        return bs
    }

    public func bindJson<T>(): ?T where T <: JsonDeserializable<T> {
        return T.fromJson(JsonReader(this.request.body))
    }

    public func bindQuery<T>(value: T): T where T <: Serializable<T> {
        let dm = value.serialize()
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let result = DataModelStruct()
        let fields = dms.getFields()
        let query = this.request.url.queryForm
        query.keys()
        for (f in fields) {
            let name = f.getName()
            let values = query.getAll(name)
            let data = f.getData()
            match (data) {
                case val: DataModelInt =>
                    if (let Some(v) <- Int64.tryParse(values[0])) {
                        result.add(field<Int64>(name, v))
                    }
                    ()
                case val: DataModelString =>
                    result.add(field<String>(name, values[0]))
                    ()
                case val: DataModelFloat =>
                    if (let Some(v) <- Float64.tryParse(values[0])) {
                        result.add(field<Float64>(name, v))
                    }
                case val: DataModelBool =>
                    if (let Some(v) <- Bool.tryParse(values[0])) {
                        result.add(field<Bool>(name, v))
                    }
                case val: DataModelSeq => println("[tang] unknow field type")
                case _ => println("[tang] unknow field type")
            }
        }
        return T.deserialize(result)
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
                        let password = splits[1]
                        return UserInfo(username, password)
                    }
                }
            }
        }
        return None
    }

    public func queries(): HashMap<String, Array<String>> {
        let map = HashMap<String, Array<String>>()
        let queryOption = this.request.url.query
        if (let Some(query) <- queryOption) {
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

    public func json<T>(value: T): Unit where T <: JsonSerializable  {
        this.jsonWithCode(HttpStatusCode.STATUS_OK, value)
    }

    public func jsonWithCode<T>(code: UInt16, value: T): Unit where T <: JsonSerializable  {
        let stream = ByteBuffer()
        this.responseBuilder.status(code).body(stream)
        let writer = JsonWriter(stream)
        value.toJson(writer)
        writer.flush()
        stream.flush()
    }
    public func writeString<T>(value: T): Unit where T <: ToString {
        this.writeStringWithCode(HttpStatusCode.STATUS_OK, value)
    }

    public func writeStringWithCode<T>(code: UInt16, value: T): Unit where T <: ToString {
        this.responseBuilder.status(code).body(value.toString())
    }

    public func write(bs:Array<Byte>):Unit {
        this.responseBuilder.body(bs)
    }

    public func download(path:Path):Unit {
        let hf = FileHandler(path.toString(), handlerType:FileHandlerType.DownLoad)
        hf.handle(this.context)
    }

    public func getHeader(key:String):?String {
        return this.request.headers.getFirst(key)
    }
}

public class Param {
    Param(let key: String, let Value: String) {}
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

extend Form {
    func keys(): Array<String> {
        let qs = this.toEncodeString()
        let pairs = qs.split("&")
        let keys = HashSet<String>()
        for (key in pairs) {
            if (let Some(i) <- key.indexOf("=")) {
                keys.add(key[0..i])
            }
        }
        return keys.toArray()
    }
}

