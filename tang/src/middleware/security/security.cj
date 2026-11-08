package tang.middleware.security

import tang.{MiddlewareFunc, TangHttpContext}

/// 安全头配置选项
public type SecurityOption = (SecurityConfig) -> Unit

/// 安全头配置
public class SecurityConfig {
    var xFrameOptions: String = "DENY"
    var xContentTypeOptions: String = "nosniff"
    var xXSSProtection: String = "1; mode=block"
    var strictTransportSecurity: String = "max-age=31536000; includeSubDomains"
    var contentSecurityPolicy: String = ""
    var referrerPolicy: String = "strict-origin-when-cross-origin"
    var permissionsPolicy: String = ""

    /// 设置 X-Frame-Options（防止点击劫持）
    /// DENY - 不允许任何域嵌入
    /// SAMEORIGIN - 只允许同源嵌入
    /// ALLOW-FROM uri - 允许指定 URI 嵌入
    public func setXFrameOptions(value: String): Unit {
        this.xFrameOptions = value
    }

    /// 设置 X-Content-Type-Options（防止 MIME 类型嗅探）
    /// nosniff - 禁用 MIME 类型嗅探
    public func setXContentTypeOptions(value: String): Unit {
        this.xContentTypeOptions = value
    }

    /// 设置 X-XSS-Protection（浏览器 XSS 保护）
    /// 1; mode=block - 启用 XSS 保护并阻止页面加载
    /// 0 - 禁用 XSS 保护
    public func setXXSSProtection(value: String): Unit {
        this.xXSSProtection = value
    }

    /// 设置 Strict-Transport-Security（HSTS，强制 HTTPS）
    /// max-age=31536000 - 1 年
    /// includeSubDomains - 包含所有子域
    /// preload - 允许预加载到浏览器 HSTS 列表
    public func setStrictTransportSecurity(value: String): Unit {
        this.strictTransportSecurity = value
    }

    /// 设置 Content-Security-Policy（CSP，内容安全策略）
    /// 示例："default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'"
    public func setContentSecurityPolicy(value: String): Unit {
        this.contentSecurityPolicy = value
    }

    /// 设置 Referrer-Policy（引用策略）
    /// no-referrer - 不发送 referrer
    /// strict-origin-when-cross-origin - 跨域时只发送源
    public func setReferrerPolicy(value: String): Unit {
        this.referrerPolicy = value
    }

    /// 设置 Permissions-Policy（功能策略，原名 Feature-Policy）
    /// 控制浏览器功能和 API 的使用
    /// 示例："geolocation=(), camera=(self), microphone=()"
    public func setPermissionsPolicy(value: String): Unit {
        this.permissionsPolicy = value
    }
}

/// 设置 X-Frame-Options 为 SAMEORIGIN
public func withXFrameSameOrigin(): SecurityOption {
    return { config => config.setXFrameOptions("SAMEORIGIN") }
}

/// 禁用 HSTS（用于 HTTP 环境）
public func withDisableHSTS(): SecurityOption {
    return { config => config.setStrictTransportSecurity("") }
}

/// 设置 CSP 策略
public func withCSP(policy: String): SecurityOption {
    return { config => config.setContentSecurityPolicy(policy) }
}

/// 设置严格的安全策略（推荐用于生产环境）
public func withStrictSecurity(): SecurityOption {
    return { config =>
        config.setXFrameOptions("DENY")
        config.setXContentTypeOptions("nosniff")
        config.setXXSSProtection("1; mode=block")
        config.setStrictTransportSecurity("max-age=31536000; includeSubDomains; preload")
        config.setContentSecurityPolicy("default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'")
        config.setReferrerPolicy("no-referrer")
        config.setPermissionsPolicy("geolocation=(), camera=(), microphone=()")
    }
}

/// 宽松的安全策略（用于开发环境）
public func withLooseSecurity(): SecurityOption {
    return { config =>
        config.setXFrameOptions("SAMEORIGIN")
        config.setContentSecurityPolicy("default-src 'self' 'unsafe-inline' 'unsafe-eval'")
        config.setReferrerPolicy("strict-origin-when-cross-origin")
    }
}

