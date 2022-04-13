package echo

from std import collection.*

public class Group {
    var router:?Router
    let path:String
    var stack = Buffer<MiddlewareFunc>()

    init(router:Router, path:String, stack:Buffer<MiddlewareFunc>) {
        this.router = router
        this.path = path
        this.stack = stack
    }

    init(path:String, opts!:Array<GroupOptionFunc>) {
        this.router = router
    }
    init() {
        this.router = None
    }
    func wrap(handler:HandlerFunc):HandlerFunc {
        var wrapHandle = handler
        for (st in this.stack) {
            wrapHandle = st(handler)
        }
        return wrapHandle
    }
}