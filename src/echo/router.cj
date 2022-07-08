package echo

from std import sync.*
from std import net.*

public class Router  {
    public var config:Config
    public var group:Group
    let tree:Node
    let mu:Mutex = Mutex()

    init() {
        this.tree = Node("/","/")
        this.group = Group()
        this.config = Config(this.group)
        match (this.config.notFoundHandler) {
            case None => this.config.notFoundHandler = this.group.wrap(noFoundHandler)
            case _ => ()
        }
    }
    
    init(opts:Array<OptionFunc>) {
        this()
        this.group.router = this
        this.config.group = this.group 
        for (opt in opts) {
            opt(this.config)
        }
    }

    public func serveHTTP(w: ResponseWriteStream, r: Request):Unit {
        this.ServeHTTPError(w, r)
    }

    public func ServeHTTPError(w: ResponseWriteStream, r: Request):Unit {

    }

    public func lookup(w: ResponseWriteStream, r: Request):HandlerFunc * Params  {
        
    }
}

public class Params{
    var path:String
    var node:?Node
    var wildcardLen:UInt16
    public init(path:String, node:Node, wildcardLen:UInt16) {
        this.path = path
        this.node = node
        this.wildcardLen = wildcardLen
    }
    public func IsZero():Bool {
        match (this.node) {
            case None => true
            case Some(_) => false
        }
    }

    public func Route():?String {
      match (this.node) {
          case None => None
          case Some(n) => n.route
      }
    }

    public func Get(name:String):?String {
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

    public func findParam(parmIndex:Int64):?String {
        var path = this.path
        var pathLen = this.path.size()
        var currNode = this.node
        var currParamIndex = this.node?.params?.size() ?? 0
        
    }
}

func noFoundHandler(w:ResponseWriteStream, req:Request): Result<Unit> {
    notFound(w, req)
    return Ok(())
}