/// 安全头中间件
///
/// 自动设置常见的安全响应头，提升应用安全性
///
/// 设置的安全头：
/// - X-Frame-Options - 防止点击劫持
/// - X-Content-Type-Options - 防止 MIME 嗅探
/// - X-XSS-Protection - 浏览器 XSS 保护
/// - Strict-Transport-Security - 强制 HTTPS
/// - Content-Security-Policy - 内容安全策略
/// - Referrer-Policy - 引用策略
/// - Permissions-Policy - 功能策略
///
/// 示例：
/// ```cj
/// // 使用默认配置
/// let r = Router(use(
///     security()  // 或 security.newSecurity()
/// ))
///
/// // 使用严格安全策略（推荐）
/// let r = Router(use(
///     security([withStrictSecurity()])
/// ))
///
/// // 自定义 CSP
/// let r = Router(use(
///     security([withCSP("default-src 'self'")])
/// ))
/// ```
public func newSecurity(opts: Array<SecurityOption>): MiddlewareFunc {
    let config = SecurityConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 调用下一个处理器
            next(ctx)

            // 设置安全头
            if (config.xFrameOptions.size > 0) {
                ctx.responseBuilder.header("X-Frame-Options", config.xFrameOptions)
            }

            if (config.xContentTypeOptions.size > 0) {
                ctx.responseBuilder.header("X-Content-Type-Options", config.xContentTypeOptions)
            }

            if (config.xXSSProtection.size > 0) {
                ctx.responseBuilder.header("X-XSS-Protection", config.xXSSProtection)
            }

            if (config.strictTransportSecurity.size > 0) {
                ctx.responseBuilder.header("Strict-Transport-Security", config.strictTransportSecurity)
            }

            if (config.contentSecurityPolicy.size > 0) {
                ctx.responseBuilder.header("Content-Security-Policy", config.contentSecurityPolicy)
            }

            if (config.referrerPolicy.size > 0) {
                ctx.responseBuilder.header("Referrer-Policy", config.referrerPolicy)
            }

            if (config.permissionsPolicy.size > 0) {
                ctx.responseBuilder.header("Permissions-Policy", config.permissionsPolicy)
            }
        }
    }
}

/// 创建安全头中间件（默认配置）
public func newSecurity(): MiddlewareFunc {
    let config = SecurityConfig()
    return { next =>
        return { ctx: TangHttpContext =>
            // 调用下一个处理器
            next(ctx)

            // 设置安全头
            if (config.xFrameOptions.size > 0) {
                ctx.responseBuilder.header("X-Frame-Options", config.xFrameOptions)
            }

            if (config.xContentTypeOptions.size > 0) {
                ctx.responseBuilder.header("X-Content-Type-Options", config.xContentTypeOptions)
            }

            if (config.xXSSProtection.size > 0) {
                ctx.responseBuilder.header("X-XSS-Protection", config.xXSSProtection)
            }

            if (config.strictTransportSecurity.size > 0) {
                ctx.responseBuilder.header("Strict-Transport-Security", config.strictTransportSecurity)
            }

            if (config.contentSecurityPolicy.size > 0) {
                ctx.responseBuilder.header("Content-Security-Policy", config.contentSecurityPolicy)
            }

            if (config.referrerPolicy.size > 0) {
                ctx.responseBuilder.header("Referrer-Policy", config.referrerPolicy)
            }

            if (config.permissionsPolicy.size > 0) {
                ctx.responseBuilder.header("Permissions-Policy", config.permissionsPolicy)
            }
        }
    }
}

/// 便捷函数：使用默认配置的安全中间件
public func security(): MiddlewareFunc {
    return newSecurity()
}

/// 便捷函数：使用自定义配置的安全中间件
public func security(opts: Array<SecurityOption>): MiddlewareFunc {
    return newSecurity(opts)
}
