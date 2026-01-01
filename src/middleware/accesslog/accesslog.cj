package tang.middleware.accesslog

import std.time.DateTime
import std.collection.ArrayList
import stdx.log.LogValue
import tang.{MiddlewareFunc, TangHttpContext}
import tang.log.getLogger

/// 访问日志配置选项
public type AccessLogOption = (AccessLogConfig) -> Unit

/// 访问日志配置
public class AccessLogConfig {
    var timeFormat: Bool = true
    var method: Bool = true
    var path: Bool = true
    var status: Bool = true
    var latency: Bool = true
    var requestID: Bool = true
    var userAgent: Bool = false
    var clientIP: Bool = false

    /// 设置是否记录时间格式
    public func setTimeFormat(enable: Bool): Unit {
        this.timeFormat = enable
    }

    /// 设置是否记录请求方法
    public func setMethod(enable: Bool): Unit {
        this.method = enable
    }

    /// 设置是否记录路径
    public func setPath(enable: Bool): Unit {
        this.path = enable
    }

    /// 设置是否记录状态码
    public func setStatus(enable: Bool): Unit {
        this.status = enable
    }

    /// 设置是否记录延迟
    public func setLatency(enable: Bool): Unit {
        this.latency = enable
    }

    /// 设置是否记录请求 ID
    public func setRequestID(enable: Bool): Unit {
        this.requestID = enable
    }

    /// 设置是否记录 User-Agent
    public func setUserAgent(enable: Bool): Unit {
        this.userAgent = enable
    }

    /// 设置是否记录客户端 IP
    public func setClientIP(enable: Bool): Unit {
        this.clientIP = enable
    }
}

/// 启用时间格式
public func withTimeFormat(): AccessLogOption {
    return { config => config.setTimeFormat(true) }
}

/// 禁用时间格式
public func withoutTimeFormat(): AccessLogOption {
    return { config => config.setTimeFormat(false) }
}

/// 启用 User-Agent 记录
public func withUserAgent(): AccessLogOption {
    return { config => config.setUserAgent(true) }
}

/// 启用客户端 IP 记录
public func withClientIP(): AccessLogOption {
    return { config => config.setClientIP(true) }
}

/// 访问日志中间件（带配置）
///
/// 记录每个请求的方法、路径、延迟、状态码等信息
///
/// 示例：
/// ```cj
/// // 使用默认配置
/// let r = Router(use(
///     accesslog()  // 或 accesslog.newAccessLog()
/// ))
///
/// // 启用 User-Agent 和客户端 IP
/// let r = Router(use(
///     accesslog([withUserAgent(), withClientIP()])
/// ))
/// ```
public func newAccessLog(opts: Array<AccessLogOption>): MiddlewareFunc {
    let config = AccessLogConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        let log = getLogger()
        return { ctx: TangHttpContext =>
            let t = DateTime.now()
            next(ctx)

            // 获取响应信息
            let url = ctx.request.url
            let method = ctx.request.method
            let latency = DateTime.now() - t
            let response = ctx.responseBuilder.build()
            let code = response.status

            // 构建日志字段
            var attrs = ArrayList<(String, LogValue)>()

            if (config.method) {
                attrs.add(("method", method.toString()))
            }

            if (config.path) {
                attrs.add(("path", url.path))
            }

            if (config.status) {
                attrs.add(("status", "${code}"))
            }

            if (config.latency) {
                attrs.add(("latency", "${latency}"))
            }

            if (config.requestID) {
                let rid = ctx.requestid()
                if (let Some(v) <- rid) {
                    attrs.add(("requestid", v))
                }
            }

            if (config.userAgent) {
                let ua = ctx.request.headers.getFirst("User-Agent")
                if (let Some(v) <- ua) {
                    attrs.add(("useragent", v))
                }
            }

            if (config.clientIP) {
                let ip = ctx.request.headers.getFirst("X-Real-IP")
                if (let Some(v) <- ip) {
                    attrs.add(("clientip", v))
                } else {
                    let xff = ctx.request.headers.getFirst("X-Forwarded-For")
                    if (let Some(v) <- xff) {
                        attrs.add(("clientip", v))
                    }
                }
            }

            // 记录日志
            log.withAttrs(attrs.toArray()).info("request")
        }
    }
}

/// 访问日志中间件（默认配置）
public func newAccessLog(): MiddlewareFunc {
    return newAccessLog(Array<AccessLogOption>())
}

/// 便捷函数：使用默认配置的访问日志中间件
public func accesslog(): MiddlewareFunc {
    return newAccessLog()
}

/// 便捷函数：使用自定义配置的访问日志中间件
public func accesslog(opts: Array<AccessLogOption>): MiddlewareFunc {
    return newAccessLog(opts)
}
