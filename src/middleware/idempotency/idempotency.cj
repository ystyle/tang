package tang.middleware.idempotency

import std.collection.HashMap
import std.collection.ArrayList
import std.sync.Mutex
import std.time.DateTime
import stdx.crypto.digest.SHA256
import stdx.encoding.hex.toHexString
import tang.{MiddlewareFunc, TangHttpContext}
import stdx.net.http.HttpStatusCode

/// 幂等性中间件配置选项
public type IdempotencyOption = (IdempotencyConfig) -> Unit

/// 幂等性响应缓存
public class CachedResponse {
    var statusCode: UInt16
    var body: String
    var timestamp: Int64

    public init(statusCode: UInt16, body: String) {
        this.statusCode = statusCode
        this.body = body
        this.timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
    }
}

/// 幂等性存储（内存实现）
public class IdempotencyStore {
    var cache: HashMap<String, CachedResponse> = HashMap<String, CachedResponse>()
    var mutex: Mutex = Mutex()
    var lifetime: Int64  // 缓存生命周期（秒）

    public init(lifetime: Int64) {
        this.lifetime = lifetime
    }

    /// 获取缓存的响应
    public func get(key: String): ?CachedResponse {
        this.mutex.lock()
        let cached = this.cache.get(key)
        this.mutex.unlock()

        // 检查是否过期
        match (cached) {
            case Some(response) =>
                let now = DateTime.now().toUnixTimeStamp().toSeconds()
                if (now - response.timestamp > this.lifetime) {
                    // 过期，删除缓存
                    this.mutex.lock()
                    this.cache.remove(key)
                    this.mutex.unlock()
                    return None
                }
                return cached
            case None =>
                return None
        }
    }

    /// 保存响应到缓存
    public func set(key: String, response: CachedResponse): Unit {
        this.mutex.lock()
        this.cache[key] = response
        this.mutex.unlock()
    }

    /// 清理过期缓存
    public func cleanup(): Unit {
        this.mutex.lock()
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        let expiredKeys = ArrayList<String>()

        for ((key, response) in this.cache) {
            if (now - response.timestamp > this.lifetime) {
                expiredKeys.add(key)
            }
        }

        for (key in expiredKeys) {
            this.cache.remove(key)
        }

        this.mutex.unlock()
    }
}

/// 幂等性配置
public class IdempotencyConfig {
    var keyHeader: String = "X-Idempotency-Key"  // 幂等性 key 的 header 名称
    var lifetime: Int64 = 3600  // 缓存生命周期（秒，默认 1 小时）
    var excludedPaths: ArrayList<String> = ArrayList<String>()  // 排除路径
    var excludedMethods: ArrayList<String> = ArrayList<String>(["GET", "HEAD", "OPTIONS"])  // 排除的方法
    var keyLookup: String = "header:X-Idempotency-Key"  // key 查找位置
    var errorHandler: (TangHttpContext) -> Unit = { ctx =>
        ctx.responseBuilder.status(HttpStatusCode.STATUS_BAD_REQUEST)
        ctx.responseBuilder.body("{\"error\":\"Missing or invalid idempotency key\"}")
    }

    var store: IdempotencyStore = IdempotencyStore(3600)

    public init() {}

    /// 设置 key 的 header 名称
    public func setKeyHeader(header: String): Unit {
        this.keyHeader = header
    }

