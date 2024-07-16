package tang.middleware

import tang.{HandlerFunc}

public func exceptionMiddleware(handler: HandlerFunc): HandlerFunc {
    return {
        ctx => try {
            handler(ctx)
        } catch (e: Exception) {
            e.printStackTrace()
            ctx.responseBuilder.status(500).body("Error 500: Internal Server Error\n")
        }
    }
}
