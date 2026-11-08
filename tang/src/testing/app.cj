package tang.testing

import tang.{Tang, TangHttpContext, Params}
import ystyle::tachyon.{newDetachedCtx, snapshotResponse}

/// 跑一次请求，拿到响应记录（不起服务、不占端口、不走网络）
///
/// 实现方式是 tachyon 的 detached ctx：handler 链照常执行，
/// 只是响应被捕获到内存里而不是写 socket。
public func test(app: Tang, req: TestRequest): TestResponse {
    let raw = req.build()
    let ctx = newDetachedCtx(raw)
    let tangCtx = TangHttpContext(ctx, Params())
    app.getRouter().handle(ctx)
    return TestResponse(snapshotResponse(ctx))
}

/// 便捷重载：直接传方法 + 路径
public func test(app: Tang, method: String, target: String): TestResponse {
    return test(app, TestRequest.of(method, target))
}

/// 便捷重载：贴原始报文
public func testRaw(app: Tang, raw: String): TestResponse {
    return test(app, request(raw))
}
