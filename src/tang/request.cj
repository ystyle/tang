package tang
from std import collection.{ArrayList, HashMap}
from net import http.{ ResponseWriteStream, Request as HttpRequest, Handler as HttpHandler, FuncHandler, HttpStatusCode }
from std import convert.*
from serialization import serialization.*
from encoding import json.*

public type HandlerFunc = (ResponseWriteStream, Request) -> Unit

public type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

public func httpHandler(handler:HttpHandler):HandlerFunc {
    return httpHandlerFunc(handler)
}

public func httpHandlerFunc(handle:HttpHandler):HandlerFunc  {
    return {w, r =>
        handle.serveHTTP(w, r.request)
        return ()
    }
}

public class Request {
    public var request:HttpRequest
    public var params:Params
    public init(req:HttpRequest) {
        this.request = req
        this.params = Params("/", Node(), UInt16(0))
    }
    public init(req:HttpRequest, params:Params) {
        this.request = req
        this.params = params
    }
    public func param(key:String):String {
        return this.params.byName(key)
    }
    public func route():String {
        return this.params.route() ?? "/"
    }
    public func bindJSON<T>():?T where T <: Serializable<T>  {
        var bs = Array<UInt8>(this.request.body.length, item:0)
        this.request.body.read(bs)
        let body = String.fromUtf8(bs)
        var jv: JsonValue = JsonValue.fromStr(body)
        let dm = DataModel.fromJson(jv)
        return T.deserialize(dm)
    }
    public func bindQuery<T>(value:Box<T>) where T <: Serializable<T> {
        let v:T = value.value
        value.value = this.bindQuery(v)
    }
    public func bindQuery<T>(value:T):T where T <: Serializable<T> {
        let dm =value.serialize()
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let result = DataModelStruct()
        let fields = dms.getFields()
        let query = this.request.url.query()
        for (f in fields) {
            let name = f.getName()
            if (let Some(raw) = query.get(name)) {
                let data = f.getData()
                match(data) {
                    case val:DataModelInt =>
                        if (let Some(v) = Int64.tryParse(raw)) {
                            result.add(field<Int64>(name, v))
                        }
                        ()
                    case val:DataModelString =>
                        result.add(field<String>(name, raw))
                        ()
                    case val:DataModelFloat =>
                        if (let Some(v) = Float64.tryParse(raw)) {
                            result.add(field<Float64>(name, v))
                        }
                    case val:DataModelBool =>
                        if (let Some(v) = Bool.tryParse(raw)) {
                            result.add(field<Bool>(name, v))
                        }
                    case val:DataModelSeq => println("[tang] unsuport field type: Array => ${name}")
                    case val:DataModelStruct => println("[tang] unsuport field type: Object => ${name}")
                    case val:DataModelNull => println("[tang] unsuport field type: Option => ${name}")
                    case _ => println("[tang] unknow field type")
                }
            }
        }
        return T.deserialize(result)
    }
}

public class Param {
    Param(let key:String, let Value:String){}
}

public class Params{
    var path:String
    var node:?Node
    var wildcardLen:UInt16
    public init() {
        this.path = ""
        this.node = None
        this.wildcardLen = 0
    }
    public init(path:String, node:Node, wildcardLen:UInt16) {
        this.path = path
        this.node = node
        this.wildcardLen = wildcardLen
    }

    public func isZero():Bool {
        match (this.node) {
            case None => true
            case Some(_) => false
        }
    }

    public func route():?String {
      match (this.node) {
          case None => None
          case Some(n) => n.route
      }
    }

    public func get(name:String):?String {
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

    public func byName (name:String):String {
        return this.get(name) ?? ""
    }

    public func int64(name:String):?Int64 {
        let i = this.get(name)
        if (let Some(v) = i) {
            return Int64.tryParse(v)
        }
        return None
    }

    func findParam(paramIndex:Int64):?String {
        var path = this.path
        var pathLen = this.path.size
        var currNode = this.node
        var params = this.node?.params
        var currParamIndex = (params?.size ?? 0) -1
        if (let Some(n) = this.node) {
            if (n.isWC) {
                if (currParamIndex == paramIndex) {
                    pathLen -= Int64(this.wildcardLen)
                    return path[pathLen..]
                }
                currParamIndex --
                pathLen -= Int64(this.wildcardLen)
                path = path[..pathLen]
            }
        }

        while (true) {
             match (currNode) {
                case None  => break
                case Some(n) =>
                if (n.part[0] != ':') {
                    pathLen -= n.part.size
                    path = path[..pathLen]
                    currNode = n.parent
                    continue
                }
                let i = path.lastIndexOf('/')
                if (let Some(v) = i) {
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

    public func map():HashMap<String,String> {
        let m = HashMap<String,String>()
        if (let Some(n) = this.node) {
            for ((param, v) in n.params) {
                let value = this.findParam(v)
                if(let Some(vl) = value) {
                    m[param] = vl
                }
            }
        }
        return m
    }
    public func slice():Array<?Param> {
        var list = Array<?Param>()
        if (let Some(n) = this.node) {
            list = Array<?Param>(n.params.size, item: None)
            for ((k, v) in n.params) {
                if (let Some(value) = this.findParam(v)) {
                    list[v] = Param(k, value)
                }
            }
        }
        return list
    }
}

public func json<T>(w: ResponseWriteStream, value:T) where T <: Serializable<T>  {
    jsonWithCode(w, HttpStatusCode.STATUS_OK, value)
}

public func jsonWithCode<T>(w: ResponseWriteStream, code:Int64, value:T) where T <: Serializable<T>  {
    w.writeStatusCode(code)
    w.write(value.serialize().toJson().toJsonString().toUtf8Array())
}

public func plainString<T>(w: ResponseWriteStream, value:T) where T <: ToString   {
    plainStringWithCode(w, HttpStatusCode.STATUS_OK, value)
}

public func plainStringWithCode<T>(w: ResponseWriteStream, code:Int64, value:T) where T <: ToString {
    w.writeStatusCode(code)
    w.write(value.toString().toUtf8Array())
}
