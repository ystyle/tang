# Favicon - 网站图标处理

## 概述

- **功能**：自动处理 `/favicon.ico` 请求，避免 404 错误
- **分类**：路由与请求控制
- **文件**：`src/middleware/favicon/favicon.cj`

Favicon 中间件自动响应 `/favicon.ico` 请求，返回默认的 1x1 透明 GIF 图标，避免每次请求都返回 404 错误。

> **💡 提示：为什么需要 Favicon 中间件？**
>
> **问题**：
> - 浏览器自动请求 `/favicon.ico`
> - 如果没有 favicon，服务器返回 404
> - 404 错误会被记录到日志（污染日志）
> - 每次访问都有额外的 404 请求
>
> **解决方案**：
> - 使用 Favicon 中间件返回默认图标
> - 减少 404 错误日志
> - 提升用户体验
>
> **生产环境建议**：
> - 使用实际的 favicon.ico 文件（静态文件服务）
> - 或使用 StaticFile 中间件提供自定义 favicon

## 签名

```cj
public func favicon(urlPath: String = "/favicon.ico"): MiddlewareFunc
```

## 快速开始

### 基础用法

```cj
import tang.middleware.favicon.favicon

let r = Router()

// 应用 Favicon 中间件
r.use(favicon())

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

**浏览器请求**：
```bash
curl -i http://localhost:8080/favicon.ico

# 响应：
# HTTP/1.1 200 OK
# Content-Type: image/x-icon
# Cache-Control: public, max-age=86400
# Content-Length: 35
```

### 自定义 URL 路径

```cj
import tang.middleware.favicon.favicon

let r = Router()

// 自定义 favicon 路径
r.use(favicon(urlPath: "/custom/icon.ico"))

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

## 完整示例

### 示例 1：避免 404 错误

```cj
import tang.*
import tang.middleware.favicon.favicon
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())

    // 应用 Favicon 中间件
    r.use(favicon())

    r.get("/", { ctx =>
        ctx.json(HashMap<String, String>([
            ("message", "Hello, World!")
        ]))
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**访问日志对比**：

**不使用 Favicon 中间件**：
```
[INFO] GET / 200 15ms
[INFO] GET /favicon.ico 404 2ms  ← 404 错误
```

**使用 Favicon 中间件**：
```
[INFO] GET / 200 15ms
[INFO] GET /favicon.ico 200 1ms  ← 200 OK
```

### 示例 2：自定义 Favicon（静态文件）

```cj
import tang.middleware.favicon.favicon
import tang.middleware.staticfile.{staticfile, withRoot}

let r = Router()

// 优先使用静态文件服务
r.use(staticfile([
    withRoot("./public")  // ./public/favicon.ico 优先
]))

// 如果静态文件不存在，使用默认 favicon
r.use(favicon())

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("message", "Hello")
        ]))
})
```

**文件结构**：
```
project/
├── public/
│   └── favicon.ico  ← 实际的 favicon 文件
└── src/
    └── main.cj
```

### 示例 3：不同路径不同 Favicon

```cj
import tang.middleware.favicon.favicon

let r = Router()

// 主站：使用默认路径
r.use(favicon())

// 管理后台：自定义路径
let admin = r.group("/admin")
admin.use(favicon(urlPath: "/admin/favicon.ico"))

r.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("page", "home")
        ]))
})

admin.get("/", { ctx =>
    ctx.json(HashMap<String, String>([
            ("page", "admin")
        ]))
})
```

**浏览器请求**：
```bash
# 主站 favicon
curl http://localhost:8080/favicon.ico

# 管理后台 favicon
curl http://localhost:8080/admin/favicon.ico
```

## 工作原理

### 默认 Favicon

中间件返回一个 1x1 透明的 GIF 图标（35 字节）：

```cj
let defaultFavicon = Array<UInt8>(35, { i =>
    [0x47u8, 0x49u8, 0x46u8, 0x38u8, 0x39u8, 0x61u8, 0x01u8, 0x00u8,
     0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x21u8, 0xF9u8, 0x04u8,
     0x01u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x2Cu8, 0x00u8, 0x00u8,
     0x00u8, 0x00u8, 0x01u8, 0x00u8, 0x01u8, 0x00u8, 0x00u8, 0x02u8,
     0x02u8, 0x04u8, 0x01u8, 0x00u8, 0x3Bu8][i]
})
```

### 响应头

```http
HTTP/1.1 200 OK
Content-Type: image/x-icon
Cache-Control: public, max-age=86400
Content-Length: 35
```

**Cache-Control**：浏览器缓存 24 小时，减少重复请求

## 测试

### 测试 Favicon 响应

```bash
# 请求 favicon
curl -i http://localhost:8080/favicon.ico

