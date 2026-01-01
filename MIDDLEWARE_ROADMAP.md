# Tang 中间件开发路线图

> 参考 [Fiber middleware](https://github.com/gofiber/recipes/tree/master/middleware) 的实现

## ✅ 已实现中间件（14个）

### 监控与检查类
- ✅ **healthcheck** - 健康检查
  - 文件：`src/middleware/healthcheck/healthcheck.cj`
  - 功能：存活检查（Liveness）、就绪检查（Readiness）、系统信息
  - 配置：`withLivenessCheck()`, `withReadinessCheck()`, `withSystemInfo()`

### 路由与请求控制类
- ✅ **redirect** - URL 重定向
  - 文件：`src/middleware/redirect/redirect.cj`
  - 功能：301/302 重定向，可作为中间件或处理器
  - 常量：`MOVED_PERMANENTLY`, `FOUND`, `SEE_OTHER`, `TEMPORARY_REDIRECT`, `PERMANENT_REDIRECT`

- ✅ **favicon** - 网站图标处理
  - 文件：`src/middleware/favicon/favicon.cj`
  - 功能：自动处理 favicon.ico 请求，避免 404

- ✅ **timeout** - 请求超时控制
  - 文件：`src/middleware/timeout/timeout.cj`
  - 功能：记录请求开始时间，支持超时检查
  - 辅助函数：`isTimeout()`, `getElapsedMs()`

### 安全类
- ✅ **security** - 安全头设置（类似 helmet）
  - 文件：`src/middleware/security/security.cj`
  - 功能：X-Frame-Options, CSP, HSTS 等安全头

- ✅ **cors** - 跨域资源共享
  - 文件：`src/middleware/cors/cors.cj`
  - 功能：CORS 预检请求、允许来源、凭证等

- ✅ **basicauth** - HTTP 基本认证
  - 文件：`src/middleware/basicauth/basic_auth.cj`
  - 功能：用户名密码验证

### 日志与监控类
- ✅ **accesslog** - 访问日志
  - 文件：`src/middleware/accesslog/accesslog.cj`
  - 功能：记录请求方法、路径、状态码、延迟等

- ✅ **log** - 请求日志
  - 文件：`src/middleware/log/log.cj`
  - 功能：简化的请求日志

- ✅ **requestid** - 请求 ID
  - 文件：`src/middleware/requestid/requestid.cj`
  - 功能：生成/传递请求 ID 用于追踪

### 异常处理类
- ✅ **recovery** - 异常恢复
  - 文件：`src/middleware/exception/recovery.cj`
  - 功能：捕获 panic，返回友好的错误响应

### 流量控制类
- ✅ **ratelimit** - 请求速率限制
  - 文件：`src/middleware/ratelimit/ratelimit.cj`
  - 功能：滑动窗口限流，支持自定义客户端识别
  - 配置：`withMaxRequests()`, `withWindowMs()`, `withClientID()`

- ✅ **bodylimit** - 请求体大小限制
  - 文件：`src/middleware/bodylimit/bodylimit.cj`
  - 功能：检查 Content-Length，防止大文件攻击
  - 配置：`withMaxSize()`

### 静态文件类
- ✅ **staticfile** - 静态文件服务
  - 文件：`src/middleware/staticfile/static.cj`
  - 功能：提供静态文件，支持目录浏览、索引文件
  - 配置：`withPrefix()`, `withBrowse()`, `withIndexFiles()`

---

## 🚀 计划实现中间件（按优先级）

### 📅 第二批 - 常用功能（预计 3 小时）

#### 1. KeyAuth - API 密钥认证 ⭐⭐⭐⭐⭐
- **优先级**：🔴 极高
- **难度**：⭐ 极简
- **预计时间**：30 分钟
- **代码量**：~50 行
- **文件**：`src/middleware/keyauth/keyauth.cj`
- **功能**：
  - 基于 API Key 的简单认证
  - 支持从 header、query、cookie 读取 key
  - 支持自定义 key 验证逻辑
- **示例**：
  ```cj
  r.use(keyAuth([
      withKey("your-secret-key"),
      withLookup("header:X-API-Key"),  // 或 "query:token", "cookie:token"
      withValidator({ key =>
          // 自定义验证逻辑
          key == "valid-key"
      })
  ]))
  ```

#### 6. ETag - 缓存验证 ⭐⭐⭐⭐
- **优先级**：🟢 高（性能优化）
- **难度**：⭐⭐ 简单
- **预计时间**：40 分钟
- **代码量**：~80 行
- **文件**：`src/middleware/etag/etag.cj`
- **功能**：
  - 自动生成 ETag 响应头
  - 检查 If-None-Match 请求头
  - 内容未改变返回 304 Not Modified
- **示例**：
  ```cj
  r.use(etag())
  ```

#### 7. Cache - 缓存控制 ⭐⭐⭐⭐
- **优先级**：🟢 高（性能优化）
- **难度**：⭐⭐ 简单
- **预计时间**：1 小时
- **代码量**：~100 行
- **文件**：`src/middleware/cache/cache.cj`
- **功能**：
  - 设置 Cache-Control 响应头
  - 支持自定义缓存策略
  - 可基于路径、方法等配置
- **示例**：
  ```cj
  r.use(cache([
      withDuration(3600),  // 1 小时
      withRules([
          CacheRule("/api/*", 0),      // API 不缓存
          CacheRule("/static/*", 86400) // 静态文件缓存 1 天
      ])
  ]))
  ```

#### 8. Rewrite - URL 重写 ⭐⭐⭐
- **优先级**：🟢 中
- **难度**：⭐⭐ 简单
- **预计时间**：30 分钟
- **代码量**：~50 行
- **文件**：`src/middleware/rewrite/rewrite.cj`
- **功能**：
  - 重写请求 URL 路径
  - 支持正则表达式和通配符
  - 不改变浏览器地址（与 redirect 区别）
- **示例**：
  ```cj
  r.use(rewrite("/api/v1/*", "/api/v2/$1"))
  r.use(rewrite("/old/(*.*)", "/new/$1"))
  ```

---

### 📅 第三批 - 安全与高级功能（预计 1 天）

#### 9. CSRF - 跨站请求伪造保护 ⭐⭐⭐⭐⭐
- **优先级**：🔴 极高（安全必备）
- **难度**：⭐⭐⭐ 中等
- **预计时间**：2 小时
- **代码量**：~150 行
- **文件**：`src/middleware/csrf/csrf.cj`
- **功能**：
  - 生成 CSRF token
  - 验证请求中的 token
  - 支持从 header 或 form 获取 token
  - 配置白名单路径
- **示例**：
  ```cj
  r.use(csrf([
      withSecret("your-secret-key"),
      withExclusion("/api/*"),  // API 不需要 CSRF
      withTokenLookup("header:X-CSRF-Token")
  ]))
  ```

#### 10. Session - 会话管理 ⭐⭐⭐⭐
- **优先级**：🟠 中高（重要但复杂）
- **难度**：⭐⭐⭐⭐ 较复杂
- **预计时间**：半天
- **代码量**：~300 行
- **文件**：
  - `src/middleware/session/session.cj`
  - `src/middleware/session/store.cj`（存储接口）
  - `src/middleware/session/memory_store.cj`（内存存储）
  - `src/middleware/session/cookie_store.cj`（Cookie 存储）
- **功能**：
  - Session 存储接口（支持多种存储后端）
  - 内存存储（默认）
  - Cookie 存储
  - Session 配置：过期时间、cookie 选项等
- **示例**：
  ```cj
  r.use(session([
      withStore(MemoryStore()),
      withExpiration(3600),
      withCookieOptions(/* ... */)
  ]))

  // 使用
  r.get("/login", { ctx =>
      ctx.session().set("userId", "123")
  })
  ```

#### 11. EncryptCookie - Cookie 加密 ⭐⭐⭐
- **优先级**：🟢 中
- **难度**：⭐⭐⭐ 中等
- **预计时间**：1.5 小时
- **代码量**：~100 行
- **文件**：`src/middleware/encryptcookie/encryptcookie.cj`
- **功能**：
  - 自动加密 Cookie 值
  - 防止 Cookie 被篡改
- **示例**：
  ```cj
  r.use(encryptCookie([
      withKey("encryption-key"),
      withExclude("session_*")  // 不加密某些 cookie
  ]))
  ```

---

### 📅 第四批 - 高级功能（可选）

#### 12. Proxy - 反向代理 ⭐⭐⭐
- **优先级**：🟢 低
- **难度**：⭐⭐⭐⭐⭐ 复杂
- **预计时间**：2-3 小时
- **代码量**：~200+ 行
- **依赖**：需要完整的 HTTP 客户端
- **文件**：`src/middleware/proxy/proxy.cj`
- **功能**：
  - 反向代理请求到后端服务器
  - 支持负载均衡
  - 支持 WebSocket 透传

#### 13. Idempotency - 幂等性控制 ⭐⭐⭐
- **优先级**：🟢 低
- **难度**：⭐⭐⭐ 中等
- **预计时间**：2 小时
- **功能**：
  - 防止重复提交
  - 基于请求内容生成幂等 key
  - 缓存响应结果

#### 14. Adaptor - 框架适配器 ⭐⭐
- **优先级**：🟢 低
- **难度**：⭐⭐⭐⭐ 较复杂
- **预计时间**：2 小时
- **功能**：
  - 与其他 Web 框架的适配器
  - 例如：适配 Gin、Echo 处理器

---

## 📊 实现进度统计

### 当前进度
- ✅ 已实现：10 个中间件
- 🚀 第一批：0/4（预计 1.5 小时）
- 🚀 第二批：0/4（预计 3 小时）
- 🚀 第三批：0/3（预计 1 天）
- 📋 第四批：0/3（可选）

### 总体目标
- 总计：27 个中间件
- 已完成：10/27 (37%)
- **预计剩余时间**：约 1.5 天开发时间

---

## 🔨 开发规范

### 文件结构
```
src/middleware/{name}/{name}.cj
```

### API 设计模式
```cj
// 1. 配置选项类型
public type {Middleware}Option = ({Middleware}Config) -> Unit

// 2. 配置类
public class {Middleware}Config {
    public init() {}
    public func set{Option}(value: Type): Unit { ... }
}

// 3. 选项函数
public func with{Option}(value: Type): {Middleware}Option {
    return { config => config.set{Option}(value) }
}

// 4. 中间件函数（带配置）
public func {middleware}(opts: Array<{Middleware}Option>): MiddlewareFunc {
    let config = {Middleware}Config()
    for (opt in opts) {
        opt(config)
    }
    return { next => ... }
}

// 5. 中间件函数（默认配置）
public func {middleware}(): MiddlewareFunc {
    return {middleware}(Array<{Middleware}Option>())
}
```

### 测试要求
每个中间件都需要：
1. 在 `examples/middleware_showcase` 中添加示例
2. 提供清晰的使用注释和示例代码
3. 测试正常流程和边界情况

---

## 📝 变更日志

### 2025-01-01
- ✅ 实现 bodylimit 中间件
- ✅ 实现 ratelimit 中间件，支持自定义客户端识别
- 📋 创建此路线图文档

### 待补充...

## 📝 实现进度

### ✅ 已完成
- ✅ 第一批（2026-01-02）：HealthCheck, Redirect, Favicon, Timeout - 全部测试通过

### 🚧 进行中
- 第二批：KeyAuth, ETag, Cache, Rewrite - 待实现

### 📅 计划中
- 第三批：JWT, Session, Compress, Proxy
- 第四批：Monitor, Limiter, Csrf, CacheControl
