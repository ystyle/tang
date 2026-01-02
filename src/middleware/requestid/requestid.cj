package tang.middleware.requestid

import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}
import sonyflake.*

let gen = Sonyflake(Setting(1))

/// 请求 ID 中间件
/// 为每个请求生成唯一的 ID，存储到 ctx.kv 中
/// 可通过 ctx.requestid() 获取
func requestid(handler: HandlerFunc): HandlerFunc {
    return {
        ctx =>
        let id = gen.NextID()
        let idStr = "${id}"
        ctx.kvSet("requestid", idStr)
        ctx.responseBuilder.header("X-Request-ID", idStr)
        handler(ctx)
    }
}

public func requestid(): MiddlewareFunc {
    return {next => requestid(next)}
}