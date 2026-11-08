package tang.middleware.rewrite

import std.regex.{Regex, RegexFlag}
import std.collection.ArrayList
import tang.{MiddlewareFunc, TangHttpContext}

/// URL 重写规则
public class RewriteRule {
    var pattern: Regex  // 匹配模式
    var replacement: String  // 替换字符串

    public init(pattern: String, replacement: String) {
        // 编译正则表达式，忽略大小写
        this.pattern = Regex(pattern, [RegexFlag.IgnoreCase])
        this.replacement = replacement
    }

    public init(pattern: Regex, replacement: String) {
        this.pattern = pattern
        this.replacement = replacement
    }
}

/// Rewrite 中间件配置选项
public type RewriteOption = (RewriteConfig) -> Unit

/// Rewrite 配置
public class RewriteConfig {
    var rules: ArrayList<RewriteRule> = ArrayList<RewriteRule>()

    public init() {}

    /// 添加重写规则
    public func addRule(rule: RewriteRule): Unit {
        this.rules.add(rule)
    }

    /// 添加重写规则（字符串模式）
    public func addRule(pattern: String, replacement: String): Unit {
        this.rules.add(RewriteRule(pattern, replacement))
    }

    /// 应用所有规则
    public func apply(path: String): String {
        var result = path
        for (rule in this.rules) {
            // 使用正则替换
            result = rule.pattern.replace(result, rule.replacement)
        }
        return result
    }
}

/// 添加重写规则（对象形式）
public func withRule(rule: RewriteRule): RewriteOption {
    return { config => config.addRule(rule) }
}

/// 添加重写规则（字符串形式）
public func withRewriteRule(pattern: String, replacement: String): RewriteOption {
    return { config => config.addRule(pattern, replacement) }
}

/// 批量添加重写规则
public func withRules(rules: ArrayList<RewriteRule>): RewriteOption {
    return { config =>
        for (rule in rules) {
            config.addRule(rule)
        }
    }
}

/// 创建路径重写函数（用于 Router.addRewriteRule）
///
/// 这个函数返回一个 (String) -> String 函数，可以直接注册到 Router
/// 重写规则会在路由匹配之前执行，这是正确的实现方式
///
/// 示例：
/// ```cj
/// import tang.middleware.rewrite.createRewriteFunction
///
/// r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))
/// r.addRewriteRule(createRewriteFunction("/old/api/(.*)", "/api/$1"))
/// ```
public func createRewriteFunction(pattern: String, replacement: String): (String) -> String {
    let regex = Regex(pattern, [RegexFlag.IgnoreCase])
    return { path =>
        // 使用 group: true 参数获取捕获组
        let matches = regex.findAll(path, group: true)
        if (matches.size > 0) {
            let matchData = matches[0]
            var result = replacement

            // 替换所有 $1, $2, ... 占位符
            // 捕获组从索引 1 开始，0 是整个匹配
            for (i in 1..matchData.groupCount() + 1) {
                let groupValue = matchData.matchString(i)
                let placeholder = "$${i}"
                result = result.replace(placeholder, groupValue)
            }

            return result
        } else {
            return path
        }
    }
}

/// 重写单个规则
/// 支持通配符和正则表达式
///
/// 示例：
/// ```cj
/// // API 版本升级
/// r.use(rewrite("/api/v1/(.*)", "/api/v2/$1"))
///
/// // 旧路径重定向到新路径
/// r.use(rewrite("/old/(.*)", "/new/$1"))
///
/// // 移除前缀
/// r.use(rewrite("/api/v2/(.*)", "/$1"))
///
/// // 多条规则
/// r.use(rewrite([
///     withRewriteRule("/api/v1/(.*)", "/api/v2/$1"),
///     withRewriteRule("/old/(.*)", "/new/$1")
/// ]))
/// ```
public func rewrite(pattern: String, replacement: String): MiddlewareFunc {
    return rewrite([withRewriteRule(pattern, replacement)])
}

/// 重写多条规则
public func rewrite(opts: Array<RewriteOption>): MiddlewareFunc {
    let config = RewriteConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 获取原始路径
            let originalPath = ctx.path()

            // 应用所有重写规则
            let newPath = config.apply(originalPath)

            // 如果路径改变，存储重写后的路径到 context
            if (newPath != originalPath) {
                // 存储重写后的路径，让路由系统使用它
                ctx.kvSet("rewritten_path", newPath)
            }

            // 继续处理请求
            next(ctx)
        }
    }
}

/// 重写规则便捷函数
///
/// 创建重写规则对象
///
/// 示例：
/// ```cj
/// import tang.middleware.rewrite.{RewriteRule}
///
/// let rule1 = RewriteRule("/api/v1/(.*)", "/api/v2/$1")
/// let rule2 = RewriteRule("/old/(.*)", "/new/$1")
///
/// r.use(rewrite([withRules([rule1, rule2])]))
/// ```
public func createRule(pattern: String, replacement: String): RewriteRule {
    return RewriteRule(pattern, replacement)
}

