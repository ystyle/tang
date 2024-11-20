package tang

import std.collection.{ArrayList, HashMap, HashSet}
import net.http.{FuncHandler, HttpStatusCode, HttpContext, HttpRequest, HttpResponseBuilder}
import encoding.url.{UserInfo, Form}
import crypto.x509.X509Certificate
import std.convert.*
import std.io.ByteBuffer
import serialization.serialization.*
import encoding.json.*
import encoding.json.stream.{JsonSerializable, JsonWriter}
import encoding.base64.fromBase64String

public type HandlerFunc = (TangHttpContext) -> Unit

public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

public func httpHandlerFunc(handle: FuncHandler): HandlerFunc {
    return {
        ctx => handle.handle(ctx.context)
    }
}

public class TangHttpContext {
    var kv = HashMap<String, Any>()
    let context: HttpContext
    let _params: Params
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
        let v = this.kv.get(key)
        if (let None <- v) {
            return None
        }
        let vv = v.getOrThrow()
        return vv as T
    }

    public func kvSet(key: String, value: Any): Unit {
        this.kv[key] = value
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

    public func bindJSON<T>(): ?T where T <: Serializable<T> {
        var bs = Array<UInt8>(this.request.bodySize ?? 0, repeat: 0)
        this.request.body.read(bs)
        let body = String.fromUtf8(bs)
        var jv: JsonValue = JsonValue.fromStr(body)
        let dm = DataModel.fromJson(jv)
        return T.deserialize(dm)
    }
    public func bindQuery<T>(value: Box<T>) where T <: Serializable<T> {
        let v: T = value.value
        value.value = this.bindQuery(v)
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

    public func parseQuery(): HashMap<String, Array<String>> {
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

    public func json<T>(value: T): Unit where T <: Serializable<T> {
        this.jsonWithCode(HttpStatusCode.STATUS_OK, value)
    }
    public func json(value: JsonSerializable) {
        this.jsonWithCode(HttpStatusCode.STATUS_OK, value)
    }
    public func jsonWithCode<T>(code: UInt16, value: T): Unit where T <: Serializable<T> {
        this.responseBuilder.status(code).body(value.serialize().toJson().toJsonString())
    }
    public func jsonWithCode(code: UInt16, value: JsonSerializable) {
        let stream = ByteBuffer() // output
        let writer = JsonWriter(stream) // init a JsonWriter
        value.toJson(writer)
        this.responseBuilder.status(code).body(stream)
    }
    public func writeString<T>(value: T): Unit where T <: ToString {
        this.writeStringWithCode(HttpStatusCode.STATUS_OK, value)
    }

    public func writeStringWithCode<T>(code: UInt16, value: T): Unit where T <: ToString {
        this.responseBuilder.status(code).body(value.toString())
    }
}

public class Param {
    Param(let key: String, let Value: String) {}
}

public class Params {
    var path: String
    var node: ?Node
    var wildcardLen: UInt16
    public init() {
        this.path = ""
        this.node = None
        this.wildcardLen = 0
    }
    public init(path: String, node: Node, wildcardLen: UInt16) {
        this.path = path
        this.node = node
        this.wildcardLen = wildcardLen
    }

    public func isZero(): Bool {
        match (this.node) {
            case None => true
            case Some(_) => false
        }
    }

    public func route(): ?String {
        match (this.node) {
            case None => None
            case Some(n) => n.route
        }
    }

    public func get(name: String): ?String {
        match (this.node) {
            case None => None
            case Some(n) =>
                if (n.params.contains(name)) {
                    let i = n.params[name]
                    this.findParam(i)
                } else {
                    None
                }
        }
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

    func findParam(paramIndex: Int64): ?String {
        var path = this.path
        var pathLen = this.path.size
        var currNode = this.node
        var params = this.node?.params
        var currParamIndex = (params?.size ?? 0) - 1
        if (let Some(n) <- this.node) {
            if (n.isWC) {
                if (currParamIndex == paramIndex) {
                    pathLen -= Int64(this.wildcardLen)
                    return path[pathLen..]
                }
                currParamIndex--
                pathLen -= Int64(this.wildcardLen)
                path = path[..pathLen]
            }
        }

        while (true) {
            match (currNode) {
                case None => break
                case Some(n) =>
                    if (n.part.toRuneArray()[0] != r':') {
                        pathLen -= n.part.size
                        path = path[..pathLen]
                        currNode = n.parent
                        continue
                    }
                    let i = path.lastIndexOf('/')
                    if (let Some(v) <- i) {
                        pathLen = v + 1
                    } else {
                        return None
                    }

                    if (currParamIndex == paramIndex) {
                        println(path)
                        return path[pathLen..]
                    }
                    currParamIndex--
                    path = path[..pathLen]
                    currNode = n.parent
            }
        }
        return None
    }

    public func map(): HashMap<String, String> {
        let m = HashMap<String, String>()
        if (let Some(n) <- this.node) {
            for ((param, v) in n.params) {
                let value = this.findParam(v)
                if (let Some(vl) <- value) {
                    m[param] = vl
                }
            }
        }
        return m
    }
    public func slice(): Array<?Param> {
        var list = Array<?Param>()
        if (let Some(n) <- this.node) {
            list = Array<?Param>(n.params.size, repeat: None)
            for ((k, v) in n.params) {
                if (let Some(value) <- this.findParam(v)) {
                    list[v] = Param(k, value)
                }
            }
        }
        return list
    }
}

extend Form {
    func keys(): Array<String> {
        let qs = this.toEncodeString()
        let pairs = qs.split("&")
        let keys = HashSet<String>()
        for (key in pairs) {
            if (let Some(i) <- key.indexOf("=")) {
                keys.put(key[0..i])
            }
        }
        return keys.toArray()
    }
}
