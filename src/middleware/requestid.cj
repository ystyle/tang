package tang.middleware

import std.time.DateTime
import std.collection.ArrayList
import log.LogValue
import tang.{HandlerFunc, TangHttpContext}
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
