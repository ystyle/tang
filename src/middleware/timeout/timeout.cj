package tang.middleware.timeout

import std.convert.Parsable
import std.time.DateTime
import stdx.net.http.{HttpStatusCode}
import tang.{MiddlewareFunc, TangHttpContext}

/// 超时配置选项
public type TimeoutOption = (TimeoutConfig) -> Unit

/// 超时配置
public class TimeoutConfig {
    var timeoutMs: Int64 = 30000       // 超时时间（毫秒，默认 30 秒）
    var onTimeout: ?(TangHttpContext) -> Unit = None  // 超时回调

    public init() {}

    /// 设置超时时间（毫秒）
    public func setTimeout(ms: Int64): Unit {
        this.timeoutMs = ms
    }

    /// 设置超时回调
    public func setOnTimeout(callback: (TangHttpContext) -> Unit): Unit {
        this.onTimeout = callback
    }
}

/// 设置超时时间
public func withTimeout(ms: Int64): TimeoutOption {
    return { config => config.setTimeout(ms) }
}

/// 设置超时回调
public func withTimeoutCallback(callback: (TangHttpContext) -> Unit): TimeoutOption {
    return { config => config.setOnTimeout(callback) }
}

/// 超时中间件
///
/// 设置请求最大处理时间，防止慢请求
///
/// 注意：由于仓颉的同步执行模型，此中间件会记录请求开始时间，
/// 用户可以在处理函数中通过 ctx 检查是否超时。
///
/// 示例：
/// ```cj
/// // 全局 5 秒超时
/// r.use(timeout([withTimeout(5000)]))
///
/// // 某个路由 10 秒超时
/// r.get("/slow", timeout([withTimeout(10000)]), { ctx =>
///     // 在处理函数中检查超时
///     if (isTimeout(ctx)) {
///         return
///     }
///     // 正常处理
/// })
/// ```
///
/// 推荐用法：在长时间操作前检查超时
/// ```cj
/// r.get("/data", timeout([withTimeout(5000)]), { ctx =>
///     for (item in largeDataset) {
///         if (isTimeout(ctx)) {
///             ctx.responseBuilder.status(504).body("Timeout")
///             return
///         }
///         // 处理 item
///     }
/// })
/// ```
public func timeout(opts: Array<TimeoutOption>): MiddlewareFunc {
    let config = TimeoutConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 记录请求开始时间
            let startTime = DateTime.now()

            // 将开始时间和超时配置存储到 context 中
            // 使用特殊的 header 来存储元数据（实际应用中应该使用 context 的 metadata）
            ctx.request.headers.add("X-Timeout-Start", "${startTime.toUnixTimeStamp().toMilliseconds()}")
            ctx.request.headers.add("X-Timeout-Ms", "${config.timeoutMs}")

            // 执行下一个处理器
            next(ctx)

            // 检查是否超时（在响应后）
            let endTime = DateTime.now()
            let durationMs = endTime.toUnixTimeStamp().toMilliseconds() - startTime.toUnixTimeStamp().toMilliseconds()

            if (durationMs > config.timeoutMs) {
                // 执行超时回调（用于日志记录等）
                if (let Some(callback) <- config.onTimeout) {
                    callback(ctx)
                }
            }
        }
    }
}

/// 超时中间件（默认配置，30 秒）
public func timeout(): MiddlewareFunc {
    return timeout(Array<TimeoutOption>())
}

/// 检查请求是否已超时
///
/// 在处理函数中调用此函数来检查是否超时
///
/// 示例：
/// ```cj
/// r.get("/slow", timeout([withTimeout(5000)]), { ctx =>
///     for (item in largeDataset) {
///         if (isTimeout(ctx)) {
///             ctx.responseBuilder.status(504).body("Gateway Timeout")
///             return
///         }
///         // 处理 item
///     }
/// })
/// ```
public func isTimeout(ctx: TangHttpContext): Bool {
    if (let Some(startTimeStr) <- ctx.request.headers.getFirst("X-Timeout-Start")) {
        if (let Some(timeoutMsStr) <- ctx.request.headers.getFirst("X-Timeout-Ms")) {
            if (let startTimeMs <- Int64.parse(startTimeStr)) {
                if (let timeoutMs <- Int64.parse(timeoutMsStr)) {
                    let currentTimeMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
                    let elapsedMs = currentTimeMs - startTimeMs
                    return elapsedMs > timeoutMs
                }
            }
        }
    }
    return false
}

/// 获取请求已处理时间（毫秒）
public func getElapsedMs(ctx: TangHttpContext): Int64 {
    if (let Some(startTimeStr) <- ctx.request.headers.getFirst("X-Timeout-Start")) {
        if (let startTimeMs <- Int64.parse(startTimeStr)) {
            let currentTimeMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
            return currentTimeMs - startTimeMs
        }
    }
    return 0
}
