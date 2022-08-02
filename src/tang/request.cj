package tang
from std import collection.ArrayList
from net import http.ResponseWriteStream, http.Request as HttpRequest, http.Handler as HttpHandler, http.FuncHandler
from std import convert.parseInt64

type HandlerFunc = (ResponseWriteStream, Request) -> Unit

type MiddlewareFunc = (HandlerFunc) -> HandlerFunc

public func HTTPHandler(handler:HttpHandler):HandlerFunc {
    return HTTPHandlerFunc(handler)
}

public func HTTPHandlerFunc(handle:HttpHandler):HandlerFunc  {
    return {w, r =>
        handle.serveHTTP(w, r.request)
        ()
    }
}

public class Request {
    var request:HttpRequest
    var params:Params
    public init(req:HttpRequest) {
        this.request = req
        // todo
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
        return this.params.route()
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

    public func route():String {
      match (this.node) {
          case None => ""
          case Some(n) => n.route
      }
    }

    public func get(name:String):String {
        match (this.node) {
            case None => ""
            case Some(n) => 
                if (n.params.contains(name)) {
                    let i = n.params[name]
                    this.findParam(i) ?? ""
                } else {
                    ""
                }
        }
    }

    public func byName (name:String):String {
        return this.get(name)
    }

    public func int64(name:String):Int64 {
        let i = this.byName(name)
        return parseInt64(i) ?? 0
    }

    func findParam(parmIndex:Int64):?String {
        var path = this.path
        var pathLen = this.path.size()
        var currNode = this.node
        var params = this.node?.params
        var currParamIndex = params?.size() ?? 0
        // todo
        return ""
    }

    public func slice():Array<?Param> {
        var list = Array<?Param>()
        if (let Some(n) = this.node) {
            list = Array<?Param>(n.params.size(), item: None)
            for ((k, v) in n.params) {
                if (let Some(value) = this.findParam(v)) {
                    list[v] = Param(k, value)
                }
            }
        }
        return list
    }
}