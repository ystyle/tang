package tang.middleware.cache

import std.regex.{Regex, RegexFlag}
import std.collection.ArrayList
import std.time.DateTime
import tang.{MiddlewareFunc, TangHttpContext}

/// 缓存规则
public class CacheRule {
    var pattern: Regex  // 匹配模式
    var maxAge: Int64  // 缓存时间（秒）
    var mustRevalidate: Bool = false  // 是否必须重新验证
    var noCache: Bool = false  // 是否禁用缓存

    public init(pattern: String, maxAge: Int64) {
        this.pattern = Regex(pattern, [RegexFlag.IgnoreCase])
        this.maxAge = maxAge
    }

    public init(pattern: String, maxAge: Int64, mustRevalidate: Bool) {
        this.pattern = Regex(pattern, [RegexFlag.IgnoreCase])
        this.maxAge = maxAge
        this.mustRevalidate = mustRevalidate
    }

    public init(pattern: Regex, maxAge: Int64, mustRevalidate: Bool, noCache: Bool) {
        this.pattern = pattern
        this.maxAge = maxAge
        this.mustRevalidate = mustRevalidate
        this.noCache = noCache
    }

    /// 匹配路径
    public func matches(path: String): Bool {
        this.pattern.matches(path)
    }
}

/// Cache 中间件配置选项
public type CacheOption = (CacheConfig) -> Unit

/// Cache 配置
public class CacheConfig {
    var defaultMaxAge: Int64 = 0  // 默认缓存时间（秒，0表示不缓存）
    var rules: ArrayList<CacheRule> = ArrayList<CacheRule>()  // 特定路径的缓存规则
    var mustRevalidate: Bool = false  // 默认是否必须重新验证
    var noStore: Bool = false  // 默认是否不存储
    var private: Bool = false  // 默认是否为私有缓存
    var excludePaths: ArrayList<String> = ArrayList<String>()  // 排除路径（不设置 Cache-Control）

    public init() {}

    /// 设置默认缓存时间（秒）
    public func setDefaultMaxAge(seconds: Int64): Unit {
        this.defaultMaxAge = seconds
    }

    /// 添加缓存规则
    public func addRule(rule: CacheRule): Unit {
        this.rules.add(rule)
    }

    /// 设置是否必须重新验证
    public func setMustRevalidate(must: Bool): Unit {
        this.mustRevalidate = must
    }

    /// 设置是否不存储
    public func setNoStore(noStore: Bool): Unit {
        this.noStore = noStore
    }

    /// 设置为私有缓存
    public func setPrivate(isPrivate: Bool): Unit {
        this.private = isPrivate
    }

    /// 添加排除路径
    public func addExcludePath(path: String): Unit {
        this.excludePaths.add(path)
    }

    /// 检查路径是否被排除
    public func isExcluded(path: String): Bool {
        for (excludePath in this.excludePaths) {
            if (path.startsWith(excludePath)) {
                return true
            }
        }
        return false
    }

    /// 为指定路径获取缓存配置
    public func getCacheConfig(path: String): (Int64, Bool, Bool) {
        // 先检查特定规则
        for (rule in this.rules) {
            if (rule.matches(path)) {
                return (rule.maxAge, rule.mustRevalidate, rule.noCache)
            }
        }

        // 使用默认配置
        return (this.defaultMaxAge, this.mustRevalidate, this.noStore)
    }
}

/// 设置默认缓存时间（秒）
public func withDuration(seconds: Int64): CacheOption {
    return { config => config.setDefaultMaxAge(seconds) }
}

/// 添加缓存规则
public func withRule(rule: CacheRule): CacheOption {
    return { config => config.addRule(rule) }
}

/// 批量添加缓存规则
public func withRules(rules: Array<CacheRule>): CacheOption {
    return { config =>
        for (rule in rules) {
            config.addRule(rule)
        }
    }
}

/// 设置必须重新验证
public func withMustRevalidate(): CacheOption {
    return { config => config.setMustRevalidate(true) }
}

/// 设置不存储
public func withNoStore(): CacheOption {
    return { config => config.setNoStore(true) }
}

/// 设置为私有缓存
public func withPrivateCache(): CacheOption {
    return { config => config.setPrivate(true) }
}

