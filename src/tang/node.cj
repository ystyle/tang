package tang

from std import collection.{ HashMap, ArrayList, StringBuilder }

public class Node {
    var route:String = ""
    var part:String = ""
    var params = HashMap<String, Int64>()
    var handleMap = HandleMap()
    var parent:?Node = None
    var colon:?Node = None
    var isWC = false
    var nodes = ArrayList<Node>()
    var index:Index = Index([], ' ', ' ')
    init() {
        
    }
    init(route:String, part:String) {
        this.route = route
        this.part = part
    }
    init(part:String) {
        this.part = part
    }
    init (part:String, nodes:ArrayList<Node>) {
        this.part = part
        this.nodes = nodes
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
        for(childNodeIndex in 0..this.nodes.size) {
            let childNode = this.nodes[childNodeIndex]
            if (childNode.part[0] != part[0]) {
                continue
            }
            // check for a common prefix
            for (i in 0..part.size) {
                if (i == childNode.part.size) {
                    break
                }
                let c = part[i]
                if (c == childNode.part[i]) {
                    continue
                }
                childNode.part = childNode.part[i..]
                let newNode = Node(part[i..])
                this.nodes[childNodeIndex] = Node(part[i..], ArrayList([childNode, newNode]))
                return newNode
            }
            // Parts match completely.
            if (part.size > childNode.part.size) {
                let p = part[childNode.part.size..]
                return childNode.addPart(p)
            } else if (part.size < childNode.part.size) {
                childNode.part = childNode.part[part.size..]
                let newNode = Node(part, ArrayList([childNode]))
                this.nodes[childNodeIndex] = newNode
                return newNode
            } else {
                return childNode
            }
        }
        let node = Node(part)
        this.nodes.append(node)
        return node
    }

    func findRoute(meth:String, path:String):(?Node, ?HandlerFunc, UInt16) {
        if (path.isEmpty()) {
            return (None, None, 0)
        }
        let p = path[1..] // strip leading "/"
        if (p.isEmpty()) {
           return (this, this.handleMap.get(meth), 0)
        }
        return this.findrouteImpl(meth, p)
    }

    func findrouteImpl(meth:String, path:String):(?Node, ?HandlerFunc, UInt16) {
        var found:?Node = None
        let firstChar = path[0]
        if (firstChar >= this.index.minChar && firstChar <= this.index.maxChar) {
            let i = this.index.table[Int64(UInt32(firstChar)-UInt32(this.index.minChar))]
            if (i != 0) {
                let childNode = this.nodes[Int64(i)-1]
                if (childNode.part == path) {
                    let handler = childNode.handleMap.get(meth)
                    if (let Some(fn) = handler) {
                        return (childNode, fn, 0)
                    }
                    found = childNode
                } else {
                    let partLen = childNode.part.size
                    if (path.startsWith(childNode.part)) {
                        let (node, handler, wildcardLen) = childNode.findrouteImpl(meth, path[partLen..])
                        if (let Some(fn) = handler) {
                            return (node, fn, wildcardLen)
                        }
                        if (let Some(n) = node ) {
                            found = node
                        }
                    }
                }
            }
        }

        if (let Some(colon_) = this.colon) {
            let i = path.indexOf('/') ?? -1
            if (i > 0) {
                let (node, handler, wildcardLen) = colon_.findrouteImpl(meth, path[i..])
                if (let Some(fn) = handler) {
                    return (node, fn, wildcardLen)
                }
            } else {
                let handler = colon_.handleMap.get(meth)
                if (let Some(fn) = handler) {
                    return (colon_, fn, 0)
                }
                if (let None = found) {
                    found = colon_
                }
            }
        }

        if (this.isWC) {
            let handler = this.handleMap.get(meth)
            if (let Some(fn) = handler) {
                    return (this, fn, UInt16(path.size))
            }
            if (let None = found) {
                found = this
            }
        }
        return (found, None, 0)
    }

    public func indexNodes():Unit {
        if (this.nodes.size > 0) {
            this.nodes.sortBy({n1, n2 =>
                if (n1.part[0] < n2.part[0]) {
                    return Ordering.LT
                } else if (n1.part[0] > n2.part[0]) {
                    return Ordering.GT
                }
                return Ordering.EQ
            })
            this.index.minChar = this.nodes[0].part[0]
            this.index.maxChar = this.nodes[this.nodes.size-1].part[0]
            let size = Int64(UInt32(this.index.maxChar) - UInt32(this.index.minChar)) + 1
            if (this.index.table.size != size) {
                this.index.table = Array(size, item: 0)
            } else {
                for (i in 0..this.index.table.size) {
                    this.index.table[i] = 0
                }
            }
            // Index nodes by the first char in a part.
            for (childNodeIndex in 0..this.nodes.size) {
                let childNode = this.nodes[childNodeIndex]
                childNode.parent = this
                childNode.indexNodes()
                let firstChar = UInt32(childNode.part[0]) - UInt32(this.index.minChar)
                this.index.table[Int64(firstChar)] = UInt8(childNodeIndex + 1)
            }

        }
        if (let Some(c) = this.colon) {
            c.parent = this
            c.indexNodes()
        }
        return ()
    }

    func setHandler(verb:String, handler:HandlerFunc) {
        if (let Some(_) = this.handleMap.get(verb) ){
            throw Exception("${this.route} already handles ${verb}")
        }
        this.handleMap.set(verb, handler)
    }
}

public class Index {
    Index(var table:Array<UInt8>, var minChar:Char, var maxChar:Char) {}
}

func join(ss:Array<String>, withSlash:Bool):String {
    if (ss.size == 0) {
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
    if (ss.size == 0) {
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
    if (params.size > 0) {
        let v = paramMap(route, params)
        return (p.parts, v)        
    }
    return (p.parts, None)
}

func paramMap(route:String, params:ArrayList<String>):HashMap<String, Int64> {
    let m = HashMap<String, Int64>(params.size)
    var i = 0
    while (i < params.size) {
        let param = params[i]
        if (param == "") {
            throw Exception("param must have a name: " + route)
        }
        m.put(param, i)
        i ++
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
        return this.i < this.segments.size
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
    var get_:?HandlerFunc = None
    var post:?HandlerFunc = None
    var put:?HandlerFunc = None
    var delete:?HandlerFunc = None
    var head:?HandlerFunc = None
    var options:?HandlerFunc = None
    var patch:?HandlerFunc = None
    var notAllowed:?HandlerFunc = None
    init() {
    }

    func get(meth:String):?HandlerFunc {
        match (meth) {
            case "GET" => this.get_
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

    func set(meth:String, handler:HandlerFunc) {
        match (meth) {
            case "GET" => this.get_ = handler
            case "POST" => this.post = handler
            case "PUT" => this.put = handler
            case "DELETE" => this.delete = handler
            case "HEAD" => this.head = handler
            case "OPTIONS" => this.options = handler
            case "PATCH" => this.patch = handler
            case "NOTALLOWED" => this.notAllowed = handler
            case _ => throw Exception("unknown HTTP method: ${meth}")
        }
    }
}
