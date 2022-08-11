### tang
>一个轻量级的web框架， 状态： 开发中

### 功能
- 中间件[middleware]： 可以把常见操作从 HTTP handler提取到可重用函数中
- 支持路由优先级： 静态路径 > 命名路径 > 通配符路径
- 支持路由分组


### 示例
```cj
from tang import tang.*
from tang import middleware.LogMiddleware
from net import http.Server, http.ResponseWriteStream
from std import time.Duration

func debugHandle(w:ResponseWriteStream, r:Request) {
    w.writeStatusCode(200)
    w.write("hello world".toUtf8Array())
    ()
}

main() {
    // 初始化router
    let r = Router([
        Use([  // 使用中间件
            LogMiddleware // 访问日志中间件
        ])
    ])
    // 创建路由分组
    r.group.withGroup("/api", {group =>
        // 命名路径 
        group.get("/user/:id", debugHandle)
        // 静态路径
        group.get("/user/current", {w, r => 
            w.writeStatusCode(200)
            println(w.header().getKeysToString())
            w.write("current user: haha\n".toUtf8Array())
        })
        // 通配符路径
        group.get("/user/*path", debugHandle)
    })
    
    r.group.get("/hello", debugHandle)
    
    println("listening on http://localhost:10000")

    // 初始并启动服务器
    let srv = Server(r)
    srv.port = 10000
    srv.listenAndServe()
}
```

### 更多示例
请查看 [`examples`](/examples/) 目录