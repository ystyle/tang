# Cache - 缓存控制

## 概述

- **功能**：设置 Cache-Control 响应头，控制浏览器缓存行为
- **分类**：缓存与优化
- **文件**：`src/middleware/cache/cache.cj`

Cache 中间件用于设置 HTTP 缓存控制策略，通过 `Cache-Control` 响应头告诉浏览器如何缓存资源。

## 签名

```cj
public func cache(): MiddlewareFunc
public func cache(opts: Array<CacheOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withConfig()` | `String` | `"public, max-age=3600"` | Cache-Control 头的值 |
| `withExcludePath()` | `Array<String>` | `[]` | 排除的路径（不设置缓存头） |

## 快速开始

### 基础用法

```cj
import tang.middleware.cache.cache

let r = Router()

// 应用 Cache 中间件
r.use(cache())

r.get("/api/data", { ctx =>
    // 默认：缓存 1 小时，public
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

**响应头**：
```http
Cache-Control: public, max-age=3600
```

### 带配置的用法

```cj
import tang.middleware.cache.{cache, withConfig}

let r = Router()

// 自定义缓存策略
r.use(cache([
    withConfig("public, max-age=86400, s-maxage=7200, stale-while-revalidate=60")
]))
```

## 完整示例

### 示例 1：API 路径级别缓存

```cj
import tang.*
import tang.middleware.cache.{cache, withConfig, withExcludePath}

let r = Router()

// 全局缓存策略
r.use(cache([
    withConfig("public, max-age=3600"),  // 1 小时
    withExcludePath([
        "/api/no-cache/*",  // 不缓存路径
        "/api/dynamic/*"     // 动态内容
    ])
]))

// 静态数据：长时间缓存
r.get("/api/config", { ctx =>
    // Cache-Control: public, max-age=3600
    ctx.json(HashMap<String, String>([
            ("version", "1.0.0")
        ]))
})

// 动态数据：不缓存
r.get("/api/no-cache/data", { ctx =>
    ctx.responseBuilder.header("Cache-Control", "no-store")
    ctx.json(HashMap<String, String>([
            ("timestamp", "${DateTime.now()}")
        ]))
})

// 手动覆盖缓存策略
r.get("/api/override", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "no-cache, no-store, must-revalidate")
        .json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

### 示例 2：不同资源类型不同策略

```cj
import tang.middleware.cache.{cache, withConfig}

let r = Router()

// 公开资源：可缓存
r.get("/public/data", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "public, max-age=86400")  // 1 天
        .json(HashMap<String, String>([
            ("data", "value")
        ]))
})

// 私有资源：需重新验证
r.get("/private/data", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "private, max-age=0, must-revalidate")
        .json(HashMap<String, String>([
            ("user", "data")
        ]))
})

// 动态内容：不缓存
r.get("/dynamic/data", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "no-store, no-cache, must-revalidate")
        .json(HashMap<String, String>([
            ("timestamp", "${DateTime.now()}")
        ]))
})
```

### 示例 3：基于响应状态码缓存

```cj
func smartCache(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            next(ctx)

            // 根据状态码设置缓存策略
            let statusCode = ctx.responseBuilder.statusCode

            if (statusCode >= 200 && statusCode < 300) {
                // 2xx 成功响应：缓存
                ctx.responseBuilder.header("Cache-Control", "public, max-age=3600")
            } else if (statusCode >= 400 && statusCode < 500) {
                // 4xx 客户端错误：短暂缓存
                ctx.responseBuilder.header("Cache-Control", "public, max-age=60")
            } else {
                // 5xx 服务器错误：不缓存
                ctx.responseBuilder.header("Cache-Control", "no-store")
            }
        }
    }
}

let r = Router()
r.use(smartCache())
```

## Cache-Control 指令详解

### 常用指令

| 指令 | 描述 |
|------|------|
| `public` | 响应可以被任何缓存（包括浏览器和 CDN）缓存 |
| `private` | 响应只能被单个用户（浏览器）缓存，不能被 CDN 缓存 |
| `no-cache` | 使用缓存前必须先验证（ETag/Last-Modified） |
| `no-store` | 完全不缓存 |
| `must-revalidate` | 缓存过期后必须向服务器验证 |
| `max-age=<seconds>` | 缓存有效时间（秒） |
| `s-maxage=<seconds>` | 共享缓存（CDN）的最大缓存时间 |

### 示例配置

```cj
// 静态资源：长时间缓存
ctx.responseBuilder.header("Cache-Control", "public, max-age=31536000")  // 1 年

// API 响应：短期缓存
ctx.responseBuilder.header("Cache-Control", "public, max-age=600")  // 10 分钟

// 私有数据：私有缓存
ctx.responseBuilder.header("Cache-Control", "private, max-age=300")  // 5 分钟

// 实时数据：不缓存
ctx.responseBuilder.header("Cache-Control", "no-store, no-cache")
```

## 测试

```bash
# 测试缓存头
curl -I http://localhost:8080/api/data

# 响应头：
# Cache-Control: public, max-age=3600
```

## 注意事项

### 1. 敏感数据不缓存

```cj
// ❌ 错误：敏感数据设置了缓存
r.get("/api/user/profile", { ctx =>
    ctx.responseBuilder.header("Cache-Control", "public, max-age=3600")
    ctx.json(HashMap<String, String>([
            ("userId", "123"),
            ("ssn", "123-45-6789"),
            ("creditCard", "1234567890123456")
        ]))
})

// ✅ 正确：敏感数据不缓存或使用 private
r.get("/api/user/profile", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "private, no-cache, no-store, must-revalidate")
        .json(userData)
})
```

### 2. 动态内容不缓存

```cj
// 包含实时时间戳的响应
r.get("/api/now", { ctx =>
    ctx.responseBuilder
        .header("Cache-Control", "no-store")  // 关键
        .json(HashMap<String, String>([
            ("timestamp", "${DateTime.now()}")
        ]))
})
```

### 3. 与 ETag 配合使用

```cj
import tang.middleware.cache.cache
import tang.middleware.etag.etag

let r = Router()

r.use(etag())
r.use(cache())

r.get("/api/data", { ctx =>
    // ETag 中间件会生成 ETag
    // Cache 中间件会设置缓存策略
    ctx.json(HashMap<String, String>([
            ("data", "value")
        ]))
})
```

## 相关链接

- **[ETag 中间件](etag.md)** - 缓存验证
- **[源码](../../../src/middleware/cache/cache.cj)** - Cache 源代码
