package tang

import std.sync.Mutex
import stdx.log.LogLevel
import stdx.net.http.{ClientBuilder}

/// 闭包内标志位（仓颉闭包不能修改捕获的裸 var，用 class 包装）
class BuilderFlag {
    var called: Bool = false
}

/// Tang.listen(builder) + setLogLevel 测试
/// 1. setLogLevel 更新 logLevel 字段（默认 ERROR）
/// 2. listen(builder)：builder 在 build 前被调用；服务正常启动；logger.level 默认 ERROR
@Test
class ListenTest {
    @TestCase
    func testSetLogLevel(): Unit {
        let app = Tang()
        // 默认 ERROR（压 stdx 连接噪音）
        @Expect(app.logLevel, LogLevel.ERROR)
        app.setLogLevel(LogLevel.INFO)
        @Expect(app.logLevel, LogLevel.INFO)
        app.setLogLevel(LogLevel.WARN)
        @Expect(app.logLevel, LogLevel.WARN)
    }

    @TestCase
    func testListenWithBuilder(): Unit {
        let flag = BuilderFlag()
        let app = Tang()
        app.setPort(18193u16)
        app.get("/ping", { ctx => ctx.writeString("pong") })

        // 固定端口，spawn 异步起服务
        spawn {
            app.listen({ sb =>
                flag.called = true
            })
        }

        // 轮询等待服务起来（listen 内 builder 先于 serve 执行）
        let client = ClientBuilder().build()
        var up = false
        for (i in 0..100) {
            try {
                let r = client.get("http://127.0.0.1:18193/ping")
                if (r.status == 200u16) {
                    up = true
                    break
                }
            } catch (_) {
                ()
            }
            sleep(100 * Duration.millisecond)
        }

        @Expect(up, true)
        @Expect(flag.called, true)

        // 默认 logger.level 是 ERROR
        if (let Some(s) <- app.getStdServer()) {
            @Expect(s.logger.level, LogLevel.ERROR)
        } else {
            @Fail("server 未启动")
        }

        let resp = client.get("http://127.0.0.1:18193/ping")
        @Expect(resp.status, 200u16)
        @Expect(readRespBody(resp), "pong")
        client.close()

        app.stop()
    }
}
