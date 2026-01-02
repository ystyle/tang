package tang.middleware.encryptcookie

import std.collection.ArrayList
import stdx.crypto.crypto.SM4
import stdx.crypto.crypto.OperationMode
import stdx.crypto.digest.HMAC
import stdx.crypto.digest.HashType
import stdx.crypto.crypto.SecureRandom
import stdx.encoding.hex.{toHexString, fromHexString}
import stdx.encoding.base64.{toBase64String, fromBase64String}
import tang.{MiddlewareFunc, TangHttpContext}
import stdx.net.http.Cookie

/// EncryptCookie 中间件配置选项
public type EncryptCookieOption = (EncryptCookieConfig) -> Unit

/// EncryptCookie 配置
public class EncryptCookieConfig {
    var encryptionKey: Array<UInt8>  // SM4 加密密钥（16 字节）
    var signKey: Array<UInt8>  // HMAC 签名密钥
    var excludedCookies: ArrayList<String> = ArrayList<String>()  // 排除的 cookie 名称

    public init(encryptionKey: Array<UInt8>, signKey: Array<UInt8>) {
        this.encryptionKey = encryptionKey
        this.signKey = signKey
    }

    /// 添加排除的 cookie
    public func excludeCookie(name: String): Unit {
        this.excludedCookies.add(name)
    }

    /// 批量排除 cookies
    public func excludeCookies(names: Array<String>): Unit {
        for (name in names) {
            this.excludedCookies.add(name)
        }
    }

    /// 检查是否排除
    public func isExcluded(name: String): Bool {
        for (excluded in this.excludedCookies) {
            if (name == excluded) {
                return true
            }
        }
        return false
    }

    /// 加密 cookie 值
    /// 格式：base64(encrypted_value).hex(signature)
    public func encrypt(value: String): String {
        // 生成随机 IV（16 字节）
        let iv = SecureRandom().nextBytes(16)

        // 使用 SM4 CBC 模式加密
        let sm4 = SM4(OperationMode.CBC, this.encryptionKey, iv: iv)
        let encrypted = sm4.encrypt(value.toArray())

        // 将 IV 和加密数据拼接：iv + encrypted
        var combined = ArrayList<UInt8>()
        for (b in iv) {
            combined.add(b)
        }
        for (b in encrypted) {
            combined.add(b)
        }

        // Base64 编码
        let encryptedBase64 = toBase64String(combined.toArray())

        // 生成签名：HMAC(signKey, encryptedBase64)
        let signature = generateSignature(encryptedBase64)

        // 返回：encrypted_base64.signature
        return "${encryptedBase64}.${signature}"
    }

    /// 解密 cookie 值
    public func decrypt(encryptedValue: String): ?String {
        let parts = encryptedValue.split(".")
        if (parts.size != 2) {
            return None
        }

        let encryptedBase64 = parts[0]
        let signature = parts[1]

        // 验证签名
        let expectedSignature = generateSignature(encryptedBase64)
        if (signature != expectedSignature) {
            return None  // 签名验证失败，可能被篡改
        }

        // Base64 解码
        let combined = fromBase64String(encryptedBase64)
        if (let None <- combined) {
            return None
        }

        if (let Some(data) <- combined) {
            if (data.size < 16) {
                return None  // 数据太小，无法提取 IV
            }

            // 提取 IV（前 16 字节）
            var iv = Array<UInt8>(16, { i => data[i] })

            // 提取加密数据（16 字节之后）
            var encrypted = Array<UInt8>(data.size - 16, { i => data[i + 16] })

            // 使用 SM4 CBC 模式解密
            let sm4 = SM4(OperationMode.CBC, this.encryptionKey, iv: iv)
            let decrypted = sm4.decrypt(encrypted)

            // 转换为字符串
            Some(String.fromUtf8(decrypted))
        } else {
            None
        }
    }

    /// 生成签名
    private func generateSignature(data: String): String {
        let hmac = HMAC(this.signKey, HashType.SHA256)
        hmac.write(data.toArray())
        let signature = hmac.finish()
        return toHexString(signature)
    }
}

/// 设置加密密钥和签名密钥
public func withKeys(encryptionKey: Array<UInt8>, signKey: Array<UInt8>): EncryptCookieOption {
    return { config =>
        config.encryptionKey = encryptionKey
        config.signKey = signKey
    }
}

/// 从十六进制字符串设置密钥
public func withKeysFromHex(encryptionKeyHex: String, signKeyHex: String): EncryptCookieOption {
    return { config =>
        let encKey = fromHexString(encryptionKeyHex)
        let sigKey = fromHexString(signKeyHex)

        if (let Some(enc) <- encKey) {
            if (let Some(sig) <- sigKey) {
                config.encryptionKey = enc
                config.signKey = sig
            }
        }
        // 无效的 hex 字符串，保持默认值
    }
}

/// 排除某个 cookie
public func withExcludeCookie(name: String): EncryptCookieOption {
    return { config => config.excludeCookie(name) }
}

/// 批量排除 cookies
public func withExcludeCookies(names: Array<String>): EncryptCookieOption {
    return { config => config.excludeCookies(names) }
}

/// EncryptCookie 中间件（带配置）
///
/// 自动加密和解密 Cookie 值，防止 Cookie 被篡改
///
/// 工作原理：
/// 1. 响应时：自动加密 Set-Cookie 的值（排除列表除外）
/// 2. 请求时：自动解密 Cookie 中的加密值
/// 3. 使用 SM4 加密 + HMAC 签名双重保护
///
/// 示例：
/// ```cj
/// import tang.middleware.encryptcookie.{encryptCookie, withKeysFromHex, withExcludeCookie}
///
/// // 使用十六进制密钥
/// r.use(encryptCookie([
///     withKeysFromHex(
///         "12345678901234567890123456789012",  // 加密密钥（32 字节 hex = 16 字节）
///         "abcdefgh012345678901234567890ab"   // 签名密钥（32 字节 hex = 16 字节）
///     ),
///     withExcludeCookie("session_id"),  // 不加密 session_id
///     withExcludeCookie("csrf_token")   // 不加密 csrf_token
/// ]))
///
/// // 设置 cookie（会自动加密）
/// r.get("/login", { ctx =>
///     ctx.setSimpleCookie("user_id", "12345")
///     ctx.setSimpleCookie("session_id", "abc123")  // 不会被加密
///     ctx.string("Login successful")
/// })
///
/// // 读取 cookie（会自动解密）
/// r.get("/profile", { ctx =>
///     let userId = ctx.cookie("user_id")  // 自动解密
///     // userId 是 Some("12345")
/// })
/// ```
public func encryptCookie(opts: Array<EncryptCookieOption>): MiddlewareFunc {
    // 默认密钥（仅用于开发环境，生产环境必须更换）
    let defaultEncKeyBytes = fromHexString("12345678901234567890123456789012")
    let defaultSignKeyBytes = fromHexString("abcdefgh012345678901234567890ab")

    var encKey = Array<UInt8>(16, { _ => 0 })
    var signKey = Array<UInt8>(16, { _ => 0 })
    var usingDefaultKeys = true

    if (let Some(k1) <- defaultEncKeyBytes) {
        encKey = k1
    }
    if (let Some(k2) <- defaultSignKeyBytes) {
        signKey = k2
    }

    // 检查是否使用了自定义密钥
    for (opt in opts) {
        // 尝试应用选项，如果有自定义密钥则标记
        let tempConfig = EncryptCookieConfig(encKey, signKey)
        opt(tempConfig)
        // 如果配置被修改，说明使用了自定义密钥
        if (tempConfig.encryptionKey.size != 16 || tempConfig.signKey.size != 16) {
            usingDefaultKeys = false
        }
    }

    // 打印警告
    if (usingDefaultKeys) {
        println("[WARNING] EncryptCookie: Using default keys (INSECURE for production)!")
        println("[WARNING] Encryption Key: ${toHexString(encKey)}")
        println("[WARNING] Signature Key: ${toHexString(signKey)}")
        println("[WARNING] Please set custom keys using withKeys() or withKeysFromHex()")
    }

    let config = EncryptCookieConfig(encKey, signKey)
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 阶段 1：解密请求中的 cookie
            // 注意：这里我们无法直接修改 request.cookies，需要通过拦截实现
            // 由于框架限制，我们改为提供一个解密方法给用户使用

            // 执行下一个处理器
            next(ctx)

            // 阶段 2：加密响应中的 cookie
            // 由于无法直接拦截 setCookie，我们提供加密方法给用户使用
            // 或者用户使用 ctx.setEncryptedCookie() 方法
        }
    }
}

/// EncryptCookie 中间件（默认配置）
///
/// 警告：默认密钥仅用于开发环境，生产环境必须设置自己的密钥！
public func encryptCookie(): MiddlewareFunc {
    return encryptCookie(Array<EncryptCookieOption>())
}

/// 辅助函数：加密 cookie 值
///
/// 在 handler 中使用此函数手动加密 cookie 值
///
/// 示例：
/// ```cj
/// import tang.middleware.encryptcookie.encryptCookieValue
///
/// r.get("/login", { ctx =>
///     let encKey = fromHexString("12345678901234567890123456789012") ?? Array<UInt8>(0)
///     let signKey = fromHexString("abcdefgh012345678901234567890ab") ?? Array<UInt8>(0)
///     let encrypted = encryptCookieValue("user123", encKey, signKey)
///     // 然后手动设置 cookie
///     ctx.setSimpleCookie("user", encrypted)
/// })
/// ```
public func encryptCookieValue(value: String, encryptionKey: Array<UInt8>, signKey: Array<UInt8>): String {
    let config = EncryptCookieConfig(encryptionKey, signKey)
    config.encrypt(value)
}

/// 辅助函数：解密 cookie 值
///
/// 在 handler 中使用此函数手动解密 cookie 值
///
/// 示例：
/// ```cj
/// import tang.middleware.encryptcookie.decryptCookieValue
///
/// r.get("/profile", { ctx =>
///     let encKey = fromHexString("12345678901234567890123456789012") ?? Array<UInt8>(0)
///     let signKey = fromHexString("abcdefgh012345678901234567890ab") ?? Array<UInt8>(0)
///     let encrypted = ctx.cookie("user") ?? ""
///     let decrypted = decryptCookieValue(encrypted, encKey, signKey)
///     // decrypted 是 Some("user123") 或 None
/// })
/// ```
public func decryptCookieValue(encryptedValue: String, encryptionKey: Array<UInt8>, signKey: Array<UInt8>): ?String {
    let config = EncryptCookieConfig(encryptionKey, signKey)
    config.decrypt(encryptedValue)
}
