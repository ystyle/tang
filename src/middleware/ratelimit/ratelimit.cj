package tang.middleware.ratelimit

import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import stdx.net.http.{HttpStatusCode}
import tang.{MiddlewareFunc, TangHttpContext}

/// Rate limit 中间件配置选项
public type RateLimitOption = (RateLimitConfig) -> Unit

/// 客户端标识符生成器函数类型
/// 用户可以自定义如何识别客户端（基于用户ID、API key、session等）
public type ClientIDGenerator = (TangHttpContext) -> String

/// 限流记录
class RateLimitRecord {
    var count: Int64 = 0
    var resetTime: DateTime

    public init(time: DateTime) {
        this.resetTime = time
    }
}

/// Rate limit 配置
public class RateLimitConfig {
    var maxRequests: Int64 = 60      // 时间窗口内最大请求数
    var windowMs: Int64 = 60000      // 时间窗口（毫秒，默认1分钟）
    var trustProxy: Bool = false     // 是否信任代理
    var clientIDGen: ?ClientIDGenerator = None  // 自定义客户端标识符生成器

    // 存储每个客户端的请求记录
    var clients: HashMap<String, RateLimitRecord> = HashMap<String, RateLimitRecord>()

    public init() {}

    /// 设置时间窗口内最大请求数
    public func setMaxRequests(requests: Int64): Unit {
        this.maxRequests = requests
    }

    /// 设置时间窗口（毫秒）
    public func setWindowMs(ms: Int64): Unit {
        this.windowMs = ms
    }

    /// 是否信任代理（使用 X-Forwarded-For 头获取真实 IP）
    public func setTrustProxy(trust: Bool): Unit {
        this.trustProxy = trust
    }

    /// 设置自定义客户端标识符生成器
    public func setClientIDGen(generator: ClientIDGenerator): Unit {
        this.clientIDGen = generator
    }

    /// 清理过期记录
    public func cleanupExpiredRecords(): Unit {
        let now = DateTime.now()
        let keysToRemove = ArrayList<String>()

        for ((key, record) in this.clients) {
            if (now > record.resetTime) {
                keysToRemove.add(key)
            }
        }

        for (key in keysToRemove) {
            this.clients.remove(key)
        }
    }
}

/// 设置最大请求数的选项
public func withMaxRequests(requests: Int64): RateLimitOption {
    return { config => config.setMaxRequests(requests) }
}

/// 设置时间窗口的选项（毫秒）
public func withWindowMs(ms: Int64): RateLimitOption {
    return { config => config.setWindowMs(ms) }
}

/// 信任代理的选项
public func withTrustProxy(): RateLimitOption {
    return { config => config.setTrustProxy(true) }
}

/// 设置自定义客户端标识符生成器的选项
public func withClientID(generator: ClientIDGenerator): RateLimitOption {
    return { config => config.setClientIDGen(generator) }
}

