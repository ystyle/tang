# WebSocket

> **v2.0.0 起**：WebSocket 实现在核心的 `tang.websocket` 包里，**零 stdx**
> （SHA1 与 Base64 各自几十行自实现，只为握手算 accept key）。
> 底层走 tachyon 的 `ctx.hijack`：握手响应由本包直接写 socket，之后连接完全交给 handler。

## 快速开始

```cangjie
import tang.*
import tang.websocket.websocket

main() {
    let app = Tang()

    app.get("/ws", websocket({ conn: WebSocketConn =>
        // 回显：收到什么发回什么
        while (true) {
            match (conn.readMessage()) {
                case Some(msg) => conn.writeText("echo:" + msg.text())
                case None => break      // 对端关闭
            }
        }
    }))

    app.listen(8080u16)
}
```

浏览器端：

```js
const ws = new WebSocket("ws://127.0.0.1:8080/ws")
ws.onmessage = (e) => console.log(e.data)
ws.onopen = () => ws.send("hi")
```

## API

### `websocket(handler: (WebSocketConn) -> Unit): HandlerFunc`

把一条路由声明为 WebSocket 端点。非升级请求会得到 `426 Upgrade Required`；
缺 `Sec-WebSocket-Key` 返回 `400`。

### `WebSocketConn`

| 方法 | 说明 |
|---|---|
| `readMessage(): ?WsMessage` | 读一条完整消息（分片自动拼好）；返回 `None` 表示对端关闭 |
| `writeText(text: String)` | 发文本帧（UTF-8） |
| `writeBinary(data: Array<Byte>)` | 发二进制帧 |
| `ping(payload: Array<Byte>)` | 发 ping |
| `close(code!: UInt16 = 1000, reason!: String = "")` | 发 close 帧 |
| `closeSocket()` | 直接关底层连接 |
| `setReadTimeout(d: Duration)` | 设置读超时 |

### `WsMessage`

| 成员 | 说明 |
|---|---|
| `opcode: WsOpcode` | `Text` / `Binary`（控制帧已在内部处理） |
| `data: Array<Byte>` | 负载 |
| `text(): String` | 按 UTF-8 解成字符串 |

## 自动处理的部分

- **握手**：校验 `Upgrade`/`Sec-WebSocket-Key`，算 `Sec-WebSocket-Accept`，回 `101`
- **分片**：`Continuation` 帧自动拼接，`readMessage` 返回完整消息
- **ping/pong**：收到 ping 自动回 pong；收到 close 回 close 并让 `readMessage` 返回 `None`
- **掩码**：客户端帧自动解掩码；服务端帧按 RFC 不加掩码

## 边界（刻意不做）

| 项 | 原因 |
|---|---|
| `permessage-deflate` 压缩 | 需要 deflate，会把 stdx/三方依赖拉进核心 |
| 子协议协商 | 只有 handler 知道要选哪个；需要时自己读 `Sec-WebSocket-Protocol` 并在握手前判断 |
| 心跳定时器 | 库不该替使用者决定间隔；用 `ping()` + 自己的定时器 |
| TLS（`wss://`） | 与 HTTP 侧一致：TLS 由 LB 终结或走 stdx.net.tls |

## 与 1.0.x 的差异

旧版是 `ctx.upgrade(...)` 方法 + `ws.onMessage(...)` 回调风格，依赖 stdx.net.websocket。
现在改成「handler 拿连接自己循环读写」的形式：更容易表达状态机，也不需要回调注册顺序。

迁移对照见 [MIGRATION.md](../../MIGRATION.md)。
