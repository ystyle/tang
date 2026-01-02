package demo

import stdx.net.http.{ServerBuilder, HttpRequest}

 main() {
    // 1. 构建 Server 实例
    let server = ServerBuilder().addr("127.0.0.1").port(10000).build()
    // 2. 注册 HttpRequestHandler
    server.distributor.register("/hello", {
        httpContext => httpContext.responseBuilder.body("hello world!")
    })
    // 3. 启动服务
    server.serve()
 }
