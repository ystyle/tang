package tang.middleware.cors

import std.collection.ArrayList
import tang.{MiddlewareFunc, TangHttpContext}

/// CORS 配置选项
public type CorsOption = (CorsConfig) -> Unit

/// CORS 配置类
public class CorsConfig {
    var allowedOrigins: ArrayList<String> = ArrayList<String>()
    var allowedMethods: ArrayList<String> = ArrayList<String>()
    var allowedHeaders: ArrayList<String> = ArrayList<String>()
    var exposedHeaders: ArrayList<String> = ArrayList<String>()
    var allowCredentials: Bool = false
    var maxAge: Int64 = 86400 // 24 小时

    /// 添加允许的来源
    public func addOrigin(origin: String): Unit {
        this.allowedOrigins.add(origin)
    }

    /// 添加允许的方法
    public func addMethod(method: String): Unit {
        this.allowedMethods.add(method)
    }

    /// 添加允许的请求头
    public func addHeader(header: String): Unit {
        this.allowedHeaders.add(header)
    }

    /// 添加暴露的响应头
    public func addExposedHeader(header: String): Unit {
        this.exposedHeaders.add(header)
    }

    /// 设置是否允许携带凭证
    public func setAllowCredentials(allow: Bool): Unit {
        this.allowCredentials = allow
    }

    /// 设置预检请求缓存时间（秒）
    public func setMaxAge(age: Int64): Unit {
        this.maxAge = age
    }
}

/// 允许所有来源的选项
public func withAllowAllOrigins(): CorsOption {
    return { config => config.addOrigin("*") }
}

/// 允许指定来源的选项
public func withAllowedOrigins(origins: Array<String>): CorsOption {
    return { config =>
        for (origin in origins) {
            config.addOrigin(origin)
        }
    }
}

/// 允许所有常用方法的选项
public func withAllowCommonMethods(): CorsOption {
    return { config =>
        config.addMethod("GET")
        config.addMethod("POST")
        config.addMethod("PUT")
        config.addMethod("DELETE")
        config.addMethod("OPTIONS")
        config.addMethod("PATCH")
    }
}

/// 允许指定方法的选项
public func withAllowedMethods(methods: Array<String>): CorsOption {
    return { config =>
        for (method in methods) {
            config.addMethod(method)
        }
    }
}

/// 允许所有请求头的选项
public func withAllowAllHeaders(): CorsOption {
    return { config => config.addHeader("*") }
}

/// 允许指定请求头的选项
public func withAllowedHeaders(headers: Array<String>): CorsOption {
    return { config =>
        for (header in headers) {
            config.addHeader(header)
        }
    }
}

/// 允许携带凭证的选项
public func withAllowCredentials(): CorsOption {
    return { config => config.setAllowCredentials(true) }
}

/// 设置最大缓存时间的选项
public func withMaxAge(age: Int64): CorsOption {
    return { config => config.setMaxAge(age) }
}

/// 默认的 CORS 配置（允许所有）
public func defaultCorsConfig(): CorsConfig {
    let config = CorsConfig()
    config.addOrigin("*")
    config.addMethod("GET")
    config.addMethod("POST")
    config.addMethod("PUT")
    config.addMethod("DELETE")
    config.addMethod("OPTIONS")
    config.addHeader("*")
    return config
}

/// CORS 中间件工厂函数（带配置）
public func newCors(opts: Array<CorsOption>): MiddlewareFunc {
    let config = defaultCorsConfig()
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            let request = ctx.request
            let method = request.method.toString()

            // 获取请求来源
            let origin = request.headers.getFirst("Origin")

            // 如果没有 Origin 头，继续处理
            if (let None <- origin) {
                next(ctx)
                return
            }

            // 检查是否是预检请求（OPTIONS 且有 Access-Control-Request-Method 头）
            let isPreflight = method == "OPTIONS" && match (request.headers.getFirst("Access-Control-Request-Method")) {
                case Some(_) => true
                case None => false
            }

            // 设置 Access-Control-Allow-Origin
            if (config.allowedOrigins.contains("*")) {
                ctx.responseBuilder.header("Access-Control-Allow-Origin", "*")
            } else if (config.allowedOrigins.contains(origin ?? "")) {
                ctx.responseBuilder.header("Access-Control-Allow-Origin", origin ?? "")
            }

            // 设置 Access-Control-Allow-Credentials
            if (config.allowCredentials) {
                ctx.responseBuilder.header("Access-Control-Allow-Credentials", "true")
            }

            // 设置 Access-Control-Expose-Headers
            if (config.exposedHeaders.size > 0) {
                let headers = String.join(config.exposedHeaders.toArray(), delimiter: ", ")
                ctx.responseBuilder.header("Access-Control-Expose-Headers", headers)
            }

            // 处理预检请求（OPTIONS）
            if (isPreflight) {
                // 设置 Access-Control-Allow-Methods
                if (config.allowedMethods.size > 0) {
                    let methods = String.join(config.allowedMethods.toArray(), delimiter: ", ")
                    ctx.responseBuilder.header("Access-Control-Allow-Methods", methods)
                }

                // 设置 Access-Control-Allow-Headers
                if (config.allowedHeaders.size > 0) {
                    let headers = String.join(config.allowedHeaders.toArray(), delimiter: ", ")
                    ctx.responseBuilder.header("Access-Control-Allow-Headers", headers)
                } else if (let Some(h) <- request.headers.getFirst("Access-Control-Request-Headers")) {
                    // 如果没有配置，回退到请求头中的值
                    ctx.responseBuilder.header("Access-Control-Allow-Headers", h)
                }

                // 设置 Access-Control-Max-Age
                if (config.maxAge > 0) {
                    ctx.responseBuilder.header("Access-Control-Max-Age", "${config.maxAge}")
                }

                // 设置 Vary 头
                ctx.responseBuilder.header("Vary", "Origin")
                ctx.responseBuilder.header("Vary", "Access-Control-Request-Method")
                ctx.responseBuilder.header("Vary", "Access-Control-Request-Headers")

                // 预检请求成功返回 204，不调用 next(ctx)
                ctx.responseBuilder.status(204).body("")
                return
            }

            // 非预检请求，设置 Vary 头后继续处理
            if (!config.allowedOrigins.contains("*")) {
                ctx.responseBuilder.header("Vary", "Origin")
            }

            // 继续处理请求
            next(ctx)
        }
    }
}

