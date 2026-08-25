# Tang 应用生命周期

## 概述

从 `1.0.3` 开始，`Tang` 应用类提供完整的生命周期管理能力：优雅停止、shutdown 回调以及底层服务器访问。

**核心 API**：
- `setShutdownCallback()` - 设置关闭回调
- `onShutdown()` - 注册关闭回调
- `stop()` - 优雅停止服务器
- `getStdServer()` - 获取底层 `stdx.net.http.Server`
- `getHttpContext()` - 上下文级：获取底层 `HttpContext`

## 优雅停止

使用 `stop()` 优雅停止服务器（等待已处理的请求完成后再关闭）：

```cj
let app = Tang().listenAsync(8080)

// 其他逻辑...
app.stop()  // 优雅停止
```

### 注意事项

- `stop()` 使用 `closeGracefully()` 关闭服务器，已到达的请求会处理完成
- 未启动服务器时调用 `stop()` 不会报错（自动跳过）

## 关闭回调

### 设置关闭回调

在 `listen()` 之前通过 `setShutdownCallback()` 设置，服务器关闭时自动执行：

```cj
let app = Tang()
    .setShutdownCallback({ =>
        println("服务器已关闭，清理资源")
        // 关闭连接池、保存状态等
    })

app.listen(8080)
```

### 运行时注册回调

服务器已启动后使用 `onShutdown()` 注册：

```cj
let app = Tang().listenAsync(8080)

app.onShutdown({ =>
    println("shutdown 回调已注册")
})
```

### 设置与注册的区别

| 方法 | 时机 | 说明 |
|------|------|------|
| `setShutdownCallback()` | `listen()` 之前 | 应用配置阶段，链式调用 |
| `onShutdown()` | 任意时机 | 直接注册到底层 Server |

## 获取底层服务器

使用 `getStdServer()` 获取底层 `stdx.net.http.Server`，访问高级能力：

```cj
let app = Tang().listenAsync(8080)

if (let Some(server) <- app.getStdServer()) {
    // 访问底层服务器配置
    let addr = server.addr
    println("监听地址: ${addr}")
}
```

> **提示**：`getStdServer()` 返回 `?Server`（Option 类型），服务器未启动时返回 `None`。

## 完整示例

```cj
let app = Tang()
    .setHost("0.0.0.0")
    .setPort(8080)
    .setShutdownCallback({ =>
        println("应用关闭，清理连接池")
    })
    .get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Hello Tang!")
        ]))
    })

app.listenAsync()

// 任意时刻优雅停止
app.stop()
```

## 相关链接

- **[WebSocket 升级](context/websocket.md)** - WebSocket 双向通信
- **[快速入门](../getting-started.md)** - 完整应用示例
- **[框架概述](../overview.md)** - Tang 的设计理念
