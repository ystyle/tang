package tang.middleware.staticfile

import std.collection.ArrayList
import std.fs.{Path, exists, FileInfo}
import stdx.net.http.{FileHandler, FileHandlerType}
import tang.{HandlerFunc, MiddlewareFunc, TangHttpContext}

/// 静态文件配置选项
public type StaticOption = (StaticConfig) -> Unit

/// 静态文件配置
public class StaticConfig {
    var root: String
    var prefix: String = "/"
    var browse: Bool = false
    var bufferSize: Int64 = 64 * 1024
    var indexFiles: ArrayList<String> = ArrayList()

    init(root: String) {
        this.root = root
        // 默认首页文件
        this.indexFiles.add("index.html")
        this.indexFiles.add("index.htm")
    }

    /// 设置 URL 前缀（默认："/"）
    public func setPrefix(prefix: String): Unit {
        this.prefix = prefix
    }

    /// 是否允许目录浏览（默认：false）
    public func setBrowse(browse: Bool): Unit {
        this.browse = browse
    }

    /// 设置缓冲区大小（默认：64KB）
    public func setBufferSize(size: Int64): Unit {
        this.bufferSize = size
    }

    /// 添加默认首页文件
    public func addIndexFile(name: String): Unit {
        this.indexFiles.add(name)
    }
}

/// 设置 URL 前缀的选项
public func withPrefix(prefix: String): StaticOption {
    return { config => config.setPrefix(prefix) }
}

/// 启用目录浏览的选项
public func withBrowse(): StaticOption {
    return { config => config.setBrowse(true) }
}

/// 设置缓冲区大小的选项
public func withBufferSize(size: Int64): StaticOption {
    return { config => config.setBufferSize(size) }
}

/// 添加默认首页文件的选项
public func withIndexFile(name: String): StaticOption {
    return { config => config.addIndexFile(name) }
}

/// 添加多个默认首页文件的选项
public func withIndexFiles(names: Array<String>): StaticOption {
    return { config =>
        for (name in names) {
            config.addIndexFile(name)
        }
    }
}

/// 静态文件服务处理器（带配置）
public func staticFiles(root: String, opts: Array<StaticOption>): HandlerFunc {
    let config = StaticConfig(root)
    for (opt in opts) {
        opt(config)
    }

    return { ctx: TangHttpContext =>
        let requestPath = ctx.request.url.path

        // 移除 URL 前缀
        var filePath = requestPath
        if (config.prefix != "/") {
            if (filePath.startsWith(config.prefix)) {
                filePath = filePath[config.prefix.size..filePath.size]
            }
        }

        // 移除开头的 /
        if (filePath.startsWith("/")) {
            filePath = filePath[1..filePath.size]
        }

        // 使用 Path 构建完整文件路径
        let rootPath = Path(config.root)
        let fullPath = if (filePath.isEmpty()) {
            rootPath.toString()
        } else {
            rootPath.join(filePath).toString()
        }

        // 检查路径是否存在以及类型
        if (exists(fullPath)) {
            let info = FileInfo(fullPath)
            if (info.isDirectory()) {
                // 是目录，查找首页文件
                var foundIndex: ?String = None
                for (indexFile in config.indexFiles) {
                    let indexPath = Path(fullPath).join(indexFile).toString()
                    if (exists(indexPath)) {
                        foundIndex = Some(indexPath)
                        break
                    }
                }

                if (let Some(idx) <- foundIndex) {
                    try {
                        let handler = FileHandler(idx, handlerType: DownLoad, bufferSize: config.bufferSize)
                        handler.handle(ctx.context)
                    } catch (_: Exception) {
                        ctx.responseBuilder.status(500).body("Internal Server Error\n")
                    }
                } else {
                    ctx.responseBuilder.status(404).body("404 Not Found\n")
                }
            } else {
                // 是文件，直接提供
                try {
                    let handler = FileHandler(fullPath, handlerType: DownLoad, bufferSize: config.bufferSize)
                    handler.handle(ctx.context)
                } catch (_: Exception) {
                    ctx.responseBuilder.status(500).body("Internal Server Error\n")
                }
            }
        } else {
            // 路径不存在，返回 404
            ctx.responseBuilder.status(404).body("404 Not Found\n")
        }
    }
}

/// 静态文件服务处理器（默认配置）
public func staticFiles(root: String): HandlerFunc {
    return staticFiles(root, Array<StaticOption>())
}

/// 静态文件中间件（路由前缀形式，带配置）
///
/// 为指定路由前缀添加静态文件服务
///
/// 示例：
/// ```cj
/// // /assets 路径映射到 /var/www/assets 目录
/// r.group("/assets", staticMiddleware("/var/www/assets"))
///
/// // 或使用中间件形式
/// let r = Router(use(
///     staticMiddleware("/var/www", [withPrefix("/static")])
/// ))
/// ```
public func staticMiddleware(root: String, opts: Array<StaticOption>): MiddlewareFunc {
    return { next =>
        let handler = staticFiles(root, opts)
        return { ctx =>
            // 先尝试静态文件
            handler(ctx)

            // 如果响应未设置（404），继续下一个处理器
            if (ctx.responseBuilder.build().status == 404) {
                next(ctx)
            }
        }
    }
}

/// 静态文件中间件（默认配置）
public func staticMiddleware(root: String): MiddlewareFunc {
    return staticMiddleware(root, Array<StaticOption>())
}
