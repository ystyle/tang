# Tang 中间件测试指南

本文档提供了新实现的4个中间件（KeyAuth、Rewrite、Cache、ETag）的详细测试说明。

## 📋 已实现的中间件

| 中间件 | 文件 | 功能描述 |
|--------|------|----------|
| **KeyAuth** | `src/middleware/keyauth/keyauth.cj` | API 密钥认证，支持从 header/query/cookie 读取 |
| **Rewrite** | `src/middleware/rewrite/rewrite.cj` | URL 重写，支持正则表达式 |
| **Cache** | `src/middleware/cache/cache.cj` | HTTP 缓存控制头（Cache-Control） |
| **ETag** | `src/middleware/etag/etag.cj` | ETag 缓存验证（基于路径生成） |

---

## 🚀 启动测试服务器

```bash
cd /home/ystyle/Code/CangJie/online/tang/examples/middleware_showcase
cjpm run
```

服务器将在 `http://localhost:10001` 启动。

---

## 🔐 KeyAuth 中间件测试

### 功能说明
基于 API Key 进行身份验证，支持从以下位置读取密钥：
- HTTP Header（如 `X-API-Key`）
- Query 参数（如 `?api_key=xxx`）
- Cookie（如 `api_key=xxx`）

### 测试端点

#### 1. 公开端点（无需认证）
```bash
curl http://localhost:10001/test/keyauth
```

**预期结果**：返回成功响应，说明无需认证

#### 2. 受保护端点（无密钥）
```bash
curl http://localhost:10001/test/keyauth/protected
```

**预期结果**：返回 `401 Unauthorized`

#### 3. 受保护端点（有效密钥）
```bash
curl -H "X-API-Key: test-secret-key-12345" http://localhost:10001/test/keyauth/protected
```

**预期结果**：返回成功响应，包含认证信息

---

## 🔄 Rewrite 中间件测试

### 功能说明
URL 重写，支持正则表达式匹配和替换。服务器端重写，浏览器地址栏不会改变。

### 测试端点

#### 1. 旧 API 路径重写
```bash
curl http://localhost:10001/old/api/data
```

**说明**：请求 `/old/api/data` 会被重写为 `/api/data`

**预期结果**：
```json
{
  "message": "URL was rewritten from /old/api/data to /api/data",
  "original": "/old/api/data",
  "current": "/api/data",
  "middleware": "Rewrite is working!"
}
```

#### 2. API 版本升级重写
```bash
curl http://localhost:10001/api/v1/users
```

**说明**：`/api/v1/*` 会被重写为 `/api/v2/*`

**预期结果**：
```json
{
  "users": "[]",
  "note": "This endpoint can be accessed via /api/v1/users (rewritten to /api/v2/users)"
}
```

---

## 💾 Cache 中间件测试

### 功能说明
设置 HTTP 缓存控制头（`Cache-Control`），控制客户端缓存行为。

### 配置规则
- 默认：缓存 1 小时（`max-age=3600`）
- `/api/*`：不缓存（`max-age=0`）
- `/static/*`：缓存 1 天（`max-age=86400`）

### 测试端点

#### 1. 缓存端点
```bash
curl -I http://localhost:10001/test/cache
```

**预期响应头**：
```
Cache-Control: max-age=3600, public
```

#### 2. 不缓存端点
```bash
curl -I http://localhost:10001/test/nocache
```

**预期响应头**：
```
Cache-Control: no-store, no-cache, must-revalidate
```

#### 3. API 路径（不缓存规则）
```bash
curl -I http://localhost:10001/api/test-cache
```

**预期响应头**：
```
Cache-Control: max-age=0, no-cache, no-store, must-revalidate
```

---

## 🏷️ ETag 中间件测试

### 功能说明
自动生成 ETag 响应头，基于请求路径和查询参数生成哈希值（使用 SHA256 或 MD5）。

### 配置选项
- 默认：使用 SHA256 哈希
- 可选：使用 MD5（更快，但安全性较低）
- 可选：使用弱 ETag（`W/` 前缀）

