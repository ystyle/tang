package tang.middleware.basicauth

import stdx.net.http.{HttpStatusCode}
import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}

public type BasicAuthCheckFunc = (TangHttpContext) -> Bool

public type WithBasicAuthRealmOption = (BasicAuth) -> Unit

public class BasicAuth {
    var realm: String = "Restricted"
    var check: BasicAuthCheckFunc
    init(realm: String, check: BasicAuthCheckFunc) {
        this.realm = realm
        this.check = check
    }
    public func middleware(next: HandlerFunc): HandlerFunc {
        return {
            ctx: TangHttpContext =>
            let ok = this.check(ctx)
            if (ok) {
                if (!ctx.isAborted()) {
                    next(ctx)
                }
            } else {
                // 认证失败，中止请求处理
                ctx.abortWithStatus(HttpStatusCode.STATUS_UNAUTHORIZED, body: "Unauthorized\n")
                ctx.responseBuilder.header("WWW-Authenticate", "basic realm=\"${this.realm}\"")
            }
        }
    }
}

public func newBasicAuth(check: BasicAuthCheckFunc): MiddlewareFunc {
    return newBasicAuth(check, Array<WithBasicAuthRealmOption>())
}

public func newBasicAuth(check: BasicAuthCheckFunc, opts: Array<WithBasicAuthRealmOption>): MiddlewareFunc {
    let basic = BasicAuth("Restricted", check)
    for (opt in opts) {
        opt(basic)
    }
    return basic.middleware
}

public func withBasicAuthRealm(realm: String): WithBasicAuthRealmOption {
    return {
        basicauth =>
        basicauth.realm = '"${realm}"'
        return ()
    }
}
