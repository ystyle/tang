package middleware
import tang.{ MiddlewareFunc, HandlerFunc }
from std import log.Logger, log.SimpleLogger, log.LogLevel
from std import time.DateTime
from std import fs.{ File, OpenOption }

let log:Logger = SimpleLogger("[Tang]", LogLevel.INFO, File("/dev/stdout", OpenOption.CreateOrTruncate(false)))

public func logMiddleware (handler: HandlerFunc): HandlerFunc {
    return {w, r =>
        let t = DateTime.now()
        let url = r.request.requestURI
        let method = r.request.method
        handler(w, r)
        let ts = DateTime.now()-t
        let code = w.header().get("StatusCode")
        print(w.header().getKeysToString())
        log.info("${ts} | ${method.toString()} | ${code} | ${url}")
    }
}

