# StaticFile - 静态文件服务

## 概述

- **功能**：提供静态文件服务（HTML、CSS、JS、图片等）
- **分类**：静态文件
- **文件**：`src/middleware/staticfile/static.cj`

StaticFile 处理器提供静态文件服务功能，支持自定义根目录、URL 前缀、目录浏览、索引文件等。

> **💡 提示：StaticFile vs 专用文件服务器**
>
> **StaticFile 中间件**：
> - 适合小型应用、原型开发
> - 内置于 Tang 框架
> - 功能简单，易于配置
>
> **Nginx/Apache**（生产环境推荐）：
> - 性能更好（专门优化）
> - 功能更丰富（缓存、压缩、Range 支持）
> - 更安全（权限控制）
>
> **建议**：
> - 开发环境：使用 StaticFile 中间件
> - 生产环境：使用 Nginx 反向代理 + 静态文件服务

## 签名

```cj
public func staticFiles(root: String, opts: Array<StaticOption>): HandlerFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withPrefix()` | `String` | `"/"` | URL 前缀 |
| `withBrowse()` | - | `false` | 启用目录浏览 |
| `withBufferSize()` | `Int64` | `65536`（64KB） | 缓冲区大小 |
| `withIndexFile()` | `String` | - | 添加默认首页文件 |
| `withIndexFiles()` | `Array<String>` | `["index.html", "index.htm"]` | 批量添加首页文件 |

## 快速开始

### 基础用法

```cj
import tang.middleware.staticfile.{staticFiles}

let r = Router()

// 提供静态文件服务
r.get("/static/*", staticFiles("./public"))

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
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── app.js
└── src/
    └── main.cj
```

**访问**：
```bash
http://localhost:8080/static/index.html
http://localhost:8080/static/css/style.css
http://localhost:8080/static/js/app.js
```

### 使用 URL 前缀

```cj
import tang.middleware.staticfile.{staticFiles, withPrefix}

let r = Router()

// URL 前缀 /assets，文件根目录 ./public
r.get("/assets/*", staticFiles("./public", [
    withPrefix("/assets")
]))
```

**映射关系**：
```
URL: /assets/css/style.css
文件: ./public/css/style.css
```

## 完整示例

### 示例 1：多目录静态文件

```cj
import tang.*
import tang.middleware.staticfile.{staticFiles}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // CSS/JS 文件
    r.get("/assets/*", staticFiles("./public/assets"))

    // 图片文件
    r.get("/images/*", staticFiles("./public/images"))

    // 上传的文件
    r.get("/uploads/*", staticFiles("./uploads"))

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：启用目录浏览

```cj
import tang.middleware.staticfile.{staticFiles, withBrowse}

let r = Router()

// 启用目录浏览
r.get("/files/*", staticFiles("./public/files", [
    withBrowse()  // 允许浏览目录
]))
```

**访问目录**：
```
http://localhost:8080/files/documents/

显示文件列表：
- report1.pdf
- report2.pdf
- ...
```

### 示例 3：自定义首页文件

```cj
import tang.middleware.staticfile.{staticFiles, withIndexFiles}

let r = Router()

r.get("/static/*", staticFiles("./public", [
    withIndexFiles([
        "index.html",
        "index.htm",
        "default.html",
        "home.html"
    ])
]))
```

**首页查找顺序**：
1. `index.html`
2. `index.htm`
3. `default.html`
4. `home.html`

### 示例 4：完整前端应用

```cj
import tang.*
import tang.middleware.staticfile.{staticFiles, withPrefix}
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    // API 路由
    let api = r.group("/api")
    api.get("/data", { ctx =>
        ctx.json(HashMap<String, String>([
            ("data", "API response")
        ]))
    })

    // 静态文件（SPA 应用）
    r.get("/*", staticFiles("./dist", [
        withPrefix("/")
    ]))

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

**部署 React/Vue 应用**：
```bash
# 构建前端应用
cd frontend
npm run build

# 将 dist 目录复制到项目
cp -r dist ../

# 文件结构：
# project/
# ├── dist/
# │   ├── index.html
# │   ├── assets/
# │   │   ├── index.js
# │   │   └── index.css
# └── src/
#     └── main.cj
```

## 注意事项

### 1. 路径安全

```cj
// ❌ 危险：不要将敏感目录暴露
r.get("/static/*", staticFiles("./"))  // 暴露整个文件系统！

// ✅ 正确：只暴露 public 目录
r.get("/static/*", staticFiles("./public"))
```

### 2. 文件大小

大文件建议使用 CDN 或专用文件服务器：

```cj
// ❌ 不推荐：使用 StaticFile 服务大文件
r.get("/downloads/*", staticFiles("./large-files"))  // 视频文件

// ✅ 推荐：使用 CDN 或 Nginx
// https://cdn.example.com/videos/file.mp4
```

### 3. 性能优化

生产环境建议使用 Nginx：

```nginx
location /static/ {
    alias /path/to/public/;
    expires 1y;
    add_header Cache-Control "public, immutable";

    # Gzip 压缩
    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
}
```

### 4. MIME 类型

StaticFile 会自动根据文件扩展名设置 Content-Type。

## 相关链接

- **[源码](../../../src/middleware/staticfile/static.cj)** - StaticFile 源代码
