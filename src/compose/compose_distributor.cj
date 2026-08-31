package tang.compose

import std.collection.ArrayList
import stdx.net.http.{HttpRequestDistributor, HttpRequestHandler, HttpContext, FuncHandler, NotFoundHandler}

/// 默认兜底分发器：未匹配 mount 前缀时返回 404
class NotFoundDistributor <: HttpRequestDistributor {
    public func register(path: String, handler: HttpRequestHandler): Unit {
        ()
    }

    public func register(path: String, handler: (HttpContext) -> Unit): Unit {
        ()
    }

    public func distribute(path: String): HttpRequestHandler {
        NotFoundHandler()
    }
}

/// 组合分发器：按路径前缀把请求委派给多个子分发器（最长前缀优先）
///
/// 场景：多框架共享一个端口。tang Router、MCP 服务等各自以完整 distributor
/// 身份 mount 进来，路径不剥离，子分发器内部语义（参数/404/中间件）完整保留。
///
/// 示例：
/// ```cj
/// let compose = ComposeDistributor()
///     .mount("/api", tangApp.getRouter())
///     .mount("/mcp", mcpTransport)
///     .setFallback(tangApp2.getRouter())
///
/// let server = ServerBuilder().distributor(compose).build()
/// server.serve()
/// ```
///
/// 匹配规则：
/// - 前缀段边界：`/api` 匹配 `/api`、`/api/users`，不匹配 `/apix`
/// - 重叠前缀取最长（`/api/v1` 优先于 `/api`）
/// - 未命中任何 mount 前缀 → fallback
/// - 自身也是 HttpRequestDistributor，可再被嵌套组合
public class ComposeDistributor <: HttpRequestDistributor {
    var mounts: ArrayList<(String, HttpRequestDistributor)> = ArrayList()
    var fallback: HttpRequestDistributor = NotFoundDistributor()

    /// 挂载一个子分发器到指定前缀（前缀必须 / 开头）
    public func mount(prefix: String, distributor: HttpRequestDistributor): ComposeDistributor {
        this.mounts.add((prefix, distributor))
        this
    }

    /// 设置兜底分发器（未命中任何 mount 前缀时使用），默认 404
    public func setFallback(distributor: HttpRequestDistributor): ComposeDistributor {
        this.fallback = distributor
        this
    }

    /// 组合层不收 handler，转发给 fallback（stdx register 契约）
    public func register(path: String, handler: HttpRequestHandler): Unit {
        this.fallback.register(path, handler)
    }

    public func register(path: String, handler: (HttpContext) -> Unit): Unit {
        this.fallback.register(path, FuncHandler(handler))
    }

    public func distribute(path: String): HttpRequestHandler {
        var best: ?(String, HttpRequestDistributor) = None
        for (m in this.mounts) {
            let prefix = m[0]
            // 段边界匹配：path == prefix 或以 prefix + "/" 开头
            if (path == prefix || path.startsWith("${prefix}/")) {
                if (let None <- best || prefix.size > best.getOrThrow()[0].size) {
                    best = Some(m)  // 最长前缀优先
                }
            }
        }
        if (let Some((_, d)) <- best) {
            return d.distribute(path)
        }
        return this.fallback.distribute(path)
    }
}
