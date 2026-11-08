package tang

import std.sync.Mutex
import stdx.net.http.{ServerBuilder, ClientBuilder, Client, Server, HttpResponse, HttpContext, HttpRequestDistributor, NotFoundHandler}

/// 测试端口占位（afterBind 回填实际端口）
class TestPortHolder {
    var value: UInt16 = 0
}

/// 读取 HttpResponse body 为字符串
func readRespBody(resp: HttpResponse): String {
    let size = resp.bodySize ?? 1024
    let buf = Array<UInt8>(size, repeat: 0)
    let len = resp.body.read(buf)
    if (len > 0) {
        return String.fromUtf8(buf.slice(0, len))
    }
    return ""
}

/// 起一个真实 stdx Server（端口 0 随机绑定），tang Router 作为 distributor
/// 返回 (baseUrl, server, client)，用完需调 stopTestServer
func startTestServer(app: Tang): (String, Server, Client) {
    startTestServer(app.getRouter())
}

/// 起一个真实 stdx Server（端口 0 随机绑定），自定义 distributor（如 ComposeDistributor）
func startTestServer(distributor: HttpRequestDistributor): (String, Server, Client) {
    let portLock = Mutex()
    let portCond = synchronized(portLock) { portLock.condition() }
    let holder = TestPortHolder()

    let server = ServerBuilder()
        .distributor(distributor)
        .addr("127.0.0.1")
        .port(0)
        .build()
    server.afterBind({ =>
        synchronized(portLock) {
            holder.value = server.port
            portCond.notifyAll()
        }
    })
    spawn { => server.serve() }

    synchronized(portLock) {
        while (holder.value == 0) {
            portCond.wait(timeout: 5 * Duration.second)
        }
    }
    let base = "http://127.0.0.1:" + holder.value.toString()
    let client = ClientBuilder().build()
    (base, server, client)
}

func stopTestServer(server: Server, client: Client): Unit {
    client.close()
    server.closeGracefully()
}

/// fromStd 反向挂载适配器测试
/// 1. 函数式 (HttpContext) -> Unit 挂进 tang 路由
/// 2. 类式 HttpRequestHandler（NotFoundHandler）挂进 tang 路由
/// 3. fromStd 挂的路由自动走 tang 中间件链（Group.wrap 生效）
@Test
class FromStdTest {
    @TestCase
    func testFromStdFuncAndClass(): Unit {
        let app = Tang()

        // ① 函数式 stdx handler
        app.get("/std-fn", fromStd({ ctx: HttpContext =>
            ctx.responseBuilder.body("std-fn-ok")
        }))

        // ② 类式 stdx handler（NotFoundHandler 是 HttpRequestHandler）
        app.get("/std-404", fromStd(NotFoundHandler()))

        // ③ fromStd 挂的路由走中间件链：中间件设置的 header 应出现在响应中
        // （Tang 无 use 方法，全局中间件通过 Router 根 group 添加，测试同包可访问 internal 字段）
        let md: MiddlewareFunc = { next =>
            {
                ctx =>
                ctx.set("X-FromStd-MW", "yes")
                next(ctx)
            }
        }
        app.getRouter()._group.use([md])
        app.get("/std-mw", fromStd({ ctx: HttpContext =>
            ctx.responseBuilder.body("mw-ok")
        }))

        let (base, server, client) = startTestServer(app)

        // ① 函数式：body 正确
        let resp1 = client.get(base + "/std-fn")
        @Expect(resp1.status, 200u16)
        @Expect(readRespBody(resp1), "std-fn-ok")

        // ② 类式：NotFoundHandler 返回 404
        let resp2 = client.get(base + "/std-404")
        @Expect(resp2.status, 404u16)

        // ③ 中间件链生效：响应头 X-FromStd-MW
        let resp3 = client.get(base + "/std-mw")
        @Expect(resp3.status, 200u16)
        @Expect(readRespBody(resp3), "mw-ok")
        if (let Some(v) <- resp3.headers.getFirst("X-FromStd-MW")) {
            @Expect(v, "yes")
        } else {
            @Fail("中间件 header 缺失，fromStd 挂载未走中间件链")
        }

        stopTestServer(server, client)
    }

    /// context prop 化：handler 内通过 ctx.context（public prop）直接操作底层 HttpContext
    @TestCase
    func testContextProp(): Unit {
        let app = Tang()
        app.get("/ctx-prop", { ctx =>
            // ctx.context 是 public prop，返回底层 stdx HttpContext
            ctx.context.responseBuilder.body("ctx-prop-ok")
        })

        let (base, server, client) = startTestServer(app)

        let resp = client.get(base + "/ctx-prop")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "ctx-prop-ok")

        stopTestServer(server, client)
    }
}