    /// 设置缓存生命周期（秒）
    public func setLifetime(seconds: Int64): Unit {
        this.lifetime = seconds
        this.store = IdempotencyStore(seconds)
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

    /// 设置 key 查找位置
    /// 格式："header:X-Idempotency-Key" 或 "query:idempotency_key"
    public func setKeyLookup(lookup: String): Unit {
        this.keyLookup = lookup
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

    /// 生成幂等 key
    public func generateKey(ctx: TangHttpContext, userKey: ?String): String {
        // 如果用户提供了自定义 key，使用用户的 key
        match (userKey) {
            case Some(k) => return k
            case None => ()  // 继续执行，生成 key
        }

        // 否则基于请求内容生成 key
        let method = ctx.method()
        let path = ctx.path()
        // 获取查询字符串（简化处理）
        var query = ""
        // TODO: 正确获取查询字符串
        let sessionID = ctx.requestid() ?? "anonymous"

        // 读取请求体（用于 POST/PUT 等方法）
        var bodyStr = ""
        if (method == "POST" || method == "PUT" || method == "PATCH") {
            // TODO: 读取请求体
            bodyStr = ""
        }

        // 组合数据：method.path.query.sessionID.body
        let data = method + "." + path + "." + query + "." + sessionID + "." + bodyStr
        let hash = SHA256()
        hash.write(data.toArray())
        let hashed = hash.finish()

        // 使用标准库的十六进制编码
        return toHexString(hashed)
    }
}

/// 设置 key 的 header 名称
public func withKeyHeader(header: String): IdempotencyOption {
    return { config => config.setKeyHeader(header) }
}

/// 设置缓存生命周期
public func withLifetime(seconds: Int64): IdempotencyOption {
    return { config => config.setLifetime(seconds) }
}

/// 添加排除路径
public func withExcludePath(path: String): IdempotencyOption {
    return { config => config.addExcludePath(path) }
}

/// 设置排除路径列表
public func withExcludedPaths(paths: Array<String>): IdempotencyOption {
    return { config => config.setExcludedPaths(paths) }
}

/// 设置排除的 HTTP 方法
public func withExcludedMethods(methods: Array<String>): IdempotencyOption {
    return { config => config.setExcludedMethods(methods) }
}

/// 设置 key 查找位置
public func withKeyLookup(lookup: String): IdempotencyOption {
    return { config => config.setKeyLookup(lookup) }
}

/// 设置错误处理器
public func withErrorHandler(handler: (TangHttpContext) -> Unit): IdempotencyOption {
    return { config => config.setErrorHandler(handler) }
}

/// 幂等性中间件（带配置）
///
/// 防止重复提交，适用于支付、订单等重要操作
///
/// 工作原理：
/// 1. 从请求中提取幂等 key（header 或自动生成）
/// 2. 检查缓存中是否已有该 key 的响应
/// 3. 如果有，返回缓存的响应
/// 4. 如果没有，执行请求并缓存响应
///
/// 示例：
/// ```cj
/// import tang.middleware.idempotency.{idempotency, withLifetime, withKeyHeader}
///
/// r.use(idempotency([
///     withKeyHeader("X-Idempotency-Key"),  // 从 header 获取 key
///     withLifetime(3600)  // 1 小时过期
/// ]))
///
/// // 客户端请求时需要提供幂等 key
/// // curl -H "X-Idempotency-Key: unique-key-123" -X POST http://localhost/api/payment
/// ```
public func idempotency(opts: Array<IdempotencyOption>): MiddlewareFunc {
    let config = IdempotencyConfig()
    for (opt in opts) {
        opt(config)
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

            // 提取幂等 key
            let userKey = extractKey(ctx, config.keyLookup)

            // 检查是否提供了自定义 key
            match (userKey) {
                case Some(k) =>
                    // 生成最终的 key
                    let key = config.generateKey(ctx, userKey)

                    // 检查缓存
                    let cached = config.store.get(key)
                    match (cached) {
                        case Some(response) =>
                            // 返回缓存的响应
                            ctx.responseBuilder.status(response.statusCode)
                            ctx.responseBuilder.body(response.body)
                        case None =>
                            // 将 key 保存到 context，供 handler 使用
                            ctx.kvSet("idempotency_key", key)
                            ctx.kvSet("idempotency_store", config.store)

                            // 执行请求
                            next(ctx)
                    }
                case None =>
                    // 没有提供 key，调用错误处理器
                    config.errorHandler(ctx)
            }
        }
    }
}

/// 幂等性中间件（默认配置）
public func idempotency(): MiddlewareFunc {
    return idempotency(Array<IdempotencyOption>())
}

/// 从请求中提取幂等 key
func extractKey(ctx: TangHttpContext, lookup: String): ?String {
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
        case _ =>
            return None
    }
}
