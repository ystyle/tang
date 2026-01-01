package tang.middleware.bodylimit

import std.convert.Parsable
import stdx.net.http.HttpStatusCode
import tang.{MiddlewareFunc, TangHttpContext}

/// Body limit 中间件配置选项
public type BodyLimitOption = (BodyLimitConfig) -> Unit

/// Body limit 配置
public class BodyLimitConfig {
    var maxSize: Int64 = 1048576  // 默认 1MB

    public init() {}

    /// 设置最大请求体大小（字节）
    public func setMaxSize(size: Int64): Unit {
        this.maxSize = size
    }
}

/// 设置最大请求体大小的选项
public func withMaxSize(size: Int64): BodyLimitOption {
    return { config => config.setMaxSize(size) }
}

/// Body limit 中间件（带配置）
///
/// 限制请求体大小，防止大文件攻击
///
/// 示例：
/// ```cj
/// // 限制请求体最大 10MB
/// r.use(bodyLimit([withMaxSize(10 * 1024 * 1024)]))
///
/// // 或使用默认配置（1MB）
/// r.use(bodyLimit())
/// ```
public func bodyLimit(opts: Array<BodyLimitOption>): MiddlewareFunc {
    let config = BodyLimitConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 检查 Content-Length 头
            let contentLength = ctx.request.headers.getFirst("Content-Length")

            if (let Some(lengthStr) <- contentLength) {
                // 解析 Content-Length
                if (let length <- Int64.parse(lengthStr)) {
                    if (length > config.maxSize) {
                        // 请求体过大，返回 413
                        ctx.responseBuilder.status(HttpStatusCode.STATUS_REQUEST_CONTENT_TOO_LARGE)
                        ctx.responseBuilder.header("Content-Type", "text/plain; charset=utf-8")
                        ctx.responseBuilder.body(#"Request Entity Too Large

Maximum request body size is ${config.maxSize} bytes

"#)
                        return
                    }
                }
            }

            // 继续处理请求
            next(ctx)
        }
    }
}

/// Body limit 中间件（默认配置）
public func bodyLimit(): MiddlewareFunc {
    return bodyLimit(Array<BodyLimitOption>())
}
