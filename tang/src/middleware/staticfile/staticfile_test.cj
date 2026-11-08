package tang.middleware.staticfile

import std.fs.{Path, Directory, File}
import std.time.DateTime
import ystyle::tachyon.{newDetachedCtx, snapshotResponse, DetachedRequest}
import tang.{TangHttpContext, Params}

/// 静态文件处理器单测：用 tachyon 的 detached ctx 直接喂请求、读回响应，
/// 不需要起真实服务（也就不需要 socket 客户端）。
@Test
class StaticFileTest {
    func prepareDir(tag: String): String {
        // 每次用唯一目录，避免上次跑剩下的文件让 File.create 抛异常
        let dir = "/tmp/tang-static-test-" + tag + "-" + DateTime.now().toUnixTimeStamp().toMilliseconds().toString()
        try {
            Directory.create(Path(dir), recursive: true)
        } catch (e: Exception) {
            ()
        }
        let f1 = File.create(Path(dir + "/hello.txt"))
        f1.write("hello static".toArray())
        f1.close()
        try {
            Directory.create(Path(dir + "/sub"), recursive: true)
        } catch (e: Exception) {
            ()
        }
        let f2 = File.create(Path(dir + "/sub/data.bin"))
        f2.write(Array<Byte>(26, { i => UInt8(97 + i) }))
        f2.close()
        return dir
    }

    func ctxFor(method: String, target: String, headers: Array<(String, String)>): TangHttpContext {
        let req = DetachedRequest()
        req.method = method
        req.target = target
        req.host = "x"
        for (h in headers) {
            req.headers.add(h)
        }
        return TangHttpContext(newDetachedCtx(req), Params())
    }

    @TestCase
    func testServeFile(): Unit {
        let dir = prepareDir("a")
        let h = staticFiles(dir, opts: [withPrefix("/static")])

        let ctx = ctxFor("GET", "/static/hello.txt", Array<(String, String)>())
        h(ctx)
        let resp = snapshotResponse(ctx.raw)
        @Expect(resp.statusCode, 200)
        @Expect(String.fromUtf8(resp.body), "hello static")

        // 不存在的文件 → 404
        let ctx2 = ctxFor("GET", "/static/nope.txt", Array<(String, String)>())
        h(ctx2)
        @Expect(snapshotResponse(ctx2.raw).statusCode, 404)

        // 非 GET/HEAD → 405
        let ctx3 = ctxFor("POST", "/static/hello.txt", Array<(String, String)>())
        h(ctx3)
        @Expect(snapshotResponse(ctx3.raw).statusCode, 405)
    }

    @TestCase
    func testRange(): Unit {
        let dir = prepareDir("range")
        let h = staticFiles(dir, opts: [withPrefix("/s")])
        let ctx = ctxFor("GET", "/s/sub/data.bin", [("Range", "bytes=0-4")])
        h(ctx)
        let resp = snapshotResponse(ctx.raw)
        @Expect(resp.statusCode, 206)
        @Expect(String.fromUtf8(resp.body), "abcde")
    }

    @TestCase
    func testTraversalBlocked(): Unit {
        let dir = prepareDir("traversal")
        let h = staticFiles(dir, opts: [withPrefix("/s")])
        let ctx = ctxFor("GET", "/s/../../etc/passwd", Array<(String, String)>())
        h(ctx)
        let resp = snapshotResponse(ctx.raw)
        @Expect(resp.statusCode, 404)
    }

    @TestCase
    func testMaxAgeHeader(): Unit {
        let dir = prepareDir("maxage")
        let h = staticFiles(dir, opts: [withPrefix("/s"), withMaxAge(3600)])
        let ctx = ctxFor("GET", "/s/hello.txt", Array<(String, String)>())
        h(ctx)
        let resp = snapshotResponse(ctx.raw)
        var found = false
        for ((k, v) in resp.headers) {
            if (k == "Cache-Control") {
                found = true
                @Expect(v, "max-age=3600")
            }
        }
        @Expect(found, true)
    }
}
