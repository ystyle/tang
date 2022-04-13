package echo

from std import collection.*
from std import net.*


public class Node {
    var route:String = ""
    var part:String = ""
    var params = HashMap<String, Int64>()
    var handleMap = HandleMap()
    var parent = Node()
    var colon = Node()
    var isWC = false
    var nodes = Buffer<Node>()
    var index:?Index = None
    init() {
        
    }
    init(route:String, part:String) {
        this.route = route
        this.part = part
    }
    func addRoute(route:String):Node {
        if (route == "/") {
            return this
        }
        return this
    }
}

public class Index {
    Index(let table:Array<UInt8>, let minChar:Char, let maxChar:Char) {}
}

func join(ss:Collection<String>, withSlash:Bool):String {
    if (ss.size() == 0) {
        return ""
    }
    let s = String.join(Array<String>(ss), delimiter: "/")
    if (withSlash) {
        return s + "/"
    }
    return s
}

type splitRouteResultType = Buffer<String> * Option<HashMap<String, Int64>>

func splitRoute(route:String):Result<splitRouteResultType> {
    if (route == "" || route[0] != '/') {
        return Err(Exception("invalid route: ${route}"))
    }
    if (route == "/") {
        let a: splitRouteResultType = (Buffer<String>(), None)
        return Ok(a)
    }
    let l_route = route[1..]
    let ss = l_route.split('/')
    if (ss.size() == 0) {
        return Err(Exception("invalid route: ${route}"))
    }
    let p = RouteParser(ss)
    var params = Buffer<String>()
    while (p.valid()) {
        let segment = p.next()
        if (segment == "") {
            p.accumulate("")
            continue
        }
        let firstChar = segment[0]
        match (firstChar) {
            case ':' => 
                p.finalizePart(true)
                p.parts.add(":")
                params.add(segment[1..])
            case '*' =>
                p.finalizePart(true)
                p.parts.add("*")
                params.add(segment[1..])
            case _ =>
                p.accumulate(segment)
        }
    }
    p.finalizePart(false)
    if (params.size() > 0) {
        return match (paramMap(route, params)) {
            case Err(e) => Err(e)
            case Ok(v) =>
                Ok((p.parts, v))
        }
    }

    return Err(Exception("invalid route: ${route}"))
}

func paramMap(route:String, params:Buffer<String>):Result<HashMap<String, Int64>> {
    let m = HashMap<String, Int64>(params.size())
    var i = 0
    while (i < params.size()) {
        let param = params[i]
        if (param == "") {
            return Err(Exception("param must have a name: " + route))
        }
        m.put(param, i)
    }
    return Ok(m)
}

class RouteParser {
    let segments:Array<String>
    var i:Int64 = 0
    var acc:Buffer<String>
    var parts:Buffer<String>
    init(segments:Array<String>) {
        this.segments = segments
        this.acc = Buffer<String>()
        this.parts = Buffer<String>()
    }
    func valid():Bool {
        return this.i < this.segments.size()
    }
    func next():String {
        let s = this.segments[this.i]
        this.i ++
        return s
    }
    func accumulate(s:String) {
        this.acc.add(s)
    }
    func finalizePart(withSlash:Bool) {
        let part = join(this.acc, withSlash)
        if (part != "") {
            this.parts.add(part)
        }
        this.acc.clear()
        if (this.valid()) {
            this.acc.add("")
        }
    }
}

public class HandleMap {
    var get:?HandlerFunc = None
    var post:?HandlerFunc = None
    var put:?HandlerFunc = None
    var delete:?HandlerFunc = None
    var head:?HandlerFunc = None
    var options:?HandlerFunc = None
    var patch:?HandlerFunc = None
    var notAllowed:?HandlerFunc = None
    init() {
    }

    func Get(meth:String):?HandlerFunc {
        match (meth) {
            case "GET" => this.get
            case "POST" => this.post
            case "PUT" => this.put
            case "DELETE" => this.delete
            case "HEAD" => this.head
            case "OPTIONS" => this.options
            case "PATCH" => this.patch
            case "NOTALLOWED" => this.notAllowed
            case _ => None
        }
    }

    func Set(meth:String, handler:HandlerFunc) {
        match (meth) {
            case "GET" => this.get = handler
            case "POST" => this.post = handler
            case "PUT" => this.put = handler
            case "DELETE" => this.delete = handler
            case "HEAD" => this.head = handler
            case "OPTIONS" => this.options = handler
            case "PATCH" => this.patch = handler
            case "NOTALLOWED" => this.notAllowed = handler
            case _ => ()
        }
    }
}
