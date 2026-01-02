package tang.middleware.keyauth

import std.collection.{HashMap, ArrayList}
import stdx.net.http.{HttpStatusCode}
import tang.{MiddlewareFunc, TangHttpContext}

/// Key auth 中间件配置选项
public type KeyAuthOption = (KeyAuthConfig) -> Unit

/// Key 验证器函数类型
/// 用户可以自定义如何验证 API Key
public type KeyValidator = (String) -> Bool

/// Key 查找器函数类型
/// 从请求中提取 API Key
public type KeyLookupFunc = (TangHttpContext) -> ?String

/// Key auth 配置
public class KeyAuthConfig {
    var keys: ArrayList<String> = ArrayList<String>()  // 允许的 API Keys 列表
    var validator: ?KeyValidator = None  // 自定义验证器
    var keyLookup: KeyLookupFunc = defaultKeyLookup  // 如何从请求中获取 key
    var errorResponse: String = "Unauthorized\n"  // 认证失败时的响应
    var exposeErrorCode: Bool = false  // 是否暴露错误原因（安全考虑）

    public init() {}

    /// 添加允许的 API Key
    public func addKey(key: String): Unit {
        this.keys.add(key)
    }

    /// 设置多个允许的 API Keys
    public func setKeys(keys: ArrayList<String>): Unit {
        this.keys = keys
    }

    /// 设置自定义验证器
    public func setValidator(validator: KeyValidator): Unit {
        this.validator = validator
    }

    /// 设置 key 查找器
    public func setKeyLookup(lookup: KeyLookupFunc): Unit {
        this.keyLookup = lookup
    }

    /// 设置错误响应
    public func setErrorResponse(response: String): Unit {
        this.errorResponse = response
    }

    /// 设置是否暴露错误码
    public func setExposeErrorCode(expose: Bool): Unit {
        this.exposeErrorCode = expose
    }

    /// 验证 key 是否有效
    public func validateKey(key: String): Bool {
        // 如果提供了自定义验证器，使用它
        if (let Some(v) <- this.validator) {
            return v(key)
        }

        // 默认：检查 key 是否在允许列表中
        for (allowedKey in this.keys) {
            if (allowedKey == key) {
                return true
            }
        }
        return false
    }
}

/// 默认的 key 查找器：从 header、query、cookie 中查找
func defaultKeyLookup(ctx: TangHttpContext): ?String {
    // 1. 尝试从 header 获取
    let headerKey1 = ctx.request.headers.getFirst("X-API-Key")
    if (let Some(k1) <- headerKey1) {
        return Some(k1)
    }

    let headerKey2 = ctx.request.headers.getFirst("Authorization")
    if (let Some(k2) <- headerKey2) {
        // 支持 "Bearer {key}" 或 "Key {key}" 格式
        if (k2.startsWith("Bearer ")) {
            return Some(k2[7..])
        }
        if (k2.startsWith("Key ")) {
            return Some(k2[4..])
        }
        return Some(k2)
    }

    // 2. 尝试从 query 参数获取
    let queryKey1 = ctx.query("api_key")
    if (let Some(q1) <- queryKey1) {
        return Some(q1)
    }

    let queryKey2 = ctx.query("token")
    if (let Some(q2) <- queryKey2) {
        return Some(q2)
    }

    let queryKey3 = ctx.query("key")
    if (let Some(q3) <- queryKey3) {
        return Some(q3)
    }

    // 3. 尝试从 cookie 获取
    let cookies = ctx.cookies()
    let cookie1 = cookies.get("api_key")
    if (let Some(c1) <- cookie1) {
        return Some(c1)
    }

    let cookie2 = cookies.get("token")
    if (let Some(c2) <- cookie2) {
        return Some(c2)
    }

    return None
}

/// 添加允许的 API Key
public func withKey(key: String): KeyAuthOption {
    return { config => config.addKey(key) }
}

/// 添加多个允许的 API Keys
public func withKeys(keys: ArrayList<String>): KeyAuthOption {
    return { config => config.setKeys(keys) }
}