/// 排除指定路径（不设置 Cache-Control 头）
public func withExcludePaths(paths: Array<String>): CacheOption {
    return { config =>
        for (path in paths) {
            config.addExcludePath(path)
        }
    }
}

/// 排除单个路径
public func withExcludePath(path: String): CacheOption {
    return { config => config.addExcludePath(path) }
}

/// Cache 中间件（带配置）
///
/// 设置 Cache-Control 响应头，控制客户端缓存行为
///
/// 示例：
/// ```cj
/// // 所有响应缓存 1 小时
/// r.use(cache([withDuration(3600)]))
///
/// // 不同路径使用不同的缓存策略
/// r.use(cache([
///     withDuration(3600),  // 默认缓存 1 小时
///     withRules([
///         CacheRule("/api/*", 0),           // API 不缓存
///         CacheRule("/static/*", 86400),    // 静态文件缓存 1 天
///         CacheRule("/images/*", 604800)    // 图片缓存 1 周
///     ])
/// ]))
///
/// // 禁用缓存
/// r.use(cache([
///     withNoStore(),
///     withRules([CacheRule("/api/*", 0)])  // API 路径不缓存
/// ]))
///
/// // 必须重新验证
/// r.use(cache([
///     withDuration(3600),
///     withMustRevalidate()
/// ]))
///
/// // 私有缓存（CDN 不会缓存）
/// r.use(cache([
///     withDuration(3600),
///     withPrivateCache()
/// ]))
/// ```
public func cache(opts: Array<CacheOption>): MiddlewareFunc {
    let config = CacheConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 先执行下一个处理器
            next(ctx)

            // 检查路径是否被排除
            if (config.isExcluded(ctx.path())) {
                return
            }

            // 获取路径对应的缓存配置
            let (maxAge, mustRevalidate, noCache) = config.getCacheConfig(ctx.path())

            // 构建 Cache-Control 头
            var directives = ArrayList<String>()

            if (noCache || maxAge == 0) {
                // 禁用缓存
                directives.add("no-cache")
                directives.add("no-store")
                directives.add("must-revalidate")
            } else {
                // 设置缓存时间
                directives.add("max-age=${maxAge}")

                if (mustRevalidate) {
                    directives.add("must-revalidate")
                }

                if (config.private) {
                    directives.add("private")
                } else {
                    directives.add("public")
                }
            }

            // 设置 Cache-Control 响应头
            let cacheControl = buildCacheControl(directives)
            ctx.responseBuilder.header("Cache-Control", cacheControl)

            // 如果设置了缓存时间，也设置 Expires 头（向后兼容）
            if (maxAge > 0) {
                let now = DateTime.now()
                let expireTime = DateTime.fromUnixTimeStamp(
                    now.toUnixTimeStamp() + Duration.second * maxAge
                )
                // 格式化为 HTTP 日期格式（简化版）
                ctx.responseBuilder.header("Expires", "${expireTime}")
            }
        }
    }
}

/// Cache 中间件（默认配置）
public func cache(): MiddlewareFunc {
    return cache(Array<CacheOption>())
}

/// 辅助函数：构建 Cache-Control 字符串
func buildCacheControl(directives: ArrayList<String>): String {
    if (directives.isEmpty()) {
        return ""
    }

    var result = directives[0]
    for (i in 1..directives.size) {
        result = result + ", " + directives[i]
    }
    return result
}

/// 创建缓存规则的便捷函数
///
/// 示例：
/// ```cj
/// import tang.middleware.cache.{CacheRule}
///
/// r.use(cache([
///     withRules([
///         CacheRule("/api/*", 0),           // 不缓存
///         CacheRule("/static/*", 86400),    // 缓存 1 天
///         CacheRule("/images/*", 604800)    // 缓存 1 周
///     ])
/// ]))
/// ```

/// 便捷创建：创建禁用缓存的规则
public func noCacheRule(pattern: String): CacheRule {
    return CacheRule(pattern, 0)
}

/// 便捷创建：创建长时间缓存的规则（天）
public func dailyCacheRule(pattern: String): CacheRule {
    return CacheRule(pattern, 86400)  // 24 小时
}

/// 便捷创建：创建中等时间缓存的规则（小时）
public func hourlyCacheRule(pattern: String, hours: Int64): CacheRule {
    return CacheRule(pattern, hours * 3600)
}
