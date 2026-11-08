package tang.middleware.favicon

import tang.{MiddlewareFunc, TangHttpContext}

/// Favicon 中间件
///
/// 自动处理 /favicon.ico 请求，避免每次返回 404
///
/// 示例：
/// ```cj
/// // 使用默认的空 favicon（1x1 透明 GIF）
/// r.use(favicon())
///
/// // 自定义 URL 路径
/// r.use(favicon(urlPath: "/custom/icon.ico"))
/// ```
public func favicon(urlPath!: String = "/favicon.ico"): MiddlewareFunc {
    // 默认的 1x1 透明 GIF (35 字节)
    let defaultFavicon = Array<UInt8>(35, { i =>
        [0x47u8, 0x49u8, 0x46u8, 0x38u8, 0x39u8, 0x61u8, 0x01u8, 0x00u8,
         0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x21u8, 0xF9u8, 0x04u8,
         0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x2Cu8, 0x00u8, 0x00u8,
         0x00u8, 0x00u8, 0x01u8, 0x00u8, 0x01u8, 0x00u8, 0x00u8, 0x02u8,
         0x02u8, 0x04u8, 0x01u8, 0x00u8, 0x3Bu8][i]
    })

    return { next =>
        return { ctx: TangHttpContext =>
            // 只处理 favicon 请求
            if (ctx.request.url.path == urlPath) {
                ctx.responseBuilder.status(200u16)
                ctx.responseBuilder.header("Content-Type", "image/x-icon")
                ctx.responseBuilder.header("Cache-Control", "public, max-age=86400")
                ctx.responseBuilder.body(defaultFavicon)
                ctx.abortWithStatus(200u16, body: None)
            } else {
                // 不是 favicon 请求，继续处理
                next(ctx)
            }
        }
    }
}
