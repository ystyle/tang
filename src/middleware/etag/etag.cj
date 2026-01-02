package tang.middleware.etag

import stdx.crypto.digest.{SHA256, MD5}
import stdx.encoding.hex.toHexString
import stdx.net.http.{HttpStatusCode}
import tang.{MiddlewareFunc, TangHttpContext}
import std.collection.ArrayList

/// ETag 生成算法
public enum ETagAlgorithm {
    | SHA256  // 使用 SHA256 哈希（默认，更安全）
    | MD5     // 使用 MD5 哈希（更快，但安全性较低）
}

/// ETag 中间件配置选项
public type ETagOption = (ETagConfig) -> Unit

/// ETag 配置
public class ETagConfig {
    var algorithm: ETagAlgorithm = ETagAlgorithm.SHA256  // 哈希算法
    var weak: Bool = false  // 是否使用弱 ETag（W/ 前缀）
    var excludePaths: ArrayList<String> = ArrayList<String>()  // 排除的路径

    public init() {}

    /// 设置哈希算法
    public func setAlgorithm(algo: ETagAlgorithm): Unit {
        this.algorithm = algo
    }

    /// 设置是否使用弱 ETag
    /// 弱 ETag 以 "W/" 开头，表示语义上相同但字节不同
    public func setWeak(weak: Bool): Unit {
        this.weak = weak
    }

    /// 添加排除的路径
    public func addExcludePath(path: String): Unit {
        this.excludePaths.add(path)
    }

    /// 检查路径是否被排除
    public func isExcluded(path: String): Bool {
        for (excludePath in this.excludePaths) {
            if (path.startsWith(excludePath)) {
                return true
            }
        }
        return false
    }

    /// 生成 ETag
    public func generateETag(content: Array<Byte>): String {
        let hash = calcHash(content, this.algorithm)
        let hashString = toHexString(hash)

        // 添加弱 ETag 前缀（如果启用）
        if (this.weak) {
            return "W/\"${hashString}\""
        } else {
            return "\"${hashString}\""
        }
    }
}

/// 计算哈希
func calcHash(content: Array<Byte>, algorithm: ETagAlgorithm): Array<Byte> {
    match (algorithm) {
        case ETagAlgorithm.SHA256 =>
            let sha256 = SHA256()
            sha256.write(content)
            sha256.finish()

        case ETagAlgorithm.MD5 =>
            let md5 = MD5()
            md5.write(content)
            md5.finish()
    }
}

/// 设置哈希算法为 SHA256
public func withSHA256(): ETagOption {
    return { config => config.setAlgorithm(ETagAlgorithm.SHA256) }
}

/// 设置哈希算法为 MD5
public func withMD5(): ETagOption {
    return { config => config.setAlgorithm(ETagAlgorithm.MD5) }
}

/// 设置为弱 ETag
public func withWeak(): ETagOption {
    return { config => config.setWeak(true) }
}

/// 添加排除路径
public func withExcludePath(path: String): ETagOption {
    return { config => config.addExcludePath(path) }
}

/// 批量添加排除路径
public func withExcludePaths(paths: ArrayList<String>): ETagOption {
    return { config =>
        for (path in paths) {
            config.addExcludePath(path)
        }
    }
}

/// ETag 中间件（带配置）
///
/// 自动生成 ETag 响应头，支持缓存验证
///
/// 注意：此中间件仅为基于路径和查询参数生成简单的 ETag
/// 完整的 ETag 实现（基于响应体内容）需要在业务层手动生成
///
/// 示例：
/// ```cj
/// // 使用默认配置（SHA256）
/// r.use(etag())
///
/// // 使用 MD5（更快）
/// r.use(etag([withMD5()]))
///
/// // 使用弱 ETag（适用于动态内容）
/// r.use(etag([withWeak()]))
///
/// // 排除某些路径
/// r.use(etag([
///     withExcludePaths(["/api/", "/upload/"])
/// ]))
///
/// // 组合配置
/// r.use(etag([
///     withMD5(),
///     withWeak(),
///     withExcludePath("/api/")
/// ]))
/// ```
public func etag(opts: Array<ETagOption>): MiddlewareFunc {
    let config = ETagConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 检查路径是否被排除
            if (config.isExcluded(ctx.path())) {
                next(ctx)
                return
            }

            // 生成简单的 ETag（基于路径）
            let path = ctx.path()
            let query = ctx.request.url.query
            let content = "${path}?${query}".toArray()

            // 生成 ETag
            let etagValue = config.generateETag(content)

            // 设置 ETag 响应头
            ctx.responseBuilder.header("ETag", etagValue)

            // 继续处理请求
            next(ctx)
        }
    }
}

/// ETag 中间件（默认配置）
public func etag(): MiddlewareFunc {
    return etag(Array<ETagOption>())
}
