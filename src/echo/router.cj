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
}


func noFoundHandler(w:ResponseWriteStream, req:Request): Result<Unit> {
    notFound(w, req)
    return Ok(())
}