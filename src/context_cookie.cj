package tang

import stdx.net.http.Cookie
import std.collection.HashMap

/// Fiber 风格链式 API - Cookie 操作（使用仓颉原生 Cookie）
extend TangHttpContext {
    /// 获取指定名称的 Cookie 值
    public func cookie(name: String): ?String {
        if (let Some(cookieHeader) <- this.request.headers.getFirst("Cookie")) {
            let cookies = cookieHeader.split("; ")
            for (cookie in cookies) {
                let parts = cookie.split("=")
                if (parts.size >= 1 && parts[0] == name) {
                    return if (parts.size >= 2) {
                        Some(parts[1])
                    } else {
                        Some("")
                    }
                }
            }
        }
        return None
    }

    /// 设置 Cookie（链式调用，使用仓颉原生 Cookie）
    public func setCookie(cookie: Cookie): TangHttpContext {
        this.responseBuilder.header("Set-Cookie", cookie.toSetCookieString())
        return this
    }

    /// 快捷方法：设置简单的 Cookie（链式调用）
    public func setSimpleCookie(name: String, value: String): TangHttpContext {
        let cookie = Cookie(name, value)
        return this.setCookie(cookie)
    }

    /// 清除指定的 Cookie（链式调用）
    public func clearCookie(name: String): TangHttpContext {
        // 设置过期时间为过去的时间来清除 Cookie
        let cookie = Cookie(name, "", maxAge: Some(0), path: "/")
        this.responseBuilder.header("Set-Cookie", cookie.toSetCookieString())
        return this
    }

    /// 获取所有 Cookies（返回 Map）
    public func cookies(): HashMap<String, String> {
        let map = HashMap<String, String>()
        if (let Some(cookieHeader) <- this.request.headers.getFirst("Cookie")) {
            let cookies = cookieHeader.split("; ")
            for (cookie in cookies) {
                let parts = cookie.split("=")
                if (parts.size >= 1) {
                    let name = parts[0]
                    let value = if (parts.size >= 2) {
                        parts[1]
                    } else {
                        ""
                    }
                    map[name] = value
                }
            }
        }
        return map
    }
}
