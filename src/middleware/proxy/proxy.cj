package tang.middleware.proxy

import std.collection.ArrayList
import std.time.DateTime
import stdx.net.http.Client
import stdx.net.http.ClientBuilder
import stdx.net.http.HttpResponse
import stdx.net.http.HttpRequestBuilder
import stdx.net.http.HttpRequest
import tang.{MiddlewareFunc, TangHttpContext}
import stdx.net.http.HttpStatusCode

/// Proxy 中间件配置选项
public type ProxyOption = (ProxyConfig) -> Unit

/// 后端服务器配置
public class BackendServer {
    var url: String
    var weight: Int32 = 1  // 权重，用于负载均衡

    public init(url: String) {
        this.url = url
    }

    public init(url: String, weight: Int32) {
        this.url = url
        this.weight = weight
    }
}

/// 负载均衡策略
public enum LoadBalanceStrategy {
    | RoundRobin  // 轮询
    | Random      // 随机
    | Weighted    // 加权（未实现）
}

/// Proxy 配置
public class ProxyConfig {
    var backends: ArrayList<BackendServer> = ArrayList<BackendServer>()
    var strategy: LoadBalanceStrategy = LoadBalanceStrategy.RoundRobin
    var timeout: Int64 = 30000  // 超时时间（毫秒）
    var retry: Int32 = 3  // 重试次数
    var stripPrefix: String = ""  // 要移除的 URL 前缀
    var modifyResponse: (TangHttpContext, HttpResponse) -> Unit = { ctx, resp => }

    var currentIndex: Int64 = 0  // 轮询索引
    var client: ?Client = None  // HTTP 客户端

    public init() {}

    /// 添加后端服务器
    public func addBackend(url: String): Unit {
        this.backends.add(BackendServer(url))
    }

    /// 添加带权重的后端服务器
    public func addBackend(url: String, weight: Int32): Unit {
        this.backends.add(BackendServer(url, weight))
    }

    /// 设置后端服务器列表
    public func setBackends(urls: Array<String>): Unit {
        for (url in urls) {
            this.backends.add(BackendServer(url))
        }
    }

    /// 设置负载均衡策略
    public func setStrategy(strategy: LoadBalanceStrategy): Unit {
        this.strategy = strategy
    }

    /// 设置超时时间
    public func setTimeout(milliseconds: Int64): Unit {
        this.timeout = milliseconds
    }

    /// 设置重试次数
    public func setRetry(count: Int32): Unit {
        this.retry = count
    }

    /// 设置要移除的 URL 前缀
    public func setStripPrefix(prefix: String): Unit {
        this.stripPrefix = prefix
    }

    /// 设置响应修改函数
    public func setModifyResponse(handler: (TangHttpContext, HttpResponse) -> Unit): Unit {
        this.modifyResponse = handler
    }

    /// 选择后端服务器
    public func selectBackend(): ?BackendServer {
        if (this.backends.size == 0) {
            return None
        }

        match (this.strategy) {
            case LoadBalanceStrategy.RoundRobin => selectRoundRobin()
            case LoadBalanceStrategy.Random => selectRandom()
            case LoadBalanceStrategy.Weighted => selectWeighted()
        }
    }

    private func selectRoundRobin(): ?BackendServer {
        let backend = this.backends[this.currentIndex]
        this.currentIndex = (this.currentIndex + 1) % this.backends.size
        Some(backend)
    }

    private func selectRandom(): ?BackendServer {
        let index = DateTime.now().toUnixTimeStamp().toSeconds() % this.backends.size
        Some(this.backends[index])
    }

    private func selectWeighted(): ?BackendServer {
        // 简化实现：暂时使用轮询
        selectRoundRobin()
    }

    /// 初始化 HTTP 客户端
    public func initClient(): Unit {
        if (let None <- this.client) {
            let builder = ClientBuilder()
            // TODO: 设置超时等配置
            this.client = Some(builder.build())
        }
    }
}

/// 添加后端服务器
public func withBackend(url: String): ProxyOption {
    return { config => config.addBackend(url) }
}

/// 添加带权重的后端服务器
public func withBackend(url: String, weight: Int32): ProxyOption {
    return { config => config.addBackend(url, weight) }
}

/// 设置后端服务器列表
public func withBackends(urls: Array<String>): ProxyOption {
    return { config => config.setBackends(urls) }
}

/// 设置负载均衡策略
public func withStrategy(strategy: LoadBalanceStrategy): ProxyOption {
    return { config => config.setStrategy(strategy) }
}

/// 设置超时时间
public func withTimeout(milliseconds: Int64): ProxyOption {
    return { config => config.setTimeout(milliseconds) }
}

/// 设置重试次数
public func withRetry(count: Int32): ProxyOption {
    return { config => config.setRetry(count) }
}

/// 设置要移除的 URL 前缀
public func withStripPrefix(prefix: String): ProxyOption {
    return { config => config.setStripPrefix(prefix) }
}

/// 设置响应修改函数
public func withModifyResponse(handler: (TangHttpContext, HttpResponse) -> Unit): ProxyOption {
    return { config => config.setModifyResponse(handler) }
}

