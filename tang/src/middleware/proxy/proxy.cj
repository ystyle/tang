package tang.middleware.proxy

import std.collection.ArrayList
import std.sync.AtomicInt64
import std.time.DateTime
import tang.{MiddlewareFunc, HandlerFunc, TangHttpContext}
import tang.http.{HttpClient, ClientResponse}

/// Proxy 配置选项
public type ProxyOption = (ProxyConfig) -> Unit

/// 后端服务器配置
public class BackendServer {
    var url: String
    var weight: Int32 = 1

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
    | RoundRobin
    | Random
}

/// Proxy 配置
public class ProxyConfig {
    var backends: ArrayList<BackendServer> = ArrayList<BackendServer>()
    var strategy: LoadBalanceStrategy = LoadBalanceStrategy.RoundRobin
    var timeout: Int64 = 30000
    var retry: Int32 = 2
    var stripPrefix: String = ""
    var modifyResponse: ?(TangHttpContext, ClientResponse) -> Unit = None
    /// 转发时额外加的请求头（X-Forwarded-* 由中间件自动补齐）
    var extraRequestHeaders: ArrayList<(String, String)> = ArrayList<(String, String)>()

    init() {}

    public func addBackend(url: String): Unit {
        this.backends.add(BackendServer(url))
    }

    public func addBackend(url: String, weight: Int32): Unit {
        this.backends.add(BackendServer(url, weight))
    }

    public func setBackends(urls: Array<String>): Unit {
        for (url in urls) {
            this.backends.add(BackendServer(url))
        }
    }

    public func setStrategy(strategy: LoadBalanceStrategy): Unit {
        this.strategy = strategy
    }

    public func setTimeout(milliseconds: Int64): Unit {
        this.timeout = milliseconds
    }

    public func setRetry(count: Int32): Unit {
        this.retry = count
    }

    public func setStripPrefix(prefix: String): Unit {
        this.stripPrefix = prefix
    }

    public func setModifyResponse(handler: (TangHttpContext, ClientResponse) -> Unit): Unit {
        this.modifyResponse = Some(handler)
    }

