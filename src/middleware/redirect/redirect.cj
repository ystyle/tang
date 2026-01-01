package tang.middleware.redirect

import stdx.net.http.{HttpStatusCode}
import tang.{HandlerFunc, MiddlewareFunc, TangHttpContext}

/// 重定向处理器
///
/// 支持 301（永久重定向）和 302（临时重定向）
///
/// 示例：
/// ```cj
/// // 永久重定向
/// r.get("/old-path", redirect(url: "/new-path", statusCode: 301))
///
/// // 临时重定向（默认）
/// r.get("/temp", redirect(url: "/new"))
/// ```
public func redirect(url!: String, statusCode!: UInt16 = 302): HandlerFunc {
    return { ctx: TangHttpContext =>
        ctx.responseBuilder.status(statusCode)
        ctx.responseBuilder.header("Location", url)
        ctx.responseBuilder.body("")
    }
}

/// 重定向中间件
///
/// 将匹配的路径重定向到新路径
///
/// 示例：
/// ```cj
/// // 重定向 /old/* 到 /new/*（临时重定向）
/// r.use(redirectMiddleware(fromPath: "/old", toPath: "/new"))
///
/// // 重定向特定路径（永久重定向）
/// r.use(redirectMiddleware(fromPath: "/api/v1/users", toPath: "/api/v2/users", statusCode: 301))
/// ```
public func redirectMiddleware(fromPath!: String, toPath!: String, statusCode!: UInt16 = 302): MiddlewareFunc {
    return { next =>
        return { ctx: TangHttpContext =>
            let requestPath = ctx.request.url.path

            // 检查路径是否匹配
            if (requestPath == fromPath || requestPath.startsWith("${fromPath}/")) {
                // 构建目标路径
                var target = toPath
                if (requestPath.startsWith("${fromPath}/")) {
                    // 保留路径的剩余部分
                    let remainder = requestPath[fromPath.size..requestPath.size]
                    target = "${toPath}${remainder}"
                }

                ctx.responseBuilder.status(statusCode)
                ctx.responseBuilder.header("Location", target)
                ctx.responseBuilder.body("")
            } else {
                // 路径不匹配，继续处理
                next(ctx)
            }
        }
    }
}