/// CORS 中间件工厂函数（默认配置）
public func newCors(): MiddlewareFunc {
    let config = defaultCorsConfig()
    return { next =>
        return { ctx: TangHttpContext =>
            let request = ctx.request
            let method = request.method.toString()

            // 获取请求来源
            let origin = request.headers.getFirst("Origin")

            // 如果没有 Origin 头，继续处理
            if (let None <- origin) {
                next(ctx)
                return
            }

            // 检查是否是预检请求（OPTIONS 且有 Access-Control-Request-Method 头）
            let isPreflight = method == "OPTIONS" && match (request.headers.getFirst("Access-Control-Request-Method")) {
                case Some(_) => true
                case None => false
            }

            // 设置 Access-Control-Allow-Origin
            if (config.allowedOrigins.contains("*")) {
                ctx.responseBuilder.header("Access-Control-Allow-Origin", "*")
            } else if (config.allowedOrigins.contains(origin ?? "")) {
                ctx.responseBuilder.header("Access-Control-Allow-Origin", origin ?? "")
            }

            // 设置 Access-Control-Allow-Credentials
            if (config.allowCredentials) {
                ctx.responseBuilder.header("Access-Control-Allow-Credentials", "true")
            }

            // 设置 Access-Control-Expose-Headers
            if (config.exposedHeaders.size > 0) {
                let headers = String.join(config.exposedHeaders.toArray(), delimiter: ", ")
                ctx.responseBuilder.header("Access-Control-Expose-Headers", headers)
            }

            // 处理预检请求（OPTIONS）
            if (isPreflight) {
                // 设置 Access-Control-Allow-Methods
                if (config.allowedMethods.size > 0) {
                    let methods = String.join(config.allowedMethods.toArray(), delimiter: ", ")
                    ctx.responseBuilder.header("Access-Control-Allow-Methods", methods)
                }

                // 设置 Access-Control-Allow-Headers
                if (config.allowedHeaders.size > 0) {
                    let headers = String.join(config.allowedHeaders.toArray(), delimiter: ", ")
                    ctx.responseBuilder.header("Access-Control-Allow-Headers", headers)
                } else if (let Some(h) <- request.headers.getFirst("Access-Control-Request-Headers")) {
                    // 如果没有配置，回退到请求头中的值
                    ctx.responseBuilder.header("Access-Control-Allow-Headers", h)
                }

                // 设置 Access-Control-Max-Age
                if (config.maxAge > 0) {
                    ctx.responseBuilder.header("Access-Control-Max-Age", "${config.maxAge}")
                }

                // 设置 Vary 头
                ctx.responseBuilder.header("Vary", "Origin")
                ctx.responseBuilder.header("Vary", "Access-Control-Request-Method")
                ctx.responseBuilder.header("Vary", "Access-Control-Request-Headers")

                // 预检请求成功返回 204，不调用 next(ctx)
                ctx.responseBuilder.status(204).body("")
                return
            }

            // 非预检请求，设置 Vary 头后继续处理
            if (!config.allowedOrigins.contains("*")) {
                ctx.responseBuilder.header("Vary", "Origin")
            }

            // 继续处理请求
            next(ctx)
        }
    }
}

/// 便捷函数：创建允许所有来源的 CORS 中间件
public func corsAllowAll(): MiddlewareFunc {
    return newCors()
}
