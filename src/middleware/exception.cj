package middleware
import tang.PlainStringWithCode

public func ExceptionMiddleware (handler: HandlerFunc): HandlerFunc {
    return {w, r =>
       try {
            handler(w, r)
       } catch (e:Throwable) {
           e.printStackTrace()
           PlainStringWithCode(w, 500, "Error 500: Internal Server Error\n")
       }
    }
}