### 测试端点

```bash
curl -I http://localhost:10001/test/etag
```

**预期响应头**：
```
ETag: "abc123..."
```

**说明**：相同的请求路径和查询参数会生成相同的 ETag

---

## 🧪 快速测试脚本

项目根目录提供了自动化测试脚本：

```bash
cd /home/ystyle/Code/CangJie/online/tang
./test_middlewares.sh
```

该脚本会自动测试所有4个中间件，并输出测试结果。

---

## 📝 中间件使用示例

### KeyAuth 示例

```cj
import tang.middleware.keyauth.{keyAuth, withKey, withLookup}

// 方式1：使用单个密钥
app.use(keyAuth([withKey("your-secret-key")]))

// 方式2：从特定位置获取密钥
app.use(keyAuth([
    withKey("secret-key"),
    withLookup("header:X-API-Key")  // 从 header 获取
]))

// 方式3：使用自定义验证器
app.use(keyAuth([
    withValidator({ key =>
        key.startsWith("valid-") && key.size > 10
    })
]))
```

### Rewrite 示例

```cj
import tang.middleware.rewrite.{rewrite, withRewriteRule}

// 单个规则
app.use(rewrite("/api/v1/(.*)", "/api/v2/$1"))

// 多个规则
app.use(rewrite([
    withRewriteRule("/old/(.*)", "/new/$1"),
    withRewriteRule("/api/v1/(.*)", "/api/v2/$1")
]))
```

### Cache 示例

```cj
import tang.middleware.cache.{cache, withDuration, CacheRule}

// 简单配置：所有响应缓存1小时
app.use(cache([withDuration(3600)]))

// 高级配置：不同路径不同策略
app.use(cache([
    withDuration(3600),  // 默认1小时
    withRules([
        CacheRule("/api/*", 0),         // API 不缓存
        CacheRule("/static/*", 86400),   // 静态文件缓存1天
        CacheRule("/images/*", 604800)   // 图片缓存1周
    ])
]))
```

### ETag 示例

```cj
import tang.middleware.etag.{etag, withMD5, withWeak}

// 默认配置（SHA256）
app.use(etag())

// 使用 MD5（更快）
app.use(etag([withMD5()]))

// 使用弱 ETag（适用于动态内容）
app.use(etag([withWeak()]))

// 排除某些路径
app.use(etag([
    withExcludePaths(["/api/", "/upload/"])
]))
```

---

## 🎯 中间件执行顺序

中间件的执行顺序非常重要，建议按以下顺序配置：

1. **Recovery** - 异常恢复（最外层）
2. **AccessLog** - 访问日志
3. **RequestID** - 请求追踪
4. **RateLimit** - 限流保护
5. **BodyLimit** - 请求体大小限制
6. **KeyAuth** - 身份认证（仅特定路由）
7. **CORS** - 跨域支持
8. **Security** - 安全头
9. **Rewrite** - URL 重写（仅特定路由）
10. **Cache** - 缓存控制
11. **ETag** - ETag 验证
12. **Timeout** - 超时控制

---

## ⚠️ 注意事项

### KeyAuth
- 不建议全局应用，应在需要认证的路由组上使用
- 密钥应通过环境变量或配置文件管理，不应硬编码

### Rewrite
- URL 重写在服务器端进行，浏览器地址栏不会改变
- 重写规则按顺序匹配，注意规则顺序

### Cache
- 仅设置响应头，不实际缓存内容
- API 路径默认不缓存（安全考虑）

### ETag
- 当前实现基于路径生成，不是基于响应内容
- 对于动态内容，建议使用弱 ETag

---

## 🔗 相关文档

- [fiber_api_comparison.md](./fiber_api_comparison.md) - Fiber Context API 对比
- [MIDDLEWARE_ROADMAP.md](./MIDDLEWARE_ROADMAP.md) - 中间件开发路线图
- [CLAUDE.md](./CLAUDE.md) - 仓颉语言语法参考
