package tang.middleware.staticfile

import std.collection.ArrayList
import std.fs.{Path, File, Directory, OpenMode}
import ystyle::tachyon.FileServer
import tang.{HandlerFunc, MiddlewareFunc, TangHttpContext, HttpStatusCode}

/// 静态文件配置选项
public type StaticOption = (StaticConfig) -> Unit

/// 静态文件配置
public class StaticConfig {
    var root: String
    var prefix: String = "/"
    var browse: Bool = false
    var maxAgeSeconds: Int64 = 0
    var allowRange: Bool = true
    var indexFiles: ArrayList<String> = ArrayList<String>()

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

    /// 缓存时长（秒），>0 时输出 Cache-Control
    public func setMaxAge(seconds: Int64): Unit {
        this.maxAgeSeconds = seconds
    }

    /// 是否支持 Range 请求（默认 true）
    public func setAllowRange(allow: Bool): Unit {
        this.allowRange = allow
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

/// 设置缓存时长的选项（秒）
public func withMaxAge(seconds: Int64): StaticOption {
    return { config => config.setMaxAge(seconds) }
}

/// 关闭 Range 支持的选项
public func withoutRange(): StaticOption {
    return { config => config.setAllowRange(false) }
}

/// 添加首页文件的选项
public func withIndexFile(name: String): StaticOption {
    return { config => config.addIndexFile(name) }
}

/// 静态文件处理器
///
/// 实现方式是复用 tachyon 的 FileServer（std.fs 实现）：
/// 目录索引、Range、If-Modified-Since、路径穿越防护都由它负责，
/// 这里只做配置映射与「目录浏览」这一项 FileServer 不提供的能力。
public func staticFiles(root: String, opts!: Array<StaticOption>): HandlerFunc {
    let config = StaticConfig(root)
    for (opt in opts) {
        opt(config)
    }
    return staticFilesWithConfig(config)
}

public func staticFiles(root: String): HandlerFunc {
    return staticFiles(root, opts: Array<StaticOption>())
}

func staticFilesWithConfig(config: StaticConfig): HandlerFunc {
    // 每次调用构造一个 FileServer：它内部只是保存配置，开销可忽略
    let fs = FileServer(config.root)
    for (name in config.indexFiles) {
        fs.addIndexName(name)
    }
    fs.setAllowRange(config.allowRange)
    fs.setMaxAge(config.maxAgeSeconds)
    let prefix = config.prefix
    let browse = config.browse

    return { ctx: TangHttpContext =>
        let raw = ctx.raw
        // 前缀剥离交给 FileServer（mountPrefix 为空时直接用 path）
        if (prefix == "/" || prefix.isEmpty()) {
            fs.handler(raw)
        } else {
            fs.serve(raw, prefix)
        }
        // 目录浏览：FileServer 对"目录且无 index"回 404，这里补一个简单列表
        if (browse && raw.statusCode() == HttpStatusCode.STATUS_NOT_FOUND) {
            renderDirectoryListing(ctx, config.root)
        }
    }
}

/// 目录浏览（简单实现：列名字 + 大小）
func renderDirectoryListing(ctx: TangHttpContext, root: String): Unit {
    var rel = ctx.path()
    let prefixLen = rel.size
    let full = if (rel == "/" || rel.isEmpty()) {
        root
    } else {
        root + (if (rel.startsWith("/")) { rel } else { "/" + rel })
    }
    var entries: ArrayList<String> = ArrayList<String>()
    try {
        let dir = Directory.readFrom(Path(full))
        for (e in dir) {
            let name = e.name
            let suffix = if (e.isDirectory()) { "/" } else { "" }
            entries.add("<li><a href=\"" + rel + (if (rel.endsWith("/")) { "" } else { "/" }) +
                name + suffix + "\">" + name + suffix + "</a></li>")
        }
    } catch (e: Exception) {
        ctx.responseBuilder.status(HttpStatusCode.STATUS_NOT_FOUND).body("404 Not Found")
        return
    }
    var sb = StringBuilder()
    sb.append("<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Index of ")
    sb.append(rel)
    sb.append("</title></head><body><h1>Index of ")
    sb.append(rel)
    sb.append("</h1><ul>")
    for (line in entries) {
        sb.append(line)
    }
    sb.append("</ul></body></html>")
    ctx.responseBuilder.status(HttpStatusCode.STATUS_OK)
    ctx.responseBuilder.header("Content-Type", "text/html; charset=utf-8")
    ctx.responseBuilder.body(sb.toString())
}

/// 静态文件中间件（路由前缀形式，带配置）
public func staticMiddleware(root: String, opts: Array<StaticOption>): MiddlewareFunc {
    return { next =>
        let handler = staticFiles(root, opts: opts)
        return { ctx =>
            // 先尝试静态文件
            handler(ctx)
            // 没命中（404）就交给后续处理器
            if (ctx.raw.statusCode() == HttpStatusCode.STATUS_NOT_FOUND) {
                next(ctx)
            }
        }
    }
}

/// 静态文件中间件（默认配置）
public func staticMiddleware(root: String): MiddlewareFunc {
    return staticMiddleware(root, Array<StaticOption>())
}
