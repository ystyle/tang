package tang.middleware.requestid

import std.time.DateTime
import std.collection.ArrayList
import log.LogValue
import tang.{HandlerFunc, TangHttpContext}
import tang.middleware.log.addLogAttrsFn
import sonyflake.*

let gen = Sonyflake(Setting(1))
let _ = addLogAttrsFn(addRequestIDtoLog)

public func requestid(handler: HandlerFunc): HandlerFunc {
    return {
        ctx =>
        let id = gen.NextID()
        ctx.kvSet("requestid", "${id}")
        handler(ctx)
    }
}

func addRequestIDtoLog(ctx: TangHttpContext, attrs: ArrayList<(String, LogValue)>): Unit {
    if (let Some(v) <- ctx.kvGet<String>("requestid")) {
        attrs.append(("requestid", v))
    }
}

extend TangHttpContext {
    public func requestid():?String {
        return this.kvGet<String>("requestid")
    }
}