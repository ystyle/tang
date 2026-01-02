# Security - 安全响应头

## 概述

- **功能**：设置安全相关的 HTTP 响应头
- **分类**：安全类
- **文件**：`src/middleware/security/security.cj`

Security 中间件用于设置各种安全相关的 HTTP 响应头，帮助保护应用免受常见的安全威胁，如 XSS、点击劫持、MIME 类型嗅探等。类似于 Node.js 的 Helmet。

## 签名

```cj
public func security(): MiddlewareFunc
public func security(opts: Array<SecurityOption>): MiddlewareFunc
```

## 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `withXSSProtection()` | `String` | `"1; mode=block"` | XSS 保护 |
| `withContentTypeNosniff()` | `Bool` | `true` | 禁止 MIME 类型嗅探 |
| `withXFrameOptions()` | `String` | `"DENY"` | 防止点击劫持 |
| `withHSTSMaxAge()` | `Int64` | `31536000` | HSTS 最大时间（秒） |
| `withHSTSSubdomains()` | `Bool` | `true` | HSTS 包含子域名 |
| `withHSTSPreload()` | `Bool` | `false` | HSTS 预加载 |
| `withCSP()` | `String` | `""` | 内容安全策略 |

## 快速开始

### 基础用法（使用默认配置）

```cj
import tang.middleware.security.security

let r = Router()

// 应用 Security 中间件
r.use(security())

r.get("/", { ctx =>
    ctx.writeString("Hello, Secure World!")
})
```

**响应头**：
```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### 带配置的用法

```cj
import tang.middleware.security.{security, withXSSProtection, withHSTSMaxAge}

let r = Router()

r.use(security([
    withXSSProtection("1; mode=block"),
    withHSTSMaxAge(31536000),  // 1 年
    withHSTSSubdomains(true),
    withHSTSPreload(false)
]))
```

## 完整示例

### 示例 1：生产环境推荐配置

```cj
import tang.*
import tang.middleware.security.{security, withXSSProtection, withHSTSMaxAge, withHSTSSubdomains}
import tang.middleware.log.logger
import stdx.net.http.ServerBuilder

main() {
    let r = Router()

    r.use(logger())
    r.use(security([
        // XSS 保护
        withXSSProtection("1; mode=block"),

        // 禁止 MIME 类型嗅探
        withContentTypeNosniff(true),

        // 防止点击劫持
        withXFrameOptions("DENY"),

        // HSTS（仅 HTTPS）
        withHSTSMaxAge(31536000),      // 1 年
        withHSTSSubdomains(true),       // 包含子域名
        withHSTSPreload(false),         // 不预加载（需要先测试）

        // 内容安全策略
        withCSP("default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'")
    ]))

    r.get("/", { ctx =>
        ctx.writeString("Hello, Secure World!")
    })

    let server = ServerBuilder()
        .distributor(r)
        .port(8080)
        .build()

    server.serve()
}
```

### 示例 2：允许 iframe 嵌入

```cj
import tang.middleware.security.{security, withXFrameOptions}

let r = Router()

// 允许来自同源的 iframe
r.use(security([
    withXFrameOptions("SAMEORIGIN")  // 允许同源嵌入
]))

r.get("/embeddable", { ctx =>
    ctx.writeString("This page can be embedded in iframe")
})
```

### 示例 3：自定义 CSP

```cj
import tang.middleware.security.{security, withCSP}

let r = Router()

r.use(security([
    withCSP(
        "default-src 'self'; " +
        "script-src 'self' https://cdn.example.com; " +
        "style-src 'self' 'unsafe-inline'; " +
        "img-src 'self' data: https:; " +
        "font-src 'self' https://fonts.gstatic.com; " +
        "connect-src 'self' https://api.example.com; " +
        "frame-ancestors 'none'; " +
        "base-uri 'self'; " +
        "form-action 'self';"
    )
]))

r.get("/", { ctx =>
    ctx.writeString("Page with strict CSP")
})
```

### 示例 4：开发环境 vs 生产环境

```cj
import std.env.Env
import tang.middleware.security.security

func getSecurity(): MiddlewareFunc {
    let env = Env.get("ENV") ?? "development"

    if (env == "production") {
        // 生产环境：严格的安全头
        return security([
            withXSSProtection("1; mode=block"),
            withContentTypeNosniff(true),
            withXFrameOptions("DENY"),
            withHSTSMaxAge(31536000),  // 1 年
            withHSTSSubdomains(true),
            withHSTSPreload(true),  // 生产环境可以预加载
            withCSP("default-src 'self'; script-src 'self'")
        ])
    } else {
        // 开发环境：较宽松的配置
        return security([
            withXSSProtection("1; mode=block"),
            withContentTypeNosniff(true),
            withXFrameOptions("SAMEORIGIN"),
            // 开发环境不启用 HSTS（HTTP 开发环境）
            withCSP("default-src 'self' 'unsafe-inline' 'unsafe-eval'")
        ])
    }
}

let r = Router()
r.use(getSecurity())
```

### 示例 5：结合 HTTPS 强制

```cj
import tang.middleware.security.{security, withHSTSMaxAge, withHSTSSubdomains, withHSTSPreload}

func enforceHTTPS(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            // 如果不是 HTTPS，重定向
            if (!ctx.secure()) {
                let httpsURL = "https://${ctx.hostName()}${ctx.path()}"
                ctx.redirectWithStatus(httpsURL, 301u16)
                return
            }

            next(ctx)
        }
    }
}

let r = Router()

// 强制 HTTPS + 安全头
r.use(enforceHTTPS())
r.use(security([
    withHSTSMaxAge(63072000),    // 2 年（推荐）
    withHSTSSubdomains(true),
    withHSTSPreload(true)        // 预加载（HTTPS 已确认）
]))
```

## 安全头详解

### X-XSS-Protection

**作用**：启用浏览器的 XSS 过滤器

**值**：
- `0` - 禁用 XSS 过滤
- `1` - 启用 XSS 过滤
- `1; mode=block` - 启用 XSS 过滤，检测到攻击时阻止页面渲染

**示例**：
```http
X-XSS-Protection: 1; mode=block
```

### X-Content-Type-Options

**作用**：禁止浏览器 MIME 类型嗅探

**值**：
- `nosniff` - 禁止嗅探

**示例**：
```http
X-Content-Type-Options: nosniff
```

> **💡 提示：为什么需要 nosniff？**
>
> **MIME 嗅探问题**：
> - 浏览器可能会忽略服务器声明的 Content-Type
> - 根据内容"猜测"文件类型
> - 攻击者可以利用此上传恶意文件
>
> **示例攻击**：
> ```
> 1. 攻击者上传 HTML 文件，但声明为 image/jpeg
> 2. 服务器返回 Content-Type: image/jpeg
> 3. 浏览器检测到内容是 HTML，将其作为 HTML 渲染
> 4. 用户访问时，恶意脚本被执行
> ```
>
> **nosniff 防护**：
> - 浏览器严格按照服务器声明的 Content-Type 处理
> - 不进行嗅探，防止攻击

### X-Frame-Options

**作用**：防止点击劫持攻击（Clickjacking）

**值**：
- `DENY` - 完全禁止在 iframe 中嵌入
- `SAMEORIGIN` - 仅允许同源嵌入
- `ALLOW-FROM uri` - 允许指定源的嵌入

**示例**：
```http
X-Frame-Options: DENY
```

### Strict-Transport-Security (HSTS)

**作用**：强制浏览器使用 HTTPS

**值**：
- `max-age=31536000` - HTTPS 缓存时间（秒）
- `includeSubDomains` - 包含所有子域名
- `preload` - 加入 HSTS 预加载列表

**示例**：
```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

**注意**：只有在 HTTPS 连接上才设置此头

### Content-Security-Policy (CSP)

**作用**：控制资源加载策略，防止 XSS 攻击

**常用指令**：
- `default-src` - 默认策略
- `script-src` - 脚本源
- `style-src` - 样式源
- `img-src` - 图片源
- `connect-src` - 连接目标（AJAX、WebSocket）

**示例**：
```http
Content-Security-Policy: default-src 'self'; script-src 'self' https://cdn.example.com
```

> **💡 提示：CSP 逐步实施**
>
> CSP 策略过于严格会破坏现有功能，建议逐步实施：
>
> **阶段 1：仅监控（report-only）**
> ```
> Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
> ```
>
> **阶段 2：宽松策略**
> ```
> Content-Security-Policy: default-src 'self' 'unsafe-inline'
> ```
>
> **阶段 3：严格策略**
> ```
> Content-Security-Policy: default-src 'self'; script-src 'self'
> ```
>
> 使用 CSP 报告收集违规情况，逐步完善策略

## 测试

### 验证安全头

```bash
curl -I http://localhost:8080/

# 响应头包含：
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# X-XSS-Protection: 1; mode=block
# Strict-Transport-Security: max-age=31536000; includeSubDomains
# Content-Security-Policy: default-src 'self'
```

### 测试 XSS 保护

```html
<!-- 测试页面 -->
<script>
alert('XSS');
</script>
```

如果 CSP 配置正确（`script-src 'self'`），内联脚本会被阻止。

### 测试 iframe 嵌入

创建一个尝试嵌入你的页面的 iframe：

```html
<iframe src="http://localhost:8080/"></iframe>
```

如果 `X-Frame-Options: DENY` 设置正确，浏览器会拒绝加载。

## 注意事项

### 1. 仅 HTTPS 设置 HSTS

HSTS 只应该在 HTTPS 连接上设置：

```cj
// ❌ 错误：HTTP 也设置 HSTS
r.use(security([
    withHSTSMaxAge(31536000)  // HTTP 也会设置这个头
]))

// ✅ 正确：仅在 HTTPS 时设置
func conditionalSecurity(): MiddlewareFunc {
    return { next =>
        return { ctx =>
            if (ctx.secure()) {
                // HTTPS：启用完整安全头
                r.use(security([
                    withHSTSMaxAge(31536000),
                    withHSTSSubdomains(true)
                ]))
            } else {
                // HTTP：不启用 HSTS
                r.use(security([
                    withXSSProtection("1; mode=block"),
                    withContentTypeNosniff(true),
                    withXFrameOptions("DENY")
                ]))
            }

            next(ctx)
        }
    }
}
```

### 2. CSP 逐步实施

不要一次性启用最严格的 CSP：

```cj
// ❌ 错误：一次性启用最严格 CSP
withCSP("default-src 'self'; script-src 'self'")  // 可能会破坏现有功能

// ✅ 正确：先使用 report-only 模式
// Content-Security-Policy-Report-Only: default-src 'self'; script-src 'self'; report-uri /csp-report
```

### 3. HSTS preload 注意事项

启用 `preload` 之前，确保：

```cj
// ✅ 检查清单：
// 1. 已配置 HTTPS（有效证书）
// 2. 已配置 HSTS 一段时间（如 30 天）
// 3. 所有子域名都支持 HTTPS
// 4. 不计划取消 HTTPS

withHSTSPreload(true)  // 满足以上条件后再启用
```

加入 HSTS preload 列表后，无法轻易移除！

### 4. 与代理协同

如果使用反向代理（Nginx、Apache），确保代理不会覆盖安全头：

**Nginx 配置**：
```nginx
location / {
    # 保留应用设置的安全头
    proxy_pass http://tang_app;

    # 或者：让代理设置安全头
    # add_header X-Frame-Options DENY;
    # add_header X-Content-Type-Options nosniff;
}
```

## 常见问题

### 问题 1：内联脚本/样式被阻止

**原因**：CSP 不允许 `unsafe-inline`，内联脚本/样式被阻止

**解决**：
```cj
// ❌ 不推荐：允许 unsafe-inline
withCSP("script-src 'self' 'unsafe-inline'")

// ✅ 推荐：将脚本/样式移到外部文件
withCSP("script-src 'self' https://cdn.example.com")

// 或者：使用 nonce（推荐）
let nonce = generateNonce()
ctx.kvSet("csp_nonce", nonce)
withCSP("script-src 'self' 'nonce-${nonce}'")
```

### 问题 2：第三方资源加载失败

**原因**：CSP 未包含第三方域名

**解决**：
```cj
withCSP("
    default-src 'self';
    script-src 'self' https://cdn.example.com https://analytics.example.com;
    style-src 'self' https://fonts.googleapis.com;
    img-src 'self' data: https:;
    connect-src 'self' https://api.example.com
")
```

## 相关链接

- **[CORS 中间件](cors.md)** - 跨域资源共享
- **[CSRF 中间件](csrf.md)** - CSRF 保护
- **[源码](../../../src/middleware/security/security.cj)** - Security 源代码
