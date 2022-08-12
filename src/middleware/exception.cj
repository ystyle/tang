package middleware
import tang.PlainString

public func ExceptionMiddleware (handler: HandlerFunc): HandlerFunc {
    return {w, r =>
       try {
            handler(w, r)
       } catch (e:Throwable) {
           e.printStackTrace()
           PlainString(w, "Error 500: Internal Server Error\n")
       }
    }
}