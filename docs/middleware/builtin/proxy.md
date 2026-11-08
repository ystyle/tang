# Proxy - 反向代理

> **本分支实现**：使用 core 自带的极简 HTTP 客户端（`tang.http`）转发，**零 stdx**。
> 上游协议只支持 `http://`；TLS 上游需要 stdx.net.tls（可另做扩展成员）。
> WebSocket 升级请求会明确返回 426，而不是静默降级。

## 快速开始

```cj
import tang.*
import tang.middleware.proxy.*

let app = Tang()
let g = app.group("/api")
g.use([proxy([
    withBackend("http://127.0.0.1:8080"),
    withBackend("http://127.0.0.1:8081"),
    withStrategy(LoadBalanceStrategy.RoundRobin),
    withStripPrefix("/api"),
    withTimeout(3000),
    withRetry(1)
])])
g.all("/*", { ctx => })   // 路由只作为中间件链的挂载点，proxy 命中后不会调用它
app.listen(8080u16)
```

## 配置项

| 选项 | 说明 |
|---|---|
| `withBackend(url)` / `withBackend(url, weight)` | 添加后端（weight 目前只记录，未参与选择） |
| `withBackends([url...])` | 批量添加 |
| `withStrategy(RoundRobin|Random)` | 负载均衡策略（默认 RoundRobin，原子计数无锁） |
| `withStripPrefix("/api")` | 转发前剥离路径前缀 |
| `withTimeout(ms)` | 上游读写超时（默认 30000） |
| `withRetry(n)` | 失败重试次数（会换后端，默认 2） |
| `withModifyResponse(fn)` | 写回客户端前的响应钩子 |
| `withRequestHeader(k, v)` | 额外转发头 |

## 转发行为

- **请求**：方法、路径（可选剥离前缀）+ query、body 原样转发；逐跳头（Connection/Keep-Alive/TE/Transfer-Encoding/Upgrade 等）不转发，Content-Length 由客户端按实际 body 计算
- **注入头**：`X-Forwarded-Host` / `X-Forwarded-Proto` / `X-Forwarded-Path`
- **响应**：状态码、除逐跳头外的响应头、body 透传
- **失败**：重试用尽后返回 `502`，body 里带最后一次错误
- **无后端**：`proxy()` 直接透传给下一个 handler（便于配置里临时关闭代理）

## 与 Go/Fiber 的差异

| 项 | 说明 |
|---|---|
| WebSocket | 不支持（返回 426）；需要时让客户端直连后端，或等 tachyon 提供双工转发 |
| 连接复用 | 每次请求新建上游连接（`Connection: close`），简单可靠；高 QPS 场景可后续加连接池 |
| 压缩/重写 | 不自动处理，用 `withModifyResponse` 自行改 |

## 已知限制

- 上游必须是 `http://`（无 TLS）
- 不支持 HTTP/2（与 tachyon 一致）
- 流式响应（chunked 上游）会被完整读入内存后再写回；超大响应需谨慎
