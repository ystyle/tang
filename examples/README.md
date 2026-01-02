# Tang 示例集合

本目录包含了 Tang 框架的各种使用示例，帮助你快速上手和深入理解框架功能。

## 📚 示例列表

### 基础示例

#### 1. [basic](./basic/) - 基础使用示例
**学习内容**：
- ✅ 使用 `Tang` 应用类创建应用
- ✅ 注册各种 HTTP 方法路由（GET、POST、PUT、DELETE、PATCH）
- ✅ 使用路径参数（`:id`）
- ✅ 使用通配符路径（`*path`）
- ✅ 路由分组（`Group`）
- ✅ 自动显示启动 Banner 和路由列表

**适合**：刚接触 Tang 框架的开发者

```bash
cd examples/basic
cjpm run
# 访问 http://localhost:10000
```

#### 2. [all_method](./all_method/) - 所有 HTTP 方法示例
**学习内容**：
- ✅ 使用 `all()` 匹配所有 HTTP 方法
- ✅ 获取请求方法（`ctx.method()`）
- ✅ 健康检查和 CORS 预检场景

**适合**：了解 Tang 支持的所有 HTTP 方法

```bash
cd examples/all_method
cjpm run
# 访问 http://localhost:8080/health
```

#### 3. [json](./json/) - JSON 响应示例
**学习内容**：
- ✅ 返回 JSON 数据（`ctx.json()`）
- ✅ 使用可序列化类（`Serializable`）
- ✅ 自定义序列化和反序列化

**适合**：学习如何返回结构化 JSON 数据

```bash
cd examples/json
cjpm run
# 访问 http://localhost:10000/api/user/current
```

#### 4. [path_params](./path_params/) - 路径参数示例
**学习内容**：
- ✅ 获取路径参数（`ctx.param("id")`）
- ✅ 使用通配符捕获路径（`ctx.param("path")`）

**适合**：学习 URL 路径参数处理

```bash
cd examples/path_params
cjpm run
# 访问 http://localhost:10000/api/user/123
```

#### 5. [bind_query](./bind_query/) - 查询参数绑定示例
**学习内容**：
- ✅ 使用 `ctx.bindQuery()` 绑定查询参数到对象
- ✅ 定义可序列化类
- ✅ 自动类型转换

**适合**：学习便捷的查询参数处理

```bash
cd examples/bind_query
cjpm run
# 访问 http://localhost:10000/api/user?id=123&name=test
```

### 中间件示例

#### 6. [basicauth](./basicauth/) - HTTP 基本认证
**学习内容**：
- ✅ 使用 BasicAuth 中间件
- ✅ 自定义认证函数
- ✅ 保护特定路由

**适合**：学习基础认证机制

```bash
cd examples/basicauth
cjpm run
# 访问 http://localhost:10000/api/user/current
# 用户名: test, 密码: test
```

#### 7. [todo](./todo/) - RESTful API 示例
**学习内容**：
- ✅ 完整的 CRUD 操作（GET、POST、PUT、DELETE）
- ✅ 使用多个中间件（exception、logger、requestid）
- ✅ 实际的 REST API 设计

**适合**：学习如何构建完整的 REST API

```bash
cd examples/todo
cjpm run
# 尝试各种 CRUD 操作
curl http://localhost:10000/api/todo
curl -X POST http://localhost:10000/api/todo -H "Content-Type: application/json" -d '{"title":"Buy milk"}'
```

### 高级示例

#### 8. [middleware_showcase](./middleware_showcase/) - 中间件完整演示 ⭐
**学习内容**：
- ✅ **23+ 个中间件的完整示例**
- ✅ 中间件组合和执行顺序
- ✅ 健康检查、重定向、超时、限流等
- ✅ 安全中间件（CORS、CSRF、Security、KeyAuth）
- ✅ 会话管理（Session、EncryptCookie）
- ✅ 高级功能（缓存、ETag、幂等性、代理）

