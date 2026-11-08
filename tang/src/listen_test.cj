package tang

import tang.log.{LogLevel, levelValue}

/// 闭包内标志位（仓颉闭包不能修改捕获的裸 var，用 class 包装）
class BuilderFlag {
    var called: Bool = false
}

/// Tang.listen(builder) + setLogLevel 测试
/// 1. setLogLevel 更新 logLevel 字段（默认 ERROR）
/// 2. listen(builder)：builder 在 serve 前被调用；服务正常启动并能响应
@Test
class ListenTest {
    @TestCase
    func testSetLogLevel(): Unit {
        let app = Tang()
        // 默认 ERROR
        @Expect(levelValue(app.logLevel), levelValue(LogLevel.ERROR))
        app.setLogLevel(LogLevel.INFO)
        @Expect(levelValue(app.logLevel), levelValue(LogLevel.INFO))
        app.setLogLevel(LogLevel.WARN)
        @Expect(levelValue(app.logLevel), levelValue(LogLevel.WARN))
    }

    @TestCase
    func testListenWithBuilder(): Unit {
        let flag = BuilderFlag()
        let app = Tang()
        app.setPort(18193u16)
        app.get("/ping", { ctx => ctx.writeString("pong") })

        // 固定端口，spawn 异步起服务
        spawn {
            app.listen({ srv =>
                flag.called = true
                srv.readTimeout = Duration.second * 10
            })
        }

        // 轮询等待服务起来
        var up = false
        var i = 0
        while (i < 100) {
            let resp = try {
                httpGet(18193u16, "/ping")
            } catch (e: Exception) {
                ""
            }
            if (statusOf(resp) == 200) {
                up = true
                break
            }
            sleep(Duration.millisecond * 100)
            i += 1
        }

        @Expect(up, true)
        @Expect(flag.called, true)

        let resp = httpGet(18193u16, "/ping")
        @Expect(statusOf(resp), 200)
        @Expect(bodyOf(resp), "pong")

        app.stop()
    }

    @TestCase
    func testStopReleasesServer(): Unit {
        let app = Tang()
        app.setPort(18194u16)
        app.get("/ping", { ctx => ctx.writeString("pong") })
        spawn {
            app.listen()
        }
        var up = false
        var i = 0
        while (i < 100) {
            let resp = try {
                httpGet(18194u16, "/ping")
            } catch (e: Exception) {
                ""
            }
            if (statusOf(resp) == 200) {
                up = true
                break
            }
            sleep(Duration.millisecond * 100)
            i += 1
        }
        @Expect(up, true)
        app.stop()
        sleep(Duration.millisecond * 100)
        match (app.getStdServer()) {
            case Some(_) => @Fail("stop() 后 server 应被置空")
            case None => @Expect(true, true)
        }
    }
}
