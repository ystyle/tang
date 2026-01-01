# Fiber Context API 对比分析

## Fiber Context 主要方法分类

### 1. 请求信息
- `Accepts()`, `AcceptsCharsets()`, `AcceptsEncodings()`, `AcceptsLanguages()` - 内容协商
- `App()` - 获取 App 实例
- `BaseURL()` - ✅ 已实现 (baseURL)
- `Body()`, `BodyRaw()`, `BodyParser()` - ✅ 已实现 (bodyRaw, bindJson)
- `Context()` - 获取底层 HTTP Context
- `Cookies()`, `Cookie()` - ✅ 已实现 (cookie, cookies)
- `Fresh()` - 检查请求是否新鲜
- `Get()` - ✅ 已实现 (getHeader)
- `Hostname()` - ✅ 已实现 (hostName)
- `IP()`, `IPs()` - ✅ 已实现 (ip, ips)
- `Is()` - ✅ 已实现 (is, isType)
- `Method()` - ✅ 已实现 (method)
- `OriginalURL()` - ✅ 已实现 (originalURL)
- `Params()`, `AllParams()`, `ParamsParser()`, `ParamsInt()` - ✅ 已实现 (param, params)
- `Path()` - ✅ 已实现 (path)
- `Protocol()` - ✅ 已实现 (protocolVersion，返回 Protocol 枚举)
- `Query()`, `Queries()`, `QueryParser()`, `QueryInt()`, `QueryBool()`, `QueryFloat()` - ✅ 已实现
- `Range()` - Range 请求
- `Request()` - 获取原始请求对象
- `Route()` - ✅ 已实现 (route)
- `Port()` - ✅ 已实现 (port)
- `Secure()` - ✅ 已实现 (secure)

### 2. 响应操作
- `Append()` - ✅ 已实现 (append，链式调用)
- `Attachment()` - ✅ 已实现 (attachment，链式调用)
- `ClearCookie()` - ✅ 已实现 (clearCookie)
- `Download()` - ✅ 已实现 (download)
- `Format()` - 格式化响应
- `JSON()`, `JSONP()`, `XML()` - ✅ 已实现 (json)
- `Links()` - 设置 Link 响应头
- `Location()` - 设置 Location 响应头
- `Redirect()` - ✅ 已实现 (redirect, redirectWithStatus)
- `Render()` - 渲染模板
- `Response()` - 获取原始响应对象
- `Send()`, `SendFile()`, `SendStatus()`, `SendString()` - ✅ 已实现 (sendStatus, writeString, write)
- `Set()` - ✅ 已实现 (set，链式调用)
- `Status()` - ✅ 已实现 (status，链式调用)
- `Type()` - ✅ 已实现 (type, contentType，链式调用)
- `Vary()` - 设置 Vary 响应头
- `Write()`, `Writef()`, `WriteString()` - ✅ 已实现 (writeString, write)

### 3. 中间件和流程控制
- `Locals()` - 本地存储
- `Next()` - 调用下一个中间件
- `RestartRouting()` - 重新开始路由

### 4. 其他实用方法
- `Bind()` - 绑定路由参数
- `ClientHelloInfo()` - TLS 信息
- `FormFile()`, `FormValue()` - ✅ 已实现 (fromFile, fromValue)
- `MultipartForm()` - ✅ 已实现 (multipartForm)
- `GetRespHeader()`, `GetReqHeaders()`, `GetRespHeaders()` - 响应/请求头
- `Stale()` - 检查请求是否过期
- `Subdomains()` - 子域名
- `XHR()` - 是否是 AJAX 请求

## Tang HttpContext 当前实现

### ✅ 已实现的功能

#### 1. 基础请求信息
- `baseURL()`, `hostName()`, `ip()`, `ips()`
- `param()`, `params()`, `route()`
- `query()`, `queries()`, `queryInt()`, `queryBool()`, `queryFloat()`
- `getHeader()` - 获取请求头
- `method()` - ✨ 新增：获取 HTTP 方法
- `path()` - ✨ 新增：获取请求路径
- `protocolVersion()` - ✨ 新增：获取协议版本（返回 Protocol 枚举）
- `port()` - ✨ 新增：获取端口号
- `secure()` - ✨ 新增：检查是否 HTTPS
- `originalURL()` - ✨ 新增：获取完整原始 URL
- `is()`, `isType()` - ✨ 新增：检查请求内容类型

#### 2. 请求体解析
- `bodyRaw()`
- `bindJson<T>()` - 绑定 JSON 到 class
- `bindQuery<T>()` - 绑定 query 到 class
- `multipartForm()`, `fromFile()`, `fromValue()`

#### 3. 响应操作（链式调用支持）
- `json()`, `jsonWithCode()`
- `writeString()`, `writeStringWithCode()`, `write()`
- `download()`
- `status(code)` - ✨ 新增：设置状态码（链式）
- `set(key, value)` - ✨ 新增：设置响应头（链式）
- `append(key, value)` - ✨ 新增：追加响应头（链式）
- `contentType()`, `type()` - ✨ 新增：设置 Content-Type（链式）
- `sendStatus(code)` - ✨ 新增：发送状态码响应
- `redirect(location)` - ✨ 新增：重定向
- `redirectWithStatus(location, code)` - ✨ 新增：指定状态码重定向
- `attachment(filename)` - ✨ 新增：设置附件响应头（链式）

