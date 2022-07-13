package tang

from std import collection.*

public class Group {
    var router:?Router
    let path:String
    var stack = ArrayList<MiddlewareFunc>()

    init(router:Router, path:String, stack:ArrayList<MiddlewareFunc>) {
        this.router = router
        this.path = path
        this.stack = stack
    }

    // init(path:String, opts!:Array<GroupOptionFunc>) {
    //     this.router = Route()
    // }
    init() {
        this.router = None
        this.path = "/"
    }
    func wrap(handler:HandlerFunc):HandlerFunc {
        var wrapHandle = handler
        for (st in this.stack) {
            wrapHandle = st(handler)
        }
        return wrapHandle
    }
}