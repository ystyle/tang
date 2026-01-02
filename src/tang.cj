package tang

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

    /// 启动应用（阻塞）
    public func listen(host!: String = "127.0.0.1", port!: UInt16 = 8080): Unit {
        this.host = host
        this.port = port

        // 打印 Banner
        if (this.printBanner) {
            this.router.printBanner(version: TANG_VERSION, port: this.port)
        }

        // 打印路由
        if (this.printRoutes) {
            this.router.printRoutes()
        }

        // 构建并启动服务器
        let server = ServerBuilder()
            .distributor(this.router)
            .addr(this.host)
            .port(this.port)
            .build()

        this.server = server
        server.serve()
    }

    /// 异步启动服务器
    public func listenAsync(host!: String = "127.0.0.1", port!: UInt16 = 8080): Unit {
        // TODO: 实现异步启动
        listen(host: host, port: port)
    }

    /// 停止服务器
    public func stop(): Unit {
        if (let Some(s) <- this.server) {
            // TODO: 调用 server.stop() 方法（如果 stdx 提供）
            this.server = None
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