/// Proxy 中间件（带配置）
///
/// 反向代理请求到后端服务器
///
/// 工作原理：
/// 1. 选择后端服务器（根据负载均衡策略）
/// 2. 构建目标 URL
/// 3. 转发请求到后端（支持所有 HTTP 方法：GET、POST、PUT、PATCH、DELETE）
/// 4. 转发响应（状态码、Headers、Body）到客户端
///
/// 注意：
/// - **不支持 WebSocket**：此中间件仅支持 HTTP 请求代理
/// - WebSocket Upgrade 请求会返回 426 错误
/// - 如需 WebSocket 代理，请直接连接后端服务器
///
/// 示例：
/// ```cj
/// import tang.middleware.proxy.{proxy, withBackend, withStrategy, LoadBalanceStrategy}
///
/// // 单个后端
/// r.use("/api", proxy([
///     withBackend("http://localhost:8080")
/// ]))
///
/// // 多个后端（负载均衡）
/// r.use("/api", proxy([
///     withBackend("http://localhost:8080"),
///     withBackend("http://localhost:8081"),
///     withBackend("http://localhost:8082"),
///     withStrategy(LoadBalanceStrategy.RoundRobin)
/// ]))
///
/// // 移除前缀
/// r.use("/api", proxy([
///     withBackend("http://backend:3000"),
///     withStripPrefix("/api")  // /api/users -> http://backend:3000/users
/// ]))
/// ```
public func proxy(opts: Array<ProxyOption>): MiddlewareFunc {
    let config = ProxyConfig()
    for (opt in opts) {
        opt(config)
    }

    // 验证配置
    if (config.backends.size == 0) {
        // 没有配置后端，直接传递
        return { next => next }
    }

    // 初始化 HTTP 客户端
    config.initClient()

    return { next =>
        return { ctx: TangHttpContext =>
            // 检测 WebSocket Upgrade 请求
            let upgrade = ctx.request.headers.getFirst("Upgrade")
            match (upgrade) {
                case Some(u) where u == "websocket" =>
                    // WebSocket 不支持，返回友好错误
                    ctx.responseBuilder.status(426u16)  // Upgrade Required
                    ctx.responseBuilder.header("Content-Type", "application/json")
                    ctx.responseBuilder.body("{\"error\":\"WebSocket not supported by HTTP proxy\",\"message\":\"Please connect to backend directly\"}")
                    return
                case _ => ()  // 继续处理 HTTP 请求
            }

            // 选择后端服务器
            match (config.selectBackend()) {
                case Some(backend) =>
                    // 构建目标 URL
                    var path = ctx.path()

                    // 移除前缀
                    if (config.stripPrefix.size > 0 && path.startsWith(config.stripPrefix)) {
                        path = path[config.stripPrefix.size..]
                    }

                    // 确保路径以 / 开头
                    if (path.size > 0 && !path.startsWith("/")) {
                        path = "/" + path
                    }

                    let targetUrl = backend.url + path

                    // 尝试使用 HTTP 客户端转发请求
                    match (config.client) {
                        case Some(client) =>
                            // 1. 构建请求
                            var requestBuilder = HttpRequestBuilder()
                            requestBuilder.method(ctx.method()).url(targetUrl)

                            // 2. 转发请求体
                            let bodyRaw = ctx.bodyRaw()
                            if (bodyRaw.size > 0) {
                                requestBuilder.body(bodyRaw)
                            }

                            // 3. 转发请求头（删除 Connection）
                            for ((name, values) in ctx.request.headers) {
                                if (name != "Connection") {
                                    for (value in values) {
                                        requestBuilder.header(name, value)
                                    }
                                }
                            }

                            // 4. 添加代理 Headers
                            requestBuilder.header("X-Forwarded-Host", ctx.request.headers.getFirst("Host") ?? "unknown")
                            requestBuilder.header("X-Forwarded-Proto", "http")
                            requestBuilder.header("X-Forwarded-Path", ctx.path())

                            // 5. 发送请求
                            let proxyRequest = requestBuilder.build()
                            let response = client.send(proxyRequest)

                            // 6. 转发状态码
                            ctx.responseBuilder.status(response.status)

                            // 7. 转发响应头（删除 Connection）
                            for ((name, values) in response.headers) {
                                if (name != "Connection") {
                                    for (value in values) {
                                        ctx.responseBuilder.header(name, value)
                                    }
                                }
                            }

                            // 8. 转发响应体
                            let bodySize = response.bodySize ?? 1024
                            let bodyBytes = Array<UInt8>(bodySize, repeat: 0)
                            let len = response.body.read(bodyBytes)

                            if (len > 0) {
                                let bodyStr = String.fromUtf8(bodyBytes.slice(0, len))
                                ctx.responseBuilder.body(bodyStr)
                            } else {
                                ctx.responseBuilder.body("")
                            }

                            // 9. 调用自定义响应修改函数
                            config.modifyResponse(ctx, response)
                        case None =>
                            // 客户端未初始化
                            ctx.responseBuilder.status(503u16)
                            ctx.responseBuilder.body("{\"error\":\"HTTP client not initialized\"}")
                    }
                case None =>
                    // 没有可用的后端
                    ctx.responseBuilder.status(503u16)
                    ctx.responseBuilder.body("{\"error\":\"No backend available\"}")
            }
        }
    }
}

/// Proxy 中间件（简化的单后端版本）
public func proxy(targetUrl: String): MiddlewareFunc {
    return proxy([withBackend(targetUrl)])
}

/// Proxy 中间件（默认配置）
public func proxy(): MiddlewareFunc {
    return proxy(Array<ProxyOption>())
}
