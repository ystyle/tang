package tang.compose

import std.collection.ArrayList
import std.sync.Mutex
import ystyle::tachyon.RequestCtx
import tang.{Tang, Router, HandlerFunc, TangHttpContext, Params}

/// 组合路由：按路径前缀把请求委派给多个子 Router，最长前缀优先
///
/// 场景：多个子系统/框架共用一个端口。
/// 与 `Router.mount()` 的区别：
///   - `mount()` 是**注册展开**（把子路由逐条注册进父 Router，中间件在注册时固定）
///   - `compose` 是**运行时委派**（子 Router 保持独立，各自的路由表/中间件/404 语义完整保留）
///
/// 匹配规则：
/// - 段边界：`/api` 匹配 `/api`、`/api/users`，不匹配 `/apix`
/// - 重叠前缀取最长（`/api/v1` 优先于 `/api`）
/// - 未命中任何前缀 → fallback（默认 404）
/// - 路径不剥离：子 Router 看到的是完整路径
public class ComposeRouter {
    let mu = Mutex()
    var mounts: ArrayList<(String, HandlerFunc)> = ArrayList<(String, HandlerFunc)>()
    var fallback: HandlerFunc = { ctx: TangHttpContext =>
        ctx.responseBuilder.status(404u16).body("404 Not Found")
    }

    public init() {}

    /// 挂载一个子 Router 到指定前缀（前缀必须 / 开头）
    public func mount(prefix: String, router: Router): ComposeRouter {
        return this.mount(prefix, { ctx: TangHttpContext =>
            router.handleWith(ctx.raw, ctx)
        })
    }

    /// 挂载任意 handler 到指定前缀（用于挂非 tang 的子系统，包一层即可）
    public func mount(prefix: String, handler: HandlerFunc): ComposeRouter {
        synchronized(mu) {
            this.mounts.add((normalize(prefix), handler))
        }
        return this
    }

    /// 设置兜底 handler（未命中任何前缀时使用），默认 404
    public func setFallback(handler: HandlerFunc): ComposeRouter {
        synchronized(mu) {
            this.fallback = handler
        }
        return this
    }

    /// 取当前所有挂载（前缀, handler），按前缀长度降序（最长匹配优先）
    func sortedMounts(): ArrayList<(String, HandlerFunc)> {
        let list = ArrayList<(String, HandlerFunc)>()
        synchronized(mu) {
            for (m in mounts) {
                list.add(m)
            }
        }
        // 简单插入排序：挂载数量通常很少（几条到几十条）
        var i: Int64 = 1
        while (i < list.size) {
            let cur = list[i]
            var j = i - 1
            while (j >= 0 && list[j][0].size < cur[0].size) {
                list[j + 1] = list[j]
                j -= 1
            }
            list[j + 1] = cur
            i += 1
        }
        return list
    }

    /// 按路径选中最长匹配前缀的 handler（无匹配返回 None）
    public func lookup(path: String): ?HandlerFunc {
        for (m in sortedMounts()) {
            let prefix = m[0]
            if (path == prefix || path.startsWith(prefix + "/")) {
                return Some(m[1])
            }
        }
        return None
    }

    /// 作为 tachyon 的 handler 入口
    public func handle(ctx: RequestCtx): Unit {
        let path = ctx.path().toStr()
        let handler = match (lookup(path)) {
            case Some(h) => h
            case None => fallback
        }
        handler(TangHttpContext(ctx, Params()))
    }

    /// 便利：包成一个 HandlerFunc
    public func handler(): HandlerFunc {
        return { ctx: TangHttpContext =>
            this.handle(ctx.raw)
        }
    }

    /// 挂到 Tang 应用上：所有未命中 tang 自身路由的请求再过 compose
    public func install(app: Tang): ComposeRouter {
        // 放在最后：tang 自己的路由优先，其余交给 compose（fallback 里可继续 next）
        app.get("/*", this.handler())
        return this
    }

    func normalize(prefix: String): String {
        if (prefix.isEmpty()) {
            return "/"
        }
        if (!prefix.startsWith("/")) {
            return "/" + prefix
        }
        return prefix
    }
}