# 响应：
# HTTP/1.1 200 OK
# Content-Type: image/x-icon
# Cache-Control: public, max-age=86400
# Content-Length: 35
# [35 字节的 GIF 数据]
```

### 测试自定义路径

```bash
# 自定义路径
curl -i http://localhost:8080/custom/icon.ico

# 响应：200 OK
```

## 最佳实践

### 1. 生产环境使用真实 Favicon

```cj
// ❌ 不推荐：生产环境使用默认 1x1 GIF
r.use(favicon())

// ✅ 推荐：使用真实的 favicon.ico
r.use(staticfile([withRoot("./public")]))
```

**为什么**：
- 默认 1x1 GIF 不专业
- 用户浏览器标签页显示空白图标
- SEO 和品牌形象受影响

### 2. Favicon 文件大小

```
推荐：favicon.ico < 50 KB

常见的 favicon 尺寸：
- 16x16（浏览器标签页）
- 32x32（任务栏）
- 96x96（桌面快捷方式）
- 192x192（Android 图标）
- 180x180（iOS 图标）
```

### 3. 缓存策略

```cj
// 当前实现：24 小时缓存
ctx.responseBuilder.header("Cache-Control", "public, max-age=86400")

// 推荐配置：
// - 生产环境：长期缓存（30 天）
// - 开发环境：短缓存或不缓存
```

### 4. HTML 指定 Favicon

```html
<!DOCTYPE html>
<html>
<head>
    <!-- 传统 favicon -->
    <link rel="icon" href="/favicon.ico" sizes="any">

    <!-- PNG favicon（现代浏览器） -->
    <link rel="icon" href="/favicon-32x32.png" sizes="32x32">
    <link rel="icon" href="/favicon-16x16.png" sizes="16x16">

    <!-- Apple Touch Icon -->
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
</head>
<body>
    <h1>My Website</h1>
</body>
</html>
```

## 注意事项

### 1. 中间件顺序

```cj
// ✅ 正确：静态文件优先
r.use(staticfile([withRoot("./public")]))  // 先查找静态文件
r.use(favicon())                            // 静态文件不存在时使用默认

// ❌ 错误：默认 favicon 优先
r.use(favicon())                            // 总是返回默认 favicon
r.use(staticfile([withRoot("./public")]))  // 永远不会执行
```

### 2. 路径匹配

```cj
// 只匹配精确路径
r.use(favicon())  // 只匹配 /favicon.ico

// 不匹配：
// /favicon.png
// /icon.ico
// /static/favicon.ico
```

### 3. 与其他路由冲突

```cj
r.use(favicon())

// ❌ 冲突：不要定义 /favicon.ico 路由
r.get("/favicon.ico", { ctx =>
    ctx.json(HashMap<String, String>([
            ("error", "Conflict")
        ]))
})
// Favicon 中间件会先处理
```

## 常见问题

### 问题 1：浏览器仍然显示空白图标

**原因**：浏览器缓存了旧的 404 响应

**解决**：
1. 清除浏览器缓存
2. 强制刷新（Ctrl+F5 或 Cmd+Shift+R）
3. 使用不同的 favicon URL

```cj
// 添加版本号
r.use(favicon(urlPath: "/favicon.ico?v=2"))
```

### 问题 2：如何使用自定义 Favicon？

**方案 1：静态文件服务**（推荐）
```cj
r.use(staticfile([withRoot("./public")]))
// ./public/favicon.ico
```

**方案 2：自定义处理器**
```cj
r.get("/favicon.ico", { ctx =>
    let iconData = readFaviconFile()  // Array<UInt8>
    ctx.responseBuilder
        .status(200u16)
        .header("Content-Type", "image/x-icon")
        .body(iconData)
})
```

### 问题 3：为什么是 GIF 而不是 ICO？

**当前实现**：1x1 透明 GIF（35 字节）

**原因**：
- GIF 格式简单
- 文件小，响应快
- 对默认图标足够

**生产环境**：应使用实际的 `.ico` 文件（支持多种尺寸）

## 相关链接

- **[StaticFile 中间件](staticfile.md)** - 静态文件服务
- **[源码](../../../src/middleware/favicon/favicon.cj)** - Favicon 源代码
