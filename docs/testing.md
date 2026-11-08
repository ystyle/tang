# 内置 HTTP 测试框架（tang.testing）

Go 的 `net/http/httptest` 能做的事，tang 这边也能做，而且更彻底 —— **不起服务、不占端口、不走网络**。
stdx.net.http 做不到这一点：它的 `HttpContext` 构造器是 internal，外部无法构造上下文，
所以只能起真实服务再用客户端去连。

## 为什么能做到

tachyon 提供了「脱离连接」的上下文：

```cangjie
DetachedRequest   // 手工构造的请求快照（方法/路径/头/body）
newDetachedCtx()  // 造一个不绑定 socket 的 RequestCtx
snapshotResponse()// 读回 handler 写进去的响应（状态码/头/body）
```

`tang.testing` 就是在它之上包了一层：

```cangjie
public func test(app: Tang, req: TestRequest): TestResponse
public func testRaw(app: Tang, raw: String): TestResponse
```

## 快速开始

```cangjie
import tang.*
import tang.testing.*

@Test
class UserApiTest {
    @TestCase
    func testGetUser(): Unit {
        let app = Tang()
        app.get("/users/:id", { ctx =>
            ctx.json(UserDto(...))
        })

        test(app, TestRequest.get("/users/42"))
            .assertStatus(200)
            .assertHeaderContains("Content-Type", "application/json")
            .assertBodyContains("\"id\":42")
    }
}
```

## API

### 构造请求

| 用法 | 说明 |
|---|---|
| `TestRequest.get("/x")` | GET |
| `TestRequest.post("/x")` / `put` / `patch` / `delete` / `head` / `options` | 其它方法 |
| `TestRequest.of("TRACE", "/x")` | 任意方法 |
| `.header("X-Token", "abc")` | 加请求头（可多次） |
| `.setHost("api.example.com")` | 改 Host |
| `.body("...") / .body(bytes)` | 请求体 |
| `.json("{\"a\":1}")` | 请求体 + Content-Type: application/json |
| `.form("a=1&b=2")` | 请求体 + Content-Type: application/x-www-form-urlencoded |
| `request(raw)` | 从原始报文构造（贴 packet 调试的习惯） |

### 断言响应

| 方法 | 说明 |
|---|---|
| `resp.status` / `resp.body` / `resp.headers` | 直接读 |
| `resp.header("X")` / `resp.hasHeader("X")` | 取头（大小写不敏感） |
| `assertStatus(200u16)` | 状态码 |
| `assertBody("...")` | body 全等 |
| `assertBodyContains("...")` | body 包含 |
| `assertHeader("X", "v")` / `assertHeaderContains("X", "v")` | 响应头 |

断言失败抛 `AssertException`，用例直接标红，不静默。

### 三种写法

```cangjie
// ① 构造器风格
test(app, TestRequest.post("/login").json("{\"name\":\"a\"}"))

// ② 只要方法 + 路径
test(app, "GET", "/health")

// ③ 贴原始报文（最贴近线上抓到的包）
testRaw(app, "GET /hello HTTP/1.1\r\nHost: x\r\nX-Debug: 1\r\n\r\n")
```

## 与「起真实服务」的取舍

| | `tang.testing` | 真实服务 + 客户端 |
|---|---|---|
| 速度 | 微秒级（无 socket、无线程等待） | 需要绑定/连接/超时处理 |
| 确定性 | 高（无端口冲突、无 TIME_WAIT） | 端口复用、并发测试易冲突 |
| 覆盖范围 | 路由/中间件/参数/响应构造 | 额外覆盖 TCP/HTTP 解析与连接管理 |
| 适用 | 绝大多数业务逻辑测试 | 协议层、并发、超时行为 |

两者都要：逻辑用 `tang.testing`，协议与连接行为用裸 socket 或压测工具。

## 注意

- `tang.testing` 是 core 的子包，**零 stdx**，测试里也不引入任何外部依赖
- 它不经过 tachyon 的请求解析，所以**不能**用来测「畸形报文怎么处理」——
  那种要发原始字节给真实 server（见 `tang/src/e2e_helpers_test.cj`）
