package tang.middleware

import tang.{HandlerFunc}
import tang.log.getLogger

public func exceptionMiddleware(handler: HandlerFunc): HandlerFunc {
    return {
        ctx => try {
            handler(ctx)
        } catch (e: Exception) {
            e.printStackTrace()
            getLogger().error("global exception middleware", ("error", e))
            ctx.responseBuilder.status(500).body("Error 500: Internal Server Error\n")
        }
    }
}
