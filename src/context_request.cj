package tang

import stdx.net.http.Protocol
import std.convert.Parsable

/// Fiber 风格链式 API - 请求信息增强
extend TangHttpContext {
    /// 获取 HTTP 请求方法（返回字符串，如 "GET", "POST"）
    public func method(): String {
        return this.request.method.toString()
    }

    /// 获取请求路径
    public func path(): String {
        if (this.request.url.rawPath.isEmpty()) {
            return this.request.url.path
        } else {
            return this.request.url.rawPath
        }
    }

    /// 获取协议版本（返回仓颉原生 Protocol 枚举）
    public func protocolVersion(): Protocol {
        return this.request.version
    }

    /// 获取端口号
    public func port(): UInt16 {
        let portStr = this.request.url.port
        if (let Some(p) <- UInt16.tryParse(portStr)) {
            return p
        }
        // 根据协议返回默认端口
        return if (this.request.url.scheme == "https") {
            443u16
        } else {
            80u16
        }
    }

    /// 检查请求是否是指定的内容类型
    public func isType(contentType: String): Bool {
        if (let Some(ct) <- this.contentType()) {
            return ct.contains(contentType)
        }
        return false
    }

    /// 检查请求是否是指定的内容类型（is 的别名）
    public func `is`(contentType: String): Bool {
        return this.isType(contentType)
    }

    /// 检查是否是 HTTPS 请求
    public func secure(): Bool {
        return this.request.url.scheme == "https"
    }

    /// 获取完整的原始 URL
    public func originalURL(): String {
        return "${this.request.url.scheme}://${this.request.url.host}${this.request.url.path}"
    }
}
