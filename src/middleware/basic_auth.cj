package tang.middleware

import net.http.{HttpRequest,HttpContext, HttpStatusCode}
import tang.{ MiddlewareFunc, HandlerFunc, TangHttpContext }


public type BasicAuthCheckFunc = (HttpRequest) -> Bool
public type WithBasicAuthRealmOption = (BasicAuth) -> Unit

public class BasicAuth {
    var realm:String
    var check:BasicAuthCheckFunc
    init(realm:String, check:BasicAuthCheckFunc) {
        this.realm = realm
        this.check = check
    }
    public func middleware (next:HandlerFunc):HandlerFunc {
        return {ctx =>
            let ok = this.check(ctx.request)
            if (ok) {
                next(ctx)
            } else {
                this.basicAuth(ctx)
            }
        }
    }
    func basicAuth(ctx:TangHttpContext):Unit {
        ctx.responseBuilder.status(HttpStatusCode.STATUS_UNAUTHORIZED).header("WWW-Authenticate", "basic realm=${this.realm}")
    }
}

public func newBasicAuthMiddleware(check:BasicAuthCheckFunc): MiddlewareFunc {
    return newBasicAuthMiddleware(check, Array<WithBasicAuthRealmOption>())
}

public func newBasicAuthMiddleware(check:BasicAuthCheckFunc, opts: Array<WithBasicAuthRealmOption>): MiddlewareFunc {
    let basic = BasicAuth("Restricted", check)
    for (opt in opts) {
        opt(basic)
    }
    return basic.middleware
}

public func withBasicAuthRealm (realm:String): WithBasicAuthRealmOption {
    return { basicauth =>
            basicauth.realm = #""${realm}""#
        return ()
    }
}