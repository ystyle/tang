package tang

/// TangHttpContext 的核心扩展
/// 提供请求 ID、CSRF Token、中断控制等常用功能的便捷访问方法
extend TangHttpContext {
    /// 获取当前请求的 ID
    /// 由 requestid 中间件设置，直接存储在 _requestId 字段中（避免使用 HashMap）
    public func requestid(): ?String {
        return this._requestId
    }

    /// 获取 CSRF Token
    /// 由 csrf 中间件设置，直接存储在 _csrfToken 字段中（避免使用 HashMap）
    public func csrfToken(): ?String {
        return this._csrfToken
    }

    /// 中止请求处理链
    /// 调用此方法后，后续的中间件和 handler 将不会被执行
    /// 常用于认证失败、权限不足等场景
    ///
    /// 示例：
    /// ```cj
    /// import stdx.net.http.{HttpStatusCode}
    ///
    /// if (!checkAuth(ctx)) {
    ///     ctx.abortWithStatus(HttpStatusCode.STATUS_UNAUTHORIZED)
    ///     return
    /// }
    /// next(ctx)
    ///
    /// // 或带响应体
    /// ctx.abortWithStatus(500, body: "Internal Server Error")
    /// ```
    public func abortWithStatus(status: UInt16, body!: ?String = None): Unit {
        this.responseBuilder.status(status)
        if (let Some(b) <- body) {
            this.responseBuilder.body(b)
        }
        this.kvSet("__aborted__", true)
    }

    /// 检查请求是否已被中止
    /// 中间件在调用 next 前，应该检查此状态
    public func isAborted(): Bool {
        match (this.kvGet<Bool>("__aborted__")) {
            case Some(v) => v
            case None => false
        }
    }
}
