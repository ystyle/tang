package tang.middleware.requestid

import std.sync.AtomicInt64
import std.time.DateTime
import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}

// 进程启动时间（秒），只算一次；让 ID 跨进程时仍可粗略排序
let bootSeconds: Int64 = DateTime.now().toUnixTimeStamp().toSeconds()
// 单调递增计数器：无锁、不依赖时钟、不 sleep
let counter = AtomicInt64(0)

/// 生成请求 ID：启动秒-自增序号
///
/// 旧实现用 sonyflake 有三个问题叠加：
///   1. 每次 NextID() 抢一把全局 Mutex；
///   2. 序列号只有 8 bit —— 每 10ms 只能出 256 个 ID，超出就 sleep 等下一个时钟片；
///   3. 序列回绕时还会 println。
/// 高 QPS 下这三点直接变成尾延迟来源，故改为无锁自增。
func nextID(): String {
    let seq = counter.fetchAdd(1)
    return bootSeconds.toString() + "-" + seq.toString()
}

/// 请求 ID 中间件
/// 为每个请求生成唯一 ID，直接存入 ctx._requestId 字段（避免创建 HashMap）
/// 可通过 ctx.requestid() 获取
func requestid(handler: HandlerFunc): HandlerFunc {
    return {
        ctx =>
        // 客户端已带 X-Request-ID 时沿用，便于跨服务串联
        let incoming = ctx.request.headers.getFirst("X-Request-ID")
        let idStr = match (incoming) {
            case Some(v) => v
            case None => nextID()
        }
        ctx._requestId = Some(idStr)
        ctx.responseBuilder.header("X-Request-ID", idStr)
        handler(ctx)
    }
}

public func requestid(): MiddlewareFunc {
    return {next => requestid(next)}
}