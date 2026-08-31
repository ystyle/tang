package tang

import stdx.log.LogLevel
import stdx.net.http.{ServerBuilder, Server}
import cjpminfo.*

///
/// Tang 应用类
/// 封装 Router 和 Server，提供简洁的应用启动 API
///
public class Tang {
    var router: Router
    var server: Option<Server>
    var host: String = "127.0.0.1"
    var port: UInt16 = 8080
    var printBanner: Bool = true
    var printRoutes: Bool = true
    var shutdownCallback: ?() -> Unit = None
    var logLevel: LogLevel = LogLevel.ERROR  // 默认压掉 stdx 连接噪音日志（Socket is closed 等）

    /// 创建 Tang 应用实例
    public init() {
        this.router = Router()
        this.server = None
    }

    /// 使用选项配置创建 Tang 应用
    public init(opts: Array<TangOption>) {
        this()
        for (opt in opts) {
            opt(this)
        }
    }

    /// 获取底层 Router
    public func getRouter(): Router {
        this.router
    }

    /// 设置主机地址
    public func setHost(host: String): Tang {
        this.host = host
        this
    }

    /// 设置端口
    public func setPort(port: UInt16): Tang {
        this.port = port
        this
    }

    /// 设置是否打印 Banner
    public func setShowBanner(show: Bool): Tang {
        this.printBanner = show
        this
    }

    /// 设置是否打印路由
    public func setShowRoutes(show: Bool): Tang {
        this.printRoutes = show
        this
    }
    
    /// 设置 shutdown 回调
    public func setShutdownCallback(callback: () -> Unit): Tang {
        this.shutdownCallback = Some(callback)
        this
    }

    /// 设置 stdx Server 日志级别（默认 ERROR，压连接噪音日志）
    public func setLogLevel(level: LogLevel): Tang {
        this.logLevel = level
        this
    }

    /// 启动应用（阻塞）- 使用配置的 host 和 port
    public func listen(): Unit {
        listen({ _: ServerBuilder => () })
    }

    /// 启动应用（阻塞）- 使用配置的 host 和 port，支持 builder 定制 stdx ServerBuilder
    /// builder 在 build 前调用，可配置 TLS、超时、协程池、HTTP/2 参数等
    ///
    /// 示例：
    /// ```cj
    /// app.listen({ sb => sb.tlsConfig(tlsCfg).readTimeout(5 * Duration.second) })
    /// ```
    public func listen(builder: (ServerBuilder) -> Unit): Unit {
        // 打印 Banner
        if (this.printBanner) {
            this.router.printBanner(version: TANG_VERSION, port: this.port)
        }

        // 打印路由
        if (this.printRoutes) {
            this.router.printRoutes()
        }

        // 构建并启动服务器
        let sb = ServerBuilder()
            .distributor(this.router)
            .addr(this.host)
            .port(this.port)
        builder(sb)
        let server = sb.build()
        server.logger.level = this.logLevel
        this.server = server
        
        // 注册 shutdown 回调
        if (let Some(cb) <- shutdownCallback) {
            server.onShutdown(cb)
        }
        
        server.serve()
    }

    /// 启动应用（阻塞）- 指定端口
    public func listen(port: UInt16): Unit {
        this.port = port
        listen()
    }

    /// 启动应用（阻塞）- 指定 host 和 port
    public func listen(host: String, port: UInt16): Unit {
        this.host = host
        this.port = port
        listen()
    }

    /// 异步启动服务器
    public func listenAsync(): Unit {
        spawn {
            listen()
        }
    }

    /// 异步启动服务器 - 指定端口
    public func listenAsync(port: UInt16): Unit {
        this.port = port
        spawn {
            listen()
        }
    }

    /// 异步启动服务器 - 指定 host 和 port
    public func listenAsync(host: String, port: UInt16): Unit {
        this.host = host
        this.port = port
        spawn {
            listen()
        }
    }

/// 停止服务器
    public func stop(): Unit {
        match (this.server) {
            case Some(s) =>
                s.closeGracefully()
                this.server = None
            case None => ()
        }
    }
    
    /// 获取底层 stdx Server
    public func getStdServer(): ?Server {
        this.server
    }
    
    /// 注册 shutdown 回调
    public func onShutdown(callback: () -> Unit): Unit {
        match (this.server) {
            case Some(s) => s.onShutdown(callback)
            case None => ()
        }
    }

    // ========== 代理 Router 的常用方法 ==========

    /// GET 路由
    public func get(path: String, handler: HandlerFunc): Tang {
        this.router.get(path, handler)
        this
    }

    /// POST 路由
    public func post(path: String, handler: HandlerFunc): Tang {
        this.router.post(path, handler)
        this
    }

    /// PUT 路由
    public func put(path: String, handler: HandlerFunc): Tang {
        this.router.put(path, handler)
        this
    }

    /// DELETE 路由
    public func delete(path: String, handler: HandlerFunc): Tang {
        this.router.delete(path, handler)
        this
    }

    /// PATCH 路由
    public func patch(path: String, handler: HandlerFunc): Tang {
        this.router.patch(path, handler)
        this
    }

    /// HEAD 路由
    public func head(path: String, handler: HandlerFunc): Tang {
        this.router.head(path, handler)
        this
    }

    /// OPTIONS 路由
    public func options(path: String, handler: HandlerFunc): Tang {
        this.router.options(path, handler)
        this
    }

    /// 匹配所有 HTTP 方法
    public func all(path: String, handler: HandlerFunc): Tang {
        this.router.all(path, handler)
        this
    }

    /// 创建路由组
    public func group(path: String): Group {
        this.router.group(path)
    }
}

///
/// Tang 应用配置选项类型
///
public type TangOption = (Tang) -> Unit

///
/// 设置主机地址选项
///
public func withHost(host: String): TangOption {
    { app => app.setHost(host) }
}

///
/// 设置端口选项
///
public func withPort(port: UInt16): TangOption {
    { app => app.setPort(port) }
}

///
/// 显示 Banner 选项
///
public func withShowBanner(): TangOption {
    { app => app.setShowBanner(true) }
}

///
/// 隐藏 Banner 选项
///
public func withHideBanner(): TangOption {
    { app => app.setShowBanner(false) }
}

///
/// 显示路由选项
///
public func withShowRoutes(): TangOption {
    { app => app.setShowRoutes(true) }
}

///
/// 隐藏路由选项
///
public func withHideRoutes(): TangOption {
    { app => app.setShowRoutes(false) }
}