**包含的中间件**：
1. **Recovery** - 异常恢复
2. **AccessLog** - 访问日志
3. **RequestID** - 请求追踪
4. **RateLimit** - 限流
5. **BodyLimit** - 请求体限制
6. **CORS** - 跨域支持
7. **Security** - 安全头
8. **Cache** - 缓存控制
9. **ETag** - 缓存验证
10. **Favicon** - 网站图标
11. **Timeout** - 超时控制
12. **KeyAuth** - API 密钥认证
13. **Redirect** - URL 重定向
14. **Rewrite** - URL 重写
15. **HealthCheck** - 健康检查
16. **CSRF** - CSRF 保护
17. **Session** - 会话管理
18. **EncryptCookie** - Cookie 加密
19. **Idempotency** - 幂等性控制
20. **Proxy** - 反向代理
21. **StaticFile** - 静态文件服务

**适合**：全面了解 Tang 中间件系统

```bash
cd examples/middleware_showcase
cjpm run
# 访问 http://localhost:10001
# 查看启动时打印的完整测试指南
```

### 工具示例

#### 9. [http_demo](./http_demo/) - stdx 标准库性能测试
**说明**：
- ✅ 使用 stdx.net.http 标准库构建
- ✅ 用于性能基准测试对比
- ✅ 与 Tang 框架进行性能对比

**用途**：性能基准测试，详见 [性能基准测试文档](../docs/advanced/benchmark.md)

```bash
cd examples/http_demo
cjpm run
# 访问 http://localhost:10000/hello
```

#### 10. [banner_test](./banner_test/) - Banner 和路由打印测试
**学习内容**：
- ✅ 自动显示启动 Banner
- ✅ 自动打印路由列表
- ✅ 彩色路由显示（HTTP 方法着色）
- ✅ 路由排序（静态 → 动态 → 通配符）

**适合**：了解 Tang 的路由可视化功能

```bash
cd examples/banner_test
cjpm run
# 查看启动时的彩色 Banner 和路由表格
```

#### 11. [app_demo](./app_demo/) - Tang 应用类演示
**学习内容**：
- ✅ `Tang` 应用类的完整用法
- ✅ 配置选项（`withHost`、`withPort`、`withShowBanner` 等）
- ✅ 链式路由注册
- ✅ 中间件使用

**适合**：学习推荐的现代化 Tang 应用开发方式

```bash
cd examples/app_demo
cjpm run
# 访问 http://localhost:3000
```

---

## 🚀 快速开始

### 1. 运行基础示例

```bash
cd examples/basic
cjpm run
```

然后访问 `http://localhost:10000` 查看效果。

### 2. 运行中间件展示

```bash
cd examples/middleware_showcase
cjpm run
```

访问 `http://localhost:10001` 并按照终端输出的测试指南进行测试。

### 3. 运行完整应用示例

```bash
cd examples/todo
cjpm run
```

使用 `curl` 测试完整的 CRUD API。

---

## 📖 推荐学习路径

### 初学者路径

1. **basic** → 了解基础路由和 Tang 应用类
2. **json** → 学习返回 JSON 数据
3. **path_params** → 掌握路径参数
4. **todo** → 实践完整 REST API

### 中级开发者路径

1. **bind_query** → 学习参数绑定
2. **basicauth** → 了解认证机制
3. **all_method** → 掌握所有 HTTP 方法
4. **middleware_showcase** → 全面学习中间件系统

### 高级开发者路径

1. **app_demo** → 学习 Tang 应用类最佳实践
2. **middleware_showcase** → 深入中间件原理
3. **banner_test** → 了解框架可视化功能
4. 阅读源码 → 理解框架内部实现

---

## 💡 提示

- 所有示例都使用 `Tang` 应用类，这是推荐的现代化开发方式
- 示例默认监听不同的端口（10000、10001、3000 等），避免冲突
- 查看示例目录下的 `src/main.cj` 文件获取完整代码
- 每个 `cjpm.toml` 都配置了正确的依赖路径

---

## 🔗 相关文档

- **[主文档](../docs/)** - 完整的框架文档
- **[快速入门](../docs/getting-started.md)** - 5 分钟上手指南
- **[中间件文档](../docs/middleware/)** - 23+ 中间件详细说明

---

**准备好开始了吗？** 从 [basic](./basic/) 示例开始你的 Tang 之旅！🚀
