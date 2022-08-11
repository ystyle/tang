package middleware

from net import http.ResponseWriteStream, http.HttpStatusCode
import tang.{ MiddlewareFunc, HandlerFunc, Request }


public type BasicAuthCheckFunc = (Request) -> Bool
public type WithBasicAuthRealmOption = (BasicAuth) -> Unit

public class BasicAuth {
    var realm:String
    var check:BasicAuthCheckFunc
    init(realm:String, check:BasicAuthCheckFunc) {
        this.realm = realm
        this.check = check
    }
    public func Middleware (next:HandlerFunc):HandlerFunc {
        return {w,r =>
            let ok = this.check(r)
            if (ok) {
                next(w, r)
            } else {
                this.basicAuth(w, r)
            }
        }
    }
    func basicAuth(w:ResponseWriteStream, r:Request):Unit {
        w.header().add("WWW-Authenticate", "basic realm=${this.realm}")
        w.writeStatusCode(HttpStatusCode.STATUS_UNAUTHORIZED)
    }
}

public func NewBasicAuthMiddleware(check:BasicAuthCheckFunc): MiddlewareFunc {
    return NewBasicAuthMiddleware(check, Array<WithBasicAuthRealmOption>())
}

public func NewBasicAuthMiddleware(check:BasicAuthCheckFunc, opts: Array<WithBasicAuthRealmOption>): MiddlewareFunc {
    let basic = BasicAuth("Restricted", check)
    for (opt in opts) {
        opt(basic)
    }
    return basic.Middleware
}

public func WithBasicAuthRealm (realm:String): WithBasicAuthRealmOption {
    return { basicauth =>
            basicauth.realm = #""${realm}""#
            ()
    }
}