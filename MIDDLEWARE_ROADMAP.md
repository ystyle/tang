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

### ✅ 第二批 - 已完成（2026-01-02）

#### 1. ✅ KeyAuth - API 密钥认证
- **文件**：`src/middleware/keyauth/keyauth.cj`
- **功能**：
  - 基于 API Key 的简单认证
  - 支持从 header、query、cookie 读取 key
  - 支持自定义 key 验证逻辑
  - 支持多种查找位置配置
- **测试状态**：✅ 全部通过
  - 公开端点访问正常
  - 受保护端点认证正常
  - 无密钥返回 401
  - 有效密钥访问成功

#### 2. ✅ Rewrite - URL 重写
- **文件**：`src/middleware/rewrite/rewrite.cj`
- **功能**：
  - 重写请求 URL 路径
  - 支持正则表达式替换
  - 不改变浏览器地址（服务器端重写）
- **实现方式**：
  - 提供两种使用方式：
    1. **Router 层面**（推荐）：`r.addRewriteRule(createRewriteFunction(pattern, replacement))`
    2. 中间件方式（仅用于特定路由）：`rewrite(pattern, replacement)`
- **测试状态**：✅ 全部通过
  - `/old/api/data` -> `/api/data` ✅
  - `/api/v1/users` -> `/api/v2/users` ✅

#### 3. ✅ Cache - 缓存控制
- **文件**：`src/middleware/cache/cache.cj`
- **功能**：
  - 设置 Cache-Control 响应头
  - 支持路径级别的缓存规则
  - 支持自定义缓存策略
  - **新增**：支持排除特定路径（`withExcludePath`）
- **测试状态**：✅ 全部通过
  - 缓存端点：`max-age=3600, public` ✅
  - 排除路径功能：`/test/nocache` 手动设置 header 成功 ✅
  - API 路径规则：`no-cache, no-store` ✅

#### 4. ✅ ETag - 缓存验证
- **文件**：`src/middleware/etag/etag.cj`
- **功能**：
  - 自动生成 ETag 响应头
  - 基于 URL 路径生成（SHA256/MD5）
  - 支持弱 ETag
- **测试状态**：✅ 全部通过
  - ETag 响应头生成正常 ✅
  - 支持排除特定路径 ✅

---

### 📅 第三批 - 安全与高级功能（计划中）

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
- ✅ 已实现：18 个中间件（14 + 4个新增）
- 🚀 第一批：4/4（已完成）✅
- 🚀 第二批：4/4（已完成）✅
- 🚀 第三批：0/3（预计 1 天）
- 📋 第四批：0/3（可选）

### 总体目标
- 总计：27 个中间件
- 已完成：18/27 (67%)
- **最新完成**：KeyAuth, Rewrite, Cache, ETag（第二批）✅

---

## 🔨 开发规范

### ⚠️ Rewrite 中间件特殊说明

**重要**：由于 Tang 框架的路由匹配在中间件执行之前完成，Rewrite 中间件有两种实现方式：

#### 方式 1：Router 层面（推荐）✅
```cj
import tang.middleware.rewrite.createRewriteFunction

// 在 Router 上注册重写规则
let r = Router()
r.addRewriteRule(createRewriteFunction("/old/(.*)", "/new/$1"))
r.addRewriteRule(createRewriteFunction("/api/v1/(.*)", "/api/v2/$1"))
```

**优点**：
- 重写在路由匹配**之前**执行，真正改变路由匹配结果
- 支持正则捕获组替换（`$1`, `$2` 等）
- 性能更好

#### 方式 2：中间件方式（仅限特定路由）
```cj
import tang.middleware.rewrite.rewrite

// 在路由组上应用（会影响路由匹配）
let apiGroup = r.group("/api")
apiGroup.use(rewrite("/v1/(.*)", "/v2/$1"))
apiGroup.get("/v2/users", { ctx => ... })
```

**限制**：
- 只能用于已注册的路由组
- 需要手动注册目标路由

**原因**：Tang 的 `distribute()` 流程是：
1. `lookup(ctx)` - 路由匹配
2. 创建 `TangHttpContext`
3. 执行 handler（包含中间件）

因此路径重写必须在步骤 1 之前完成才能影响路由匹配。

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

### 2026-01-02
- ✅ 实现第二批中间件：KeyAuth, Rewrite, Cache, ETag - 全部测试通过
- 🔧 **重要架构修改**：添加 `Router.addRewriteRule()` 方法支持路径重写
- 🔧 **重要架构修改**：修改 `ctx.path()` 支持读取重写后的路径
- 🔧 Cache 中间件新增 `withExcludePath()` 和 `withExcludePaths()` 选项
- 📝 更新测试文档 `MIDDLEWARE_TEST_GUIDE.md`

### 2025-01-01
- ✅ 实现 bodylimit 中间件
- ✅ 实现 ratelimit 中间件，支持自定义客户端识别
- 📋 创建此路线图文档

## 📝 实现进度

### ✅ 已完成
- ✅ 第一批（2026-01-02）：HealthCheck, Redirect, Favicon, Timeout - 全部测试通过
- ✅ 第二批（2026-01-02）：KeyAuth, Rewrite, Cache, ETag - 全部测试通过 ✨

### 🚧 进行中
- 第三批：CSRF, Session, EncryptCookie - 待实现

### 📅 计划中
- 第四批：Proxy, Idempotency, Adaptor
