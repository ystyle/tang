package tang

from std import collection.*
from net import http.*


public class Node {
    var route:String = ""
    var part:String = ""
    var params = HashMap<String, Int64>()
    var handleMap = HandleMap()
    var parent = Node()
    var colon:?Node = None
    var isWC = false
    var nodes = ArrayList<Node>()
    var index:?Index = None
    init() {
        
    }
    init(route:String, part:String) {
        this.route = route
        this.part = part
    }
    init(part:String) {
        this.part = part
    }
    func addRoute(route:String):Node {
        if (route == "/") {
            return this
        }
        let (parts, l_params) = splitRoute(route)
        var currNode = this
        for (p in parts) {
            currNode = currNode.addPart(p)
        }
        currNode.route = route
        currNode.params = l_params ?? HashMap<String, Int64>()
        this.indexNodes()
        return currNode
    }
    public func addPart(part:String):Node {
        if (part == "*") {
            this.isWC = true
            return this
        }
        if (part == ":") {
            if (let None = this.colon) {
                this.colon = Node(":")
            }
            return this.colon.getOrThrow()
        }
        this.nodes.forEachWithIndex({childNodeIndex, childNode => 
            if (childNode.part[0] != part[0]) {
                return
            }
            // check for a common prefix
           let list = part.toArray()
        list. 
            ( )
        })
        // todo
        return this
    }
    public func indexNodes() {

    }
}

public class Index {
    Index(let table:Array<UInt8>, let minChar:Char, let maxChar:Char) {}
}

func join(ss:Array<String>, withSlash:Bool):String {
    if (ss.size() == 0) {
        return ""
    }
    let s = String.join(ss, delimiter: "/")
    if (withSlash) {
        return s + "/"
    }
    return s
}


func splitRoute(route:String):(ArrayList<String>, Option<HashMap<String, Int64>>) {
    if (route == "" || route[0] != '/') {
        throw Exception("invalid route: ${route}")
    }
    if (route == "/") {
        return (ArrayList<String>(), None)
    }
    let l_route = route[1..]
    let ss = l_route.split('/')
    if (ss.size() == 0) {
        throw Exception("invalid route: ${route}")
    }
    let p = RouteParser(ss)
    var params = ArrayList<String>()
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
                p.parts.append(":")
                params.append(segment[1..])
            case '*' =>
                p.finalizePart(true)
                p.parts.append("*")
                params.append(segment[1..])
            case _ =>
                p.accumulate(segment)
        }
    }
    p.finalizePart(false)
    if (params.size() > 0) {
        let v = paramMap(route, params)
        return (p.parts, v)        
    }

    throw Exception("invalid route: ${route}")
}

func paramMap(route:String, params:ArrayList<String>):HashMap<String, Int64> {
    let m = HashMap<String, Int64>(params.size())
    var i = 0
    while (i < params.size()) {
        let param = params[i]
        if (param == "") {
            throw Exception("param must have a name: " + route)
        }
        m.put(param, i)
    }
    return m
}

class RouteParser {
    let segments:Array<String>
    var i:Int64 = 0
    var acc:ArrayList<String>
    var parts:ArrayList<String>
    init(segments:Array<String>) {
        this.segments = segments
        this.acc = ArrayList<String>()
        this.parts = ArrayList<String>()
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
        this.acc.append(s)
    }
    func finalizePart(withSlash:Bool) {
        let part = join(this.acc, withSlash)
        if (let Some(v) = part) {
            this.parts.append(v)
        }
        this.acc.clear()
        if (this.valid()) {
            this.acc.append("")
        }
    }
}

func join (ss:Collection<String>, withSlash:Bool):?String {
    if (ss.isEmpty()) {
        return None
    }
    let s = String.join(ss.toArray(), delimiter:"/")
    if (withSlash) {
        return s + "/"
    }
    return s
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
