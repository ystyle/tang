package tang.middleware.healthcheck

import std.collection.HashMap
import std.time.DateTime
import tang.{HandlerFunc, TangHttpContext}

/// 健康检查函数类型
/// 返回 true 表示健康，false 表示不健康
public type HealthCheckFunc = (TangHttpContext) -> Bool

/// 健康检查配置选项
public type HealthCheckOption = (HealthCheckConfig) -> Unit

/// 健康检查配置
public class HealthCheckConfig {
    var livenessCheck: ?HealthCheckFunc = None       // 存活检查
    var readinessCheck: ?HealthCheckFunc = None      // 就绪检查
    var includeSystemInfo: Bool = true               // 是否包含系统信息

    public init() {}

    /// 设置存活检查
    /// 存活检查：确认服务是否正在运行
    public func setLivenessCheck(check: HealthCheckFunc): Unit {
        this.livenessCheck = check
    }

    /// 设置就绪检查
    /// 就绪检查：确认服务是否准备好接收流量（例如依赖服务是否可用）
    public func setReadinessCheck(check: HealthCheckFunc): Unit {
        this.readinessCheck = check
    }

    /// 是否包含系统信息（时间戳等）
    public func setIncludeSystemInfo(include: Bool): Unit {
        this.includeSystemInfo = include
    }
}

/// 设置存活检查的选项
public func withLivenessCheck(check: HealthCheckFunc): HealthCheckOption {
    return { config => config.setLivenessCheck(check) }
}

/// 设置就绪检查的选项
public func withReadinessCheck(check: HealthCheckFunc): HealthCheckOption {
    return { config => config.setReadinessCheck(check) }
}

/// 包含系统信息
public func withSystemInfo(): HealthCheckOption {
    return { config => config.setIncludeSystemInfo(true) }
}

/// 不包含系统信息
public func withoutSystemInfo(): HealthCheckOption {
    return { config => config.setIncludeSystemInfo(false) }
}

/// 健康检查处理器
///
/// 用于 Kubernetes 等容器编排平台的健康检查
///
/// 示例：
/// ```cj
/// // 简单健康检查（默认，总是返回健康）
/// app.get("/health", healthCheck())
///
/// // 带自定义检查
/// app.get("/health", healthCheck([
///     withLivenessCheck({ ctx =>
///         // 检查服务是否存活
///         true
///     }),
///     withReadinessCheck({ ctx =>
///         // 检查数据库连接等
///         checkDatabase()
///     }),
///     withSystemInfo()
/// ]))
/// ```
///
/// 响应示例：
/// ```json
/// {
///   "status": "ok",
///   "liveness": "ok",
///   "readiness": "ok",
///   "timestamp": "2026-01-01T12:00:00Z"
/// }
/// ```
public func healthcheck(opts: Array<HealthCheckOption>): HandlerFunc {
    let config = HealthCheckConfig()
    for (opt in opts) {
        opt(config)
    }

    return { ctx: TangHttpContext =>
        let result = HashMap<String, String>()

        // 默认状态
        var overallStatus = "ok"
        var livenessStatus = "ok"
        var readinessStatus = "ok"

        // 执行存活检查
        if (let Some(check) <- config.livenessCheck) {
            if (check(ctx)) {
                livenessStatus = "ok"
            } else {
                livenessStatus = "failed"
                overallStatus = "unhealthy"
            }
        }

        // 执行就绪检查
        if (let Some(check) <- config.readinessCheck) {
            if (check(ctx)) {
                readinessStatus = "ok"
            } else {
                readinessStatus = "not_ready"
                overallStatus = "not_ready"
            }
        }

        // 构建响应
        result.add("status", overallStatus)
        result.add("liveness", livenessStatus)
        result.add("readiness", readinessStatus)

        // 添加系统信息
        if (config.includeSystemInfo) {
            result.add("timestamp", "${DateTime.now()}")
        }

        // 根据状态设置 HTTP 状态码
        if (overallStatus == "ok") {
            ctx.responseBuilder.status(200)
        } else if (overallStatus == "not_ready") {
            // 503 Service Unavailable - 服务未就绪
            ctx.responseBuilder.status(503)
        } else {
            // 503 Service Unavailable - 服务不健康
            ctx.responseBuilder.status(503)
        }

        ctx.json(result)
    }
}

/// 健康检查处理器（默认配置）
public func healthcheck(): HandlerFunc {
    return healthcheck(Array<HealthCheckOption>())
}