#### 4. Cookie 操作（使用 Cangjie 原生 Cookie）
- `cookie(name)` - ✨ 新增：获取指定 Cookie
- `cookies()` - ✨ 新增：获取所有 Cookies
- `setCookie(cookie)` - ✨ 新增：设置 Cookie
- `setSimpleCookie(name, value)` - ✨ 新增：快捷设置简单 Cookie
- `clearCookie(name)` - ✨ 新增：清除 Cookie

#### 5. 认证
- `basicAuth()`

#### 6. 本地存储
- `kvGet<T>()`, `kvSet()`

### ❌ 尚未实现的重要 Fiber API

#### 低优先级（特定场景）
1. **内容协商**
   - `accepts(...types)` - 内容协商
   - `fresh()` - 检查缓存新鲜度

2. **高级请求信息**
   - `range(size: Int)` - Range 请求支持
   - `xhr()` - 是否 AJAX 请求
   - `subdomains()` - 子域名列表
   - `stale()` - 检查缓存过期

3. **响应工具**
   - `vary(fields: Array<String>)` - Vary 响应头
   - `links(linkMap)` - Link 响应头

4. **其他**
   - `bind()` - 绑定路由参数生成 URL
   - `render()` - 模板渲染

## 实现进度总结

### ✅ 已完成阶段（2025-01）

#### 阶段 1：核心响应操作 ✅
使用 `extend` 语法在 `src/context_response.cj` 中实现：
- ✅ `status(code: UInt16): TangHttpContext` - 设置状态码（链式）
- ✅ `set(key: String, value: String): TangHttpContext` - 设置响应头（链式）
- ✅ `append(key: String, value: String): TangHttpContext` - 追加响应头（链式）
- ✅ `contentType(contentType: String): TangHttpContext` - 设置 Content-Type（链式）
- ✅ `type(contentType: String): TangHttpContext` - Content-Type 别名（链式）
- ✅ `sendStatus(code: UInt16): Unit` - 发送状态码响应
- ✅ `redirect(location: String): Unit` - 重定向（302）
- ✅ `redirectWithStatus(location: String, code: UInt16): Unit` - 指定状态码重定向
- ✅ `attachment(filename: String): TangHttpContext` - 设置附件响应头（链式）

#### 阶段 2：请求信息增强 ✅
使用 `extend` 语法在 `src/context_request.cj` 中实现：
- ✅ `method(): String` - 获取 HTTP 方法（如 "GET", "POST"）
- ✅ `path(): String` - 获取请求路径
- ✅ `protocolVersion(): Protocol` - 获取协议版本（返回 Protocol 枚举）
- ✅ `port(): UInt16` - 获取端口号
- ✅ `isType(contentType: String): Bool` - 检查内容类型
- ✅ `is(contentType: String): Bool` - isType 别名
- ✅ `secure(): Bool` - 检查是否 HTTPS
- ✅ `originalURL(): String` - 获取完整原始 URL

#### 阶段 3：Cookie 操作 ✅
使用 `extend` 语法在 `src/context_cookie.cj` 中实现：
- ✅ `cookie(name: String): ?String` - 获取指定 Cookie
- ✅ `cookies(): HashMap<String, String>` - 获取所有 Cookies
- ✅ `setCookie(cookie: Cookie): TangHttpContext` - 设置 Cookie（使用原生 Cookie）
- ✅ `setSimpleCookie(name: String, value: String): TangHttpContext` - 快捷设置简单 Cookie
- ✅ `clearCookie(name: String): TangHttpContext` - 清除 Cookie

**设计亮点**：
- 使用 Cangjie 原生 `stdx.net.http.Cookie` 类，无需自定义实现
- 所有方法都支持链式调用（返回 `TangHttpContext`）
- 使用 `extend` 语法将功能分散到多个文件，提高代码可维护性

### 📋 未来建议阶段

#### 阶段 4：内容协商和缓存（优先级：中）
```cj
// 内容协商
public func accepts(...types: String): ?String
public func acceptsCharsets(...charsets: String): ?String
public func acceptsEncodings(...encodings: String): ?String
public func acceptsLanguages(...languages: String): ?String

// 缓存控制
public func fresh(): Bool  // 检查请求是否新鲜
public func stale(): Bool  // 检查请求是否过期
```

#### 阶段 5：高级功能（优先级：低）
```cj
// Range 请求支持
public func range(size: Int64): ?ContentRange

// 子域名
public func subdomains(offset: Int = 0): ArrayList<String>

// AJAX 检测
public func xhr(): Bool

// 响应头工具
public func vary(fields: Array<String>): TangHttpContext
public func links(linkMap: HashMap<String, String>): TangHttpContext
```

## 使用示例

完整的 chainable API 使用示例请参考：[CHAINABLE_API_EXAMPLES.md](./CHAINABLE_API_EXAMPLES.md)

### 快速示例

```cj
import tang.*
import stdx.net.http.{HttpStatusCode, Cookie}

main() {
    let app = Tang()

    // 链式调用示例
    app.post("/api/login") { ctx =>
        if (ctx.is("application/json")) {
            let cookie = Cookie("session", "abc123",
                maxAge: Some(3600),
                path: "/",
                secure: ctx.secure(),
                httpOnly: true)

            ctx.status(200)
               .set("Content-Type", "application/json")
               .setCookie(cookie)
               .writeString("{\"success\":true}")
        } else {
            ctx.sendStatus(400)
        }
    }

    app.start(8080)
}
```