    public func addRequestHeader(name: String, value: String): Unit {
        this.extraRequestHeaders.add((name, value))
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

/// 设置后端列表
public func withBackends(urls: Array<String>): ProxyOption {
    return { config => config.setBackends(urls) }
}

/// 设置负载均衡策略
public func withStrategy(strategy: LoadBalanceStrategy): ProxyOption {
    return { config => config.setStrategy(strategy) }
}

/// 设置上游超时（毫秒）
public func withTimeout(milliseconds: Int64): ProxyOption {
    return { config => config.setTimeout(milliseconds) }
}

/// 设置失败重试次数（不含首次请求）
public func withRetry(count: Int32): ProxyOption {
    return { config => config.setRetry(count) }
}

/// 设置要剥离的路径前缀
public func withStripPrefix(prefix: String): ProxyOption {
    return { config => config.setStripPrefix(prefix) }
}

/// 设置响应修改钩子（在写回客户端之前）
public func withModifyResponse(handler: (TangHttpContext, ClientResponse) -> Unit): ProxyOption {
    return { config => config.setModifyResponse(handler) }
}

/// 额外转发请求头
public func withRequestHeader(name: String, value: String): ProxyOption {
    return { config => config.addRequestHeader(name, value) }
}

/// 逐跳头：不能原样转发（RFC 7230 §6.1）
func isHopByHop(name: String): Bool {
    let n = name.toAsciiLower()
    if (n == "connection" || n == "keep-alive" || n == "proxy-authenticate" ||
        n == "proxy-authorization" || n == "te" || n == "trailers" ||
        n == "transfer-encoding" || n == "upgrade") {
        return true
    }
    if (n == "content-length") {
        // 请求体可能被重写，长度交给客户端按实际 body 计算
        return true
    }
    return false
}

/// 反向代理中间件
///
/// 用 core 自带的极简 HTTP 客户端转发（零 stdx），支持：
/// - 多后端 + 轮询/随机
/// - 失败重试（换后端重试）
/// - 路径前缀剥离
/// - X-Forwarded-For / Host / Proto / Path 注入
/// - 响应修改钩子
///
/// 不支持：WebSocket 升级（返回 426）、TLS 上游（需要 stdx.net.tls，可用扩展成员补）。
public func proxy(opts: Array<ProxyOption>): MiddlewareFunc {
    let config = ProxyConfig()
    for (opt in opts) {
        opt(config)
    }
    let client = HttpClient(timeoutMs: config.timeout)
    let counter = AtomicInt64(0)

    return { next =>
        return { ctx: TangHttpContext =>
            if (config.backends.size == 0) {
                next(ctx)
                return
            }
            // WebSocket 升级需要双工转发，这里明确拒绝而不是静默转成普通 HTTP
            if (let Some(u) <- ctx.request.headers.getFirst("Upgrade")) {
                if (u.toAsciiLower() == "websocket") {
                    ctx.responseBuilder.status(426u16)
                    ctx.responseBuilder.header("Content-Type", "application/json")
                    ctx.responseBuilder.body("{\"error\":\"WebSocket upgrade is not supported by proxy middleware\"}")
                    return
                }
            }

            var path = ctx.path()
            if (!config.stripPrefix.isEmpty() && path.startsWith(config.stripPrefix)) {
                path = path[config.stripPrefix.size..]
            }
            if (path.isEmpty() || !path.startsWith("/")) {
                path = "/" + path
            }
            let query = ctx.request.url.query
            let targetPath = if (query.isEmpty()) { path } else { path + "?" + query }
            let body = ctx.raw.body().toArray()

            let attempts: Int64 = if (config.retry < 0) { 1 } else { Int64(config.retry) + 1 }
            var lastError = ""
            var i = 0
            while (i < attempts) {
                let backend = selectBackend(config, counter)
                i += 1
                let resp = try {
                    sendToBackend(client, config, ctx, backend, targetPath, body)
                } catch (e: Exception) {
                    lastError = e.toString()
                    continue
                }
                // 写回客户端
                ctx.responseBuilder.status(resp.status)
                for ((name, value) in resp.headers) {
                    if (isHopByHop(name)) {
                        continue
                    }
                    ctx.responseBuilder.header(name, value)
                }
                match (config.modifyResponse) {
                    case Some(h) => h(ctx, resp)
                    case None => ()
                }
                ctx.responseBuilder.body(resp.body)
                return
            }
            ctx.responseBuilder.status(502u16)
            ctx.responseBuilder.body("502 Bad Gateway: " + lastError)
        }
    }
}

/// 便利重载：单后端
public func proxy(targetUrl: String): MiddlewareFunc {
    return proxy([withBackend(targetUrl)])
}

/// 便利重载：无后端（直接透传，便于配置里临时关闭）
public func proxy(): MiddlewareFunc {
    return { next => next }
}

func selectBackend(config: ProxyConfig, counter: AtomicInt64): BackendServer {
    match (config.strategy) {
        case LoadBalanceStrategy.Random =>
            // 用毫秒时间戳 + 计数器做廉价伪随机（真正的随机源要 std.random，够用即可）
            let seed = DateTime.now().toUnixTimeStamp().toMilliseconds() + counter.fetchAdd(1)
            let idx = seed % config.backends.size
            return config.backends[idx]
        case LoadBalanceStrategy.RoundRobin =>
            let idx = counter.fetchAdd(1)
            return config.backends[idx % config.backends.size]
    }
}

func sendToBackend(client: HttpClient, config: ProxyConfig, ctx: TangHttpContext,
                   backend: BackendServer, targetPath: String, body: Array<Byte>): ClientResponse {
    let headers = ArrayList<(String, String)>()
    ctx.request.headers.forEach({ name, value =>
        if (!isHopByHop(name)) {
            headers.add((name, value))
        }
    })
    // 注入转发头
    let host = match (ctx.request.headers.getFirst("Host")) {
        case Some(v) => v
        case None => "unknown"
    }
    headers.add(("X-Forwarded-Host", host))
    headers.add(("X-Forwarded-Proto", "http"))
    headers.add(("X-Forwarded-Path", ctx.path()))
    for (h in config.extraRequestHeaders) {
        headers.add(h)
    }
    let url = backend.url + targetPath
    return client.send(ctx.request.method, url, headers, body)
}
