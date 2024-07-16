package tang.middleware

import net.http.HttpContext
import tang.{ MiddlewareFunc, HandlerFunc, TangHttpContext }
import std.log.{Logger,SimpleLogger, LogLevel}
import std.time.DateTime
import std.fs.{ File, OpenOption }

let log:Logger = SimpleLogger("[Tang]", LogLevel.INFO, File("/dev/stdout", OpenOption.CreateOrTruncate(false)))

public func logMiddleware (handler: HandlerFunc): HandlerFunc {
    return {ctx:TangHttpContext =>
        let t = DateTime.now()
        let url = ctx.request.url
        let method = ctx.request.method
        handler(ctx)
        let ts = DateTime.now()-t
        let code = ctx.responseBuilder.build().status
        log.info("${ts} | ${method.toString()} | ${code} | ${url}")
        return
    }
}