/// 设置自定义验证器
public func withValidator(validator: KeyValidator): KeyAuthOption {
    return { config => config.setValidator(validator) }
}

/// 设置 key 查找位置
/// 格式："header:X-API-Key", "query:token", "cookie:api_key"
public func withLookup(lookup: String): KeyAuthOption {
    return { config =>
        let parts = lookup.split(':')
        if (parts.size != 2) {
            return
        }

        let source = parts[0]
        let name = parts[1]

        config.setKeyLookup({ ctx =>
            match (source) {
                case "header" => ctx.request.headers.getFirst(name)
                case "query" => ctx.query(name)
                case "cookie" =>
                    let cookies = ctx.cookies()
                    let cookie = cookies.get(name)
                    cookie
                case _ => None
            }
        })
    }
}

/// 设置自定义的 key 查找函数
public func withCustomLookup(lookup: KeyLookupFunc): KeyAuthOption {
    return { config => config.setKeyLookup(lookup) }
}

/// 设置错误响应
public func withErrorResponse(response: String): KeyAuthOption {
    return { config => config.setErrorResponse(response) }
}

/// 设置是否暴露错误码
public func withExposeErrorCode(): KeyAuthOption {
    return { config => config.setExposeErrorCode(true) }
}

/// Key auth 中间件（带配置）
///
/// 基于 API Key 进行简单认证
///
/// 示例：
/// ```cj
/// // 使用单个 API Key
/// r.use(keyAuth([withKey("your-secret-key")]))
///
/// // 使用多个 API Keys
/// r.use(keyAuth([withKeys(["key1", "key2", "key3"])]))
///
/// // 从特定位置获取 key
/// r.use(keyAuth([
///     withKey("secret-key"),
///     withLookup("header:X-API-Key")  // 仅从 header 获取
/// ]))
///
/// // 使用自定义验证器
/// r.use(keyAuth([
///     withValidator({ key =>
///         // 自定义验证逻辑
///         key.startsWith("valid-") && key.size > 10
///     })
/// ]))
///
/// // 自定义查找逻辑
/// r.use(keyAuth([
///     withKey("secret"),
///     withCustomLookup({ ctx =>
///         // 从多个地方查找，优先级自定义
///         ctx.request.headers.getFirst("X-Custom-Key") ??
///         ctx.request.query.getFirst("custom_key")
///     })
/// ]))
///
/// // 或使用默认配置
/// r.use(keyAuth())
/// ```
public func keyAuth(opts: Array<KeyAuthOption>): MiddlewareFunc {
    let config = KeyAuthConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 从请求中获取 API Key
            let maybeKey = config.keyLookup(ctx)

            match (maybeKey) {
                case Some(key) =>
                    // 验证 key
                    let isValid = config.validateKey(key)
                    match (isValid) {
                        case true =>
                            // 认证成功，继续处理
                            next(ctx)

                        case false =>
                            // 认证失败，返回 401
                            ctx.responseBuilder.status(HttpStatusCode.STATUS_UNAUTHORIZED)
                            ctx.responseBuilder.header("Content-Type", "text/plain; charset=utf-8")
                            if (config.exposeErrorCode) {
                                ctx.responseBuilder.header("X-Auth-Error", "Invalid API Key")
                            }
                            ctx.responseBuilder.body(config.errorResponse)
                    }

                case None =>
                    // 未提供 key，返回 401
                    ctx.responseBuilder.status(HttpStatusCode.STATUS_UNAUTHORIZED)
                    ctx.responseBuilder.header("Content-Type", "text/plain; charset=utf-8")
                    if (config.exposeErrorCode) {
                        ctx.responseBuilder.header("X-Auth-Error", "Missing API Key")
                    }
                    ctx.responseBuilder.body(config.errorResponse)
            }
        }
    }
}

/// Key auth 中间件（默认配置）
public func keyAuth(): MiddlewareFunc {
    return keyAuth(Array<KeyAuthOption>())
}