/// Rate limit 中间件（带配置）
///
/// 基于客户端 IP 地址限制请求速率，防止 DDoS 攻击
///
/// 示例：
/// ```cj
/// // 每分钟最多 100 个请求（基于 IP）
/// r.use(rateLimit([withMaxRequests(100)]))
///
/// // 每秒最多 10 个请求
/// r.use(rateLimit([withMaxRequests(10), withWindowMs(1000)]))
///
/// // 基于 API Key 进行限流
/// r.use(rateLimit([
///     withMaxRequests(1000),
///     withClientID({ ctx => ctx.request.headers.getFirst("X-API-Key") ?? "anonymous" })
/// ]))
///
/// // 基于用户 ID 进行限流
/// r.use(rateLimit([
///     withMaxRequests(500),
///     withClientID({ ctx => ctx.getSession().userId ?? "guest" })
/// ]))
///
/// // 或使用默认配置（每分钟 60 个请求，基于 IP）
/// r.use(rateLimit())
/// ```
public func rateLimit(opts: Array<RateLimitOption>): MiddlewareFunc {
    let config = RateLimitConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 获取客户端标识符
            var clientKey: String = ""

            // 如果提供了自定义 clientIDGen，使用它
            if (let Some(generator) <- config.clientIDGen) {
                clientKey = generator(ctx)
            } else {
                // 默认基于 IP 地址
                var clientIP = ctx.request.remoteAddr

                // 去除端口号（如果存在）
                if (clientIP.contains(":")) {
                    let parts = clientIP.split(':')
                    if (parts.size >= 2) {
                        // IP:port 格式，取 IP 部分
                        // 对于 IPv6 地址，需要特殊处理
                        if (clientIP.startsWith("[")) {
                            // IPv6 格式 [::1]:port
                            let endBracket = clientIP.indexOf(']')
                            if (let Some(idx) <- endBracket) {
                                clientIP = clientIP[0..idx+1]
                            }
                        } else {
                            // IPv4 格式 127.0.0.1:port
                            clientIP = parts[0]
                        }
                    }
                }

                // 如果信任代理，尝试从 X-Forwarded-For 获取真实 IP
                if (config.trustProxy) {
                    if (let Some(xff) <- ctx.request.headers.getFirst("X-Forwarded-For")) {
                        // X-Forwarded-For 可能包含多个 IP，取第一个
                        let ips = xff.split(',')
                        if (ips.size > 0) {
                            clientIP = ips[0]
                        }
                    }
                }

                clientKey = clientIP
            }

            let now = DateTime.now()

            // 获取或创建客户端记录
            if (let Some(record) <- config.clients.get(clientKey)) {
                // 检查时间窗口是否已过
                if (now > record.resetTime) {
                    // 时间窗口已过，重置计数
                    record.count = 1
                    let windowDuration = Duration.millisecond * config.windowMs
                    record.resetTime = DateTime.fromUnixTimeStamp(now.toUnixTimeStamp() + windowDuration)
                } else {
                    // 时间窗口内，增加计数
                    record.count++

                    // 检查是否超过限制
                    if (record.count > config.maxRequests) {
                        let remainingDuration = record.resetTime.toUnixTimeStamp() - now.toUnixTimeStamp()
                        let retryAfter = remainingDuration.toMilliseconds() / 1000
                        ctx.responseBuilder.status(HttpStatusCode.STATUS_TOO_MANY_REQUESTS)
                        ctx.responseBuilder.header("Content-Type", "text/plain; charset=utf-8")
                        ctx.responseBuilder.header("X-RateLimit-Limit", "${config.maxRequests}")
                        ctx.responseBuilder.header("X-RateLimit-Remaining", "0")
                        ctx.responseBuilder.header("X-RateLimit-Reset", "${record.resetTime.toUnixTimeStamp().toMilliseconds() / 1000}")
                        ctx.responseBuilder.header("Retry-After", "${retryAfter}")
                        let windowSecs = config.windowMs / 1000
                        ctx.responseBuilder.body("Too Many Requests\n\nRate limit exceeded. Maximum ${config.maxRequests} requests per ${windowSecs} seconds.\n\nPlease retry in ${retryAfter} seconds.\n")
                        return
                    }
                }
            } else {
                // 新客户端，创建记录
                let windowDuration = Duration.millisecond * config.windowMs
                let resetTime = DateTime.fromUnixTimeStamp(now.toUnixTimeStamp() + windowDuration)
                let record = RateLimitRecord(resetTime)
                record.count = 1
                config.clients.add(clientKey, record)
            }

            // 设置速率限制响应头
            if (let Some(record) <- config.clients.get(clientKey)) {
                let remaining = config.maxRequests - record.count
                ctx.responseBuilder.header("X-RateLimit-Limit", "${config.maxRequests}")
                ctx.responseBuilder.header("X-RateLimit-Remaining", "${remaining}")
                ctx.responseBuilder.header("X-RateLimit-Reset", "${record.resetTime.toUnixTimeStamp().toMilliseconds() / 1000}")
            }

            // 定期清理过期记录（每 100 次请求清理一次）
            if (config.clients.size > 100) {
                config.cleanupExpiredRecords()
            }

            // 继续处理请求
            next(ctx)
        }
    }
}

/// Rate limit 中间件（默认配置）
public func rateLimit(): MiddlewareFunc {
    return rateLimit(Array<RateLimitOption>())
}
