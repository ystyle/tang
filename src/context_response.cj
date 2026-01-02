package tang

import stdx.net.http.{HttpStatusCode, HttpResponseBuilder}

/// Fiber 风格链式 API - 核心响应操作
extend TangHttpContext {
    /// 设置 HTTP 响应状态码（链式调用）
    public func status(code: UInt16): TangHttpContext {
        this.responseBuilder.status(code)
        return this
    }

    /// 设置响应头（链式调用）
    public func set(key: String, value: String): TangHttpContext {
        this.responseBuilder.header(key, value)
        return this
    }

    /// 追加响应头（链式调用）
    public func append(key: String, value: String): TangHttpContext {
        this.responseBuilder.header(key, value)
        return this
    }

    /// 设置 Content-Type 响应头（链式调用）
    public func contentType(contentType: String): TangHttpContext {
        this.responseBuilder.header("Content-Type", contentType)
        return this
    }

    /// 发送状态码响应（终结方法）
    public func sendStatus(code: UInt16): Unit {
        this.responseBuilder.status(code).body("")
    }

    /// 重定向到指定路径（终结方法）
    public func redirect(location: String): Unit {
        this.responseBuilder
            .status(HttpStatusCode.STATUS_FOUND)
            .header("Location", location)
            .body("")
    }

    /// 重定向到指定路径并指定状态码（终结方法）
    public func redirectWithStatus(location: String, code: UInt16): Unit {
        this.responseBuilder
            .status(code)
            .header("Location", location)
            .body("")
    }

    /// 设置附件下载响应头（链式调用）
    public func attachment(filename: String): TangHttpContext {
        this.responseBuilder.header("Content-Disposition", "attachment; filename=\"${filename}\"")
        return this
    }
}
