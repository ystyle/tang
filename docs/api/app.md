# Tang 应用生命周期

## 概述

从 `1.0.3` 开始，`Tang` 应用类提供完整的生命周期管理能力：优雅停止、shutdown 回调以及底层服务器访问。

**核心 API**：
- `setShutdownCallback()` - 设置关闭回调
- `onShutdown()` - 注册关闭回调
- `stop()` - 优雅停止服务器
- `getStdServer()` - 获取底层 `stdx.net.http.Server`
- `listen(builder)` - 透传 stdx `ServerBuilder` 配置（TLS、超时等）
- `setLogLevel()` - 设置 stdx Server 日志级别（默认 ERROR）
- `mount(prefix, router)` - Fiber 风格子应用挂载

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

## ServerBuilder 配置透传

从 `1.0.4` 开始，`listen(builder)` 支持在构建 stdx `Server` 前定制 `ServerBuilder`，解锁 TLS、超时、协程池、HTTP/2 参数等能力：

```cj
let app = Tang()

app.listen({ sb =>
    sb.tlsConfig(tlsCfg)                    // HTTPS
    sb.readTimeout(5 * Duration.second)     // 超时
    sb.servicePoolConfig(poolCfg)           // 协程池
})
```

- `builder` 在 `build()` 之前调用，可链式配置任意 `ServerBuilder` 方法
- 现有 `listen()` / `listen(port)` / `listen(host, port)` 复用同一逻辑
- 对应的 `listenAsync(builder)` 可异步启动

### 日志级别

stdx Server 默认日志级别为 ERROR（压掉连接噪音日志如 `Socket is closed` / `Broken pipe`）。需要日志时用 `setLogLevel()` 打开：

```cj
let app = Tang().setLogLevel(LogLevel.INFO)
app.listen()
```

`setLogLevel()` 返回 `Tang`，可链式调用。

## 子应用挂载

Fiber 风格的 `app.Mount`，把子应用（Router）的路由以前缀注册到当前应用：

```cj
let app = Tang()
let subApp = Tang()
subApp.get("/users/:id", { ctx => ctx.json(...) })

app.mount("/api", subApp.getRouter())   // 实际路径 /api/users/:id
app.listen()
```

- 子应用中间件原样保留；路径参数照常；快照语义
- 完整说明见 [与 stdx.http 互操作](stdx-interop.md)

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

- **[与 stdx.http 互操作](stdx-interop.md)** - fromStd / register / ComposeDistributor / mount
- **[WebSocket 升级](context/websocket.md)** - WebSocket 双向通信
- **[快速入门](../getting-started.md)** - 完整应用示例
- **[框架概述](../overview.md)** - Tang 的设计理念
