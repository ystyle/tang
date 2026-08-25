# WebSocket 升级

## 概述

从 `1.0.3` 开始，Tang 支持通过 `TangHttpContext.upgrade()` 将 HTTP 请求升级为 WebSocket 连接，实现服务端主动推送、实时聊天等双向通信场景。

**核心 API**：
- `upgrade()` - 升级为 WebSocket 连接
- `getHttpContext()` - 获取底层 `HttpContext`（高级操作）

## 升级连接

使用 `upgrade()` 将当前请求升级为 WebSocket：

```cj
r.get("/ws", { ctx =>
    let ws = ctx.upgrade(
        subProtocols: ArrayList<String>(["chat"]),  // 可选子协议
        origins: ArrayList<String>(["https://example.com"]),  // 可选来源白名单
        headersFunc: { ctx =>  // 自定义响应头
            let headers = HttpHeaders()
            headers["X-Powered-By"] = "tang"
            headers
        }
    )

    ws.onMessage({ _ => 
        // 处理客户端消息
        ()
    })

    ws.send("hello")
})
```

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `subProtocols` | `ArrayList<String>` | WebSocket 子协议列表，如 `["chat"]`、`["superchat"]` |
| `origins` | `ArrayList<String>` | 允许的来源白名单，用于跨域校验 |
| `headersFunc` | `(TangHttpContext) -> HttpHeaders` | 自定义握手响应头，接收当前 `TangHttpContext` 并返回 `HttpHeaders` |

### WebSocket 发送消息

升级成功后返回 `WebSocket` 实例，可以直接发送消息：

```cj
ws.send("text message")           // 发送文本
ws.send(ByteArray([...]))         // 发送二进制
```

### 接收消息

使用 `onMessage` 注册消息回调：

```cj
ws.onMessage({ msg =>
    println("收到客户端消息: ${msg}")
})
```

### 关闭连接

```cj
ws.close()
```

## 获取底层上下文

需要访问底层的 `stdx.net.http.HttpContext`（如获取 socket 信息、执行高级操作）时，使用 `getHttpContext()`：

```cj
r.get("/debug", { ctx =>
    let raw = ctx.getHttpContext()
    // raw 是 stdx HttpContext，可访问底层能力
    ctx.json(HashMap<String, String>([
        ("method", raw.request.method)
    ]))
})
```

## 应用级 WebSocket 示例

配合 `Tang` 应用类完整示例：

```cj
let app = Tang()
    .get("/ws", { ctx =>
        let ws = ctx.upgrade()
        ws.onMessage({ msg =>
            // echo 消息
            ws.send(msg)
        })
    })
    .setShutdownCallback({ => 
        println("服务器关闭前清理资源")
    })

app.listen(8080)
```

## 相关链接

- **[辅助方法](utils.md)** - TangHttpContext 其他辅助方法
- **[应用生命周期](../app.md)** - shutdown 回调与优雅停止
- **[快速入门](../../getting-started.md)** - 完整应用示例
