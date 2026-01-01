package tang.middleware.log

import std.time.DateTime
import std.collection.ArrayList
import stdx.log.LogValue
import tang.{HandlerFunc, TangHttpContext, log.getLogger}

public type TangLogAttrsFn  = (ctx: TangHttpContext, attrs: ArrayList<(String, LogValue)>) -> Unit
let logFns = ArrayList<TangLogAttrsFn>()

public func addLogAttrsFn(fns: Array<TangLogAttrsFn>) {
    logFns.add(all:fns)
}

public func logger(handler: HandlerFunc): HandlerFunc {
    let log = getLogger()
    return { ctx: TangHttpContext =>
        let t = DateTime.now()
        handler(ctx)
        let url = ctx.request.url
        let method = ctx.request.method
        let attr = ArrayList<(String, LogValue)>()
        let ts = DateTime.now() - t
        let code = ctx.responseBuilder.build().status
        for (fn in logFns) {
            fn(ctx, attr)
        }
        var l = log.withAttrs([("method", method), ("path", url.path), ("latency", "${ts}"), ("status", "${code}")])
        if (attr.size > 0) {
            l = l.withAttrs(attr.toArray())
        }
        l.info("vist")
        return
    }
}
