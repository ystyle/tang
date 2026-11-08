package http_demo

import tang.*

/// 最小 HTTP 服务
///
/// 对照旧版（stdx.net.http 的 ServerBuilder + distributor.register）：
/// 现在底层是 tachyon，写法更直接，且不需要 stdx 环境。
main() {
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16)
    ])

    app.get("/hello", { ctx => ctx.writeString("hello world!") })

    app.listen()
}
