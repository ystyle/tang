package tang.middleware.requestid

import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}
import sonyflake.*

let gen = Sonyflake(Setting(1))

/// 请求 ID 中间件
/// 为每个请求生成唯一的 ID，直接存储到 ctx._requestId 字段
/// 可通过 ctx.requestid() 获取
func requestid(handler: HandlerFunc): HandlerFunc {
    return {
        ctx =>
        let id = gen.NextID()
        let idStr = "${id}"
        ctx._requestId = Some(idStr)  // 直接设置字段，避免创建 HashMap
        ctx.responseBuilder.header("X-Request-ID", idStr)
        handler(ctx)
    }
}

public func requestid(): MiddlewareFunc {
    return {next => requestid(next)}
}