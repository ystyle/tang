package middleware
import tang.plainStringWithCode

public func exceptionMiddleware (handler: HandlerFunc): HandlerFunc {
    return {w, r =>
       try {
            handler(w, r)
       } catch (e:Exception) {
           e.printStackTrace()
           plainStringWithCode(w, 500, "Error 500: Internal Server Error\n")
       }
    }
}