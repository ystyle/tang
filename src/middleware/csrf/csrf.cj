package tang.middleware.csrf

import std.regex.{Regex, RegexFlag}
import std.collection.ArrayList
import stdx.crypto.digest.{SHA256, HMAC}
import stdx.crypto.digest.HashType
import stdx.crypto.crypto.SecureRandom
import std.time.DateTime
import stdx.encoding.hex.{toHexString, fromHexString}
import std.convert.Parsable
import tang.{MiddlewareFunc, TangHttpContext}
import stdx.net.http.HttpStatusCode

/// CSRF 中间件配置选项
public type CSRFOption = (CSRFConfig) -> Unit

/// CSRF 配置
public class CSRFConfig {
    var secretKey: Array<UInt8> = Array<UInt8>()  // 密钥，用于签名
    var tokenLength: Int32 = 32  // token 长度（字节）
    var tokenLookup: String = "header:X-CSRF-Token"  // token 查找位置
    var excludedPaths: ArrayList<String> = ArrayList<String>()  // 排除路径
    var excludedMethods: ArrayList<String> = ArrayList<String>(["HEAD", "OPTIONS", "TRACE"])  // 排除的 HTTP 方法（GET 不排除，用于生成 token）
    var expiration: Int64 = 86400  // token 过期时间（秒，默认 24 小时）
    var errorHandler: (TangHttpContext) -> Unit = { ctx =>
        ctx.responseBuilder.status(HttpStatusCode.STATUS_FORBIDDEN)
        ctx.responseBuilder.body("{\"error\":\"CSRF token validation failed\"}")
    }

    public init() {}

    /// 设置密钥（直接传入字符串）
    public func setSecretKey(key: String): Unit {
        this.secretKey = key.toArray()
    }

    /// 设置密钥（从 hex 编码的字符串）
    /// 例如：fromHexString("736563726574313233") 解码为 "secret123"
    public func setSecretKeyFromHex(key: String): Unit {
        let keyBytes = fromHexString(key)
        this.secretKey = match (keyBytes) {
            case Some(bytes) => bytes
            case None => Array<UInt8>()  // 无效的 hex 字符串
        }
    }

    /// 设置密钥（字节数组）
    public func setSecretKeyBytes(key: Array<UInt8>): Unit {
        this.secretKey = key
    }

    /// 设置 token 长度
    public func setTokenLength(length: Int32): Unit {
        this.tokenLength = length
    }

    /// 设置 token 查找位置
    /// 格式："header:X-CSRF-Token" 或 "query:csrf_token" 或 "form:csrf_token"
    public func setTokenLookup(lookup: String): Unit {
        this.tokenLookup = lookup
    }

    /// 添加排除路径
    public func addExcludePath(path: String): Unit {
        this.excludedPaths.add(path)
    }

    /// 设置排除路径列表
    public func setExcludedPaths(paths: Array<String>): Unit {
        for (path in paths) {
            this.excludedPaths.add(path)
        }
    }

    /// 设置排除的 HTTP 方法
    public func setExcludedMethods(methods: Array<String>): Unit {
        this.excludedMethods = ArrayList<String>(methods)
    }

    /// 设置 token 过期时间
    public func setExpiration(seconds: Int64): Unit {
        this.expiration = seconds
    }

    /// 设置错误处理器
    public func setErrorHandler(handler: (TangHttpContext) -> Unit): Unit {
        this.errorHandler = handler
    }

    /// 检查路径是否被排除
    public func isPathExcluded(path: String): Bool {
        for (excludePath in this.excludedPaths) {
            // 支持通配符匹配
            if (excludePath.endsWith("*")) {
                let prefix = excludePath[0..excludePath.size - 1]
                if (path.startsWith(prefix)) {
                    return true
                }
            } else if (path == excludePath || path.startsWith(excludePath + "/")) {
                return true
            }
        }
        return false
    }

    /// 检查方法是否被排除
    public func isMethodExcluded(method: String): Bool {
        for (excludedMethod in this.excludedMethods) {
            if (method == excludedMethod) {
                return true
            }
        }
        return false
    }

    /// 生成 CSRF token
    public func generateToken(ctx: TangHttpContext): String {
        // 生成随机 token
        let randomBytes = SecureRandom().nextBytes(this.tokenLength)
        let token = toHexString(randomBytes)

        // 生成签名：HMAC(secretKey, token.timestamp)
        let timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
        let data = token + "." + "${timestamp}"
        let signature = generateSignature(data)

        // 返回：token.signature.timestamp
        return "${token}.${signature}.${timestamp}"
    }

    /// 验证 CSRF token
    public func validateToken(token: String, ctx: TangHttpContext): Bool {
        let parts = token.split(".")
        if (parts.size != 3) {
            return false
        }

        let tokenValue = parts[0]
        let signature = parts[1]
        let timestamp = parts[2]

        // 验证时间戳
        let tokenTime = Int64.tryParse(timestamp)
        if (let None <- tokenTime) {
            return false
        }

        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        if (let Some(time) <- tokenTime) {
            if (now - time > this.expiration) {
                return false  // token 过期
            }

            // 验证签名
            let data = tokenValue + "." + timestamp
            let expectedSignature = generateSignature(data)

            if (signature == expectedSignature) {
                return true
            }
        }

        return false
    }

    /// 生成签名
    private func generateSignature(data: String): String {
        let hmac = HMAC(this.secretKey, HashType.SHA256)
        hmac.write(data.toArray())
        let signature = hmac.finish()
        return toHexString(signature)
    }
}

/// 设置密钥
public func withSecretKey(key: String): CSRFOption {
    return { config => config.setSecretKey(key) }
}

/// 设置密钥（字节数组）
public func withSecretKeyBytes(key: Array<UInt8>): CSRFOption {
    return { config => config.setSecretKeyBytes(key) }
}

/// 设置 token 长度
public func withTokenLength(length: Int32): CSRFOption {
    return { config => config.setTokenLength(length) }
}

/// 设置 token 查找位置
public func withTokenLookup(lookup: String): CSRFOption {
    return { config => config.setTokenLookup(lookup) }
}

/// 添加排除路径
public func withExcludePath(path: String): CSRFOption {
    return { config => config.addExcludePath(path) }
}

/// 设置排除路径列表
public func withExcludedPaths(paths: Array<String>): CSRFOption {
    return { config => config.setExcludedPaths(paths) }
}

/// 设置排除的 HTTP 方法
public func withExcludedMethods(methods: Array<String>): CSRFOption {
    return { config => config.setExcludedMethods(methods) }
}

/// 设置 token 过期时间
public func withExpiration(seconds: Int64): CSRFOption {
    return { config => config.setExpiration(seconds) }
}

/// 设置错误处理器
public func withErrorHandler(handler: (TangHttpContext) -> Unit): CSRFOption {
    return { config => config.setErrorHandler(handler) }
}

/// CSRF 中间件（带配置）
///
/// 防止跨站请求伪造（CSRF）攻击
///
/// 工作原理：
/// 1. 对于安全的方法（GET、HEAD 等），生成 token 并存储
/// 2. 对于不安全的方法（POST、PUT、DELETE 等），验证 token
/// 3. token 使用 HMAC 签名，防止伪造
///
/// 示例：
/// ```cj
/// import tang.middleware.csrf.{csrf, withSecretKey}
///
/// r.use(csrf([
///     withSecretKey("your-secret-key-here"),
///     withExpiration(3600),  // 1 小时过期
///     withExcludePath("/api/public/*")  // 公开 API 不需要 CSRF
/// ]))
///
/// // 在 handler 中获取 token
/// r.get("/api/csrf-token", { ctx =>
///     let token = ctx.csrfToken()
///     ctx.json(HashMap<String, String>([
///         ("token", token),
///         ("header", "X-CSRF-Token")
///     ]))
/// })
/// ```
public func csrf(opts: Array<CSRFOption>): MiddlewareFunc {
    let config = CSRFConfig()
    for (opt in opts) {
        opt(config)
    }

    // 验证密钥已设置
    if (config.secretKey.isEmpty()) {
        config.setSecretKey("default-csrf-secret-key-please-change-in-production")
    }

    return { next =>
        return { ctx: TangHttpContext =>
            let method = ctx.method()
            let path = ctx.path()

            // 检查是否排除
            if (config.isPathExcluded(path) || config.isMethodExcluded(method)) {
                next(ctx)
                return
            }

            // 不安全的方法需要验证 token
            if (method == "POST" || method == "PUT" || method == "PATCH" || method == "DELETE") {
                let token = extractToken(ctx, config.tokenLookup)

                match (token) {
                    case Some(t) =>
                        if (config.validateToken(t, ctx)) {
                            next(ctx)
                        } else {
                            config.errorHandler(ctx)
                        }
                    case None =>
                        config.errorHandler(ctx)
                }
            } else {
                // 安全的方法，生成 token 并存储到 context
                let token = config.generateToken(ctx)
                ctx.kvSet("csrf_token", token)
                next(ctx)
            }
        }
    }
}

/// CSRF 中间件（默认配置）
public func csrf(): MiddlewareFunc {
    return csrf(Array<CSRFOption>())
}

/// 从请求中提取 token
func extractToken(ctx: TangHttpContext, lookup: String): ?String {
    let parts = lookup.split(":")
    if (parts.size != 2) {
        return None
    }

    let source = parts[0]
    let key = parts[1]

    match (source) {
        case "header" =>
            return ctx.request.headers.getFirst(key)
        case "query" =>
            return ctx.query(key)
        case "form" =>
            // TODO: 实现表单解析后支持
            return None
        case _ =>
            return None
    }
}

