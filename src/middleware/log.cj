package middleware
import tang.{ MiddlewareFunc, HandlerFunc }
from std import log.Logger, log.SimpleLogger, log.LogLevel
from std import time.Time
from std import io.File, io.AccessMode, io.OpenMode

let log:Logger = SimpleLogger("[Tang]", LogLevel.INFO, File("/dev/stdout", AccessMode.Write, OpenMode.Append))

public func LogMiddleware (handler: HandlerFunc): HandlerFunc {
    return {w, r =>
        let t = Time.now()
        let url = r.request.requestURI
        let method = r.request.method
        handler(w, r)
        let ts = Time.now()-t
        let code = w.header().get("StatusCode")
        log.info("${ts} | ${method.toString()} | ${code} | ${url}")
    }
}

