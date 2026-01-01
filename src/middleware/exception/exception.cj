package tang.middleware.exception

import tang.{MiddlewareFunc, TangHttpContext}
import tang.log.getLogger
import stdx.net.http.HttpStatusCode

/// 异常处理器类型
public type ExceptionHandler = (TangHttpContext, Exception) -> Unit

/// 异常恢复配置选项
public type RecoveryOption = (RecoveryConfig) -> Unit

/// 异常恢复配置
public class RecoveryConfig {
    var enableLog: Bool = true
    var printStackTrace: Bool = true
    var defaultStatus: UInt16 = HttpStatusCode.STATUS_INTERNAL_SERVER_ERROR
    var defaultBody: String = "500 Internal Server Error\n"
    var customHandler: ?ExceptionHandler = None

    /// 设置是否启用日志记录
    public func setEnableLog(enable: Bool): Unit {
        this.enableLog = enable
    }

    /// 设置是否打印堆栈跟踪
    public func setPrintStackTrace(enable: Bool): Unit {
        this.printStackTrace = enable
    }

    /// 设置默认错误状态码
    public func setDefaultStatus(status: UInt16): Unit {
        this.defaultStatus = status
    }

    /// 设置默认错误响应体
    public func setDefaultBody(body: String): Unit {
        this.defaultBody = body
    }

    /// 设置自定义异常处理器
    public func setCustomHandler(handler: ExceptionHandler): Unit {
        this.customHandler = handler
    }
}

/// 禁用日志记录
public func withoutLog(): RecoveryOption {
    return { config => config.setEnableLog(false) }
}

/// 禁用堆栈跟踪打印
public func withoutStackTrace(): RecoveryOption {
    return { config => config.setPrintStackTrace(false) }
}

/// 设置自定义错误状态码和响应体
public func withErrorResponse(status: UInt16, body: String): RecoveryOption {
    return { config =>
        config.setDefaultStatus(status)
        config.setDefaultBody(body)
    }
}

/// 设置自定义异常处理器
public func withExceptionHandler(handler: ExceptionHandler): RecoveryOption {
    return { config => config.setCustomHandler(handler) }
}

/// 异常恢复中间件（带配置）
///
/// 捕获并处理所有异常，防止程序崩溃
///
/// 示例：
/// ```cj
/// // 使用默认配置
/// let r = Router(use(
///     recovery()  // 或 recovery.newRecovery()
/// ))
///
/// // 禁用堆栈跟踪打印
/// let r = Router(use(
///     recovery([withoutStackTrace()])
/// ))
///
/// // 自定义错误响应
/// let r = Router(use(
///     recovery([withErrorResponse(500, "Internal Error\n")])
/// ))
///
/// // 自定义异常处理器
/// let r = Router(use(
///     recovery([withExceptionHandler({ ctx, e =>
///         // 自定义处理逻辑
///         ctx.responseBuilder.status(500).body("Error: ${e.message}\n")
///     })])
/// ))
/// ```
public func newRecovery(opts: Array<RecoveryOption>): MiddlewareFunc {
    let config = RecoveryConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        let log = getLogger()
        return { ctx: TangHttpContext =>
            try {
                next(ctx)
            } catch (e: Exception) {
                // 打印堆栈跟踪
                if (config.printStackTrace) {
                    e.printStackTrace()
                }

                // 记录日志
                if (config.enableLog) {
                    log.error("exception caught", ("error", e.toString()))
                }

                // 使用自定义处理器或默认处理
                match (config.customHandler) {
                    case Some(handler) => handler(ctx, e)
                    case None => ctx.responseBuilder.status(config.defaultStatus).body(config.defaultBody)
                }
            }
        }
    }
}

/// 异常恢复中间件（默认配置）
public func newRecovery(): MiddlewareFunc {
    return newRecovery(Array<RecoveryOption>())
}

/// 便捷函数：使用默认配置的异常恢复中间件
public func recovery(): MiddlewareFunc {
    return newRecovery()
}

/// 便捷函数：使用自定义配置的异常恢复中间件
public func recovery(opts: Array<RecoveryOption>): MiddlewareFunc {
    return newRecovery(opts)
}
