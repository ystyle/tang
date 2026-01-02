package tang.middleware.session

import std.collection.HashMap
import std.collection.ArrayList
import std.sync.Mutex
import std.time.DateTime
import stdx.crypto.crypto.SecureRandom
import stdx.encoding.hex.toHexString
import stdx.net.http.Cookie
import tang.{MiddlewareFunc, TangHttpContext}

/// Session 数据接口
public interface SessionData {
    func get(key: String): ?String
    func set(key: String, value: String): Unit
    func remove(key: String): Unit
    func clear(): Unit
    func keys(): Array<String>
}

/// Session 接口
public interface Session {
    prop id: String
    prop data: SessionData
    func isNew(): Bool
    func touch(): Unit  // 更新访问时间
}

/// Session 存储接口
public interface SessionStore {
    func get(sessionID: String): ?Session
    func set(session: Session): Unit
    func destroy(sessionID: String): Unit
    func gc(maxLifetime: Int64): Unit  // 垃圾回收，清理过期 session
    func generateSessionID(): String  // 生成新的 session ID
}

/// 内存 Session 数据实现
public class MemorySessionData <: SessionData {
    var data: HashMap<String, String> = HashMap<String, String>()

    public func get(key: String): ?String {
        if (this.data.contains(key)) {
            Some(this.data[key])
        } else {
            None
        }
    }

    public func set(key: String, value: String): Unit {
        this.data[key] = value
    }

    public func remove(key: String): Unit {
        this.data.remove(key)
    }

    public func clear(): Unit {
        this.data.clear()
    }

    public func keys(): Array<String> {
        this.data.keys().toArray()
    }
}

/// 内存 Session 实现
public class MemorySession <: Session {
    var _id: String
    var _data: SessionData
    var createdAt: Int64
    var accessedAt: Int64
    var _isNew: Bool

    public init(id: String) {
        this._id = id
        this._data = MemorySessionData()
        this.createdAt = DateTime.now().toUnixTimeStamp().toSeconds()
        this.accessedAt = this.createdAt
        this._isNew = true
    }

    public prop id: String {
        get() {
            this._id
        }
    }

    public prop data: SessionData {
        get() {
            this._data
        }
    }

    public func isNew(): Bool {
        this._isNew
    }

    public func touch(): Unit {
        this.accessedAt = DateTime.now().toUnixTimeStamp().toSeconds()
        this._isNew = false
    }
}

/// 内存 Session 存储
public class MemoryStore <: SessionStore {
    var sessions: HashMap<String, MemorySession> = HashMap<String, MemorySession>()
    let mu: Mutex = Mutex()

    public init() {}

    public func get(sessionID: String): ?Session {
        this.mu.lock()
        if (this.sessions.contains(sessionID)) {
            let s = this.sessions[sessionID]
            this.mu.unlock()
            s as Session
        } else {
            this.mu.unlock()
            None
        }
    }

    public func set(session: Session): Unit {
        this.mu.lock()
        // 通过接口属性访问 session.id
        if (let Some(memSession) <- (session as MemorySession)) {
            this.sessions[memSession.id] = memSession
        }
        this.mu.unlock()
    }

    public func destroy(sessionID: String): Unit {
        this.mu.lock()
        this.sessions.remove(sessionID)
        this.mu.unlock()
    }

    public func gc(maxLifetime: Int64): Unit {
        this.mu.lock()
        let now = DateTime.now().toUnixTimeStamp().toSeconds()

        var toRemove: ArrayList<String> = ArrayList<String>()
        for ((id, session) in this.sessions) {
            if (now - session.accessedAt > maxLifetime) {
                toRemove.add(id)
            }
        }

        for (id in toRemove) {
            this.sessions.remove(id)
        }

        this.mu.unlock()
    }

    /// 生成新的 session ID
    public func generateSessionID(): String {
        let randomBytes = SecureRandom().nextBytes(32)
        toHexString(randomBytes)
    }
}

/// Session 中间件配置选项
public type SessionOption = (SessionConfig) -> Unit

/// Session 配置
public class SessionConfig {
    var store: SessionStore
    var expiration: Int64 = 86400  // session 过期时间（秒，默认 24 小时）
    var cookieName: String = "session"
    var cookiePath: String = "/"
    var cookieDomain: String = ""  // Cookie domain（空字符串表示不设置）
    var cookieSecure: Bool = false
    var cookieHttpOnly: Bool = true

    public init(store: SessionStore) {
        this.store = store
    }

    /// 设置过期时间
    public func setExpiration(seconds: Int64): Unit {
        this.expiration = seconds
    }

    /// 设置 Cookie 名称
    public func setCookieName(name: String): Unit {
        this.cookieName = name
    }

    /// 设置 Cookie 路径
    public func setCookiePath(path: String): Unit {
        this.cookiePath = path
    }

    /// 设置 Cookie 域名
    public func setCookieDomain(domain: String): Unit {
        this.cookieDomain = domain
    }

    /// 设置 Cookie Secure 标志
    public func setCookieSecure(secure: Bool): Unit {
        this.cookieSecure = secure
    }

    /// 设置 Cookie HttpOnly 标志
    public func setCookieHttpOnly(httpOnly: Bool): Unit {
        this.cookieHttpOnly = httpOnly
    }

    /// 从 Cookie 中获取 session ID
    public func getSessionIDFromCookie(ctx: TangHttpContext): ?String {
        ctx.cookie(this.cookieName)
    }
}

/// 设置存储
public func withStore(store: SessionStore): SessionOption {
    return { config => config.store = store }
}

/// 设置过期时间
public func withExpiration(seconds: Int64): SessionOption {
    return { config => config.setExpiration(seconds) }
}

/// 设置 Cookie 名称
public func withCookieName(name: String): SessionOption {
    return { config => config.setCookieName(name) }
}

/// 设置 Cookie 路径
public func withCookiePath(path: String): SessionOption {
    return { config => config.setCookiePath(path) }
}

/// 设置 Cookie 域名
public func withCookieDomain(domain: String): SessionOption {
    return { config => config.setCookieDomain(domain) }
}

/// 设置 Cookie Secure 标志
public func withCookieSecure(secure: Bool): SessionOption {
    return { config => config.setCookieSecure(secure) }
}

/// 设置 Cookie HttpOnly 标志
public func withCookieHttpOnly(httpOnly: Bool): SessionOption {
    return { config => config.setCookieHttpOnly(httpOnly) }
}

/// Session 中间件（带配置）
///
/// 提供会话管理功能
///
/// 工作原理：
/// 1. 从 Cookie 中读取 session ID
/// 2. 从存储中加载 session
/// 3. 如果没有 session，创建新的
/// 4. 将 session 存储到 context 中
/// 5. 响应时保存 session 并设置 Cookie
///
/// 示例：
/// ```cj
/// import tang.middleware.session.{session, withExpiration}
///
/// r.use(session([
///     withExpiration(3600)  // 1 小时过期
/// ]))
///
/// // 使用 session
/// r.get("/login", { ctx =>
///     let session = ctx.session()
///     session.data.set("userId", "123")
///     ctx.json(HashMap<String, String>([
///         ("message", "Login successful")
///     ]))
/// })
///
/// r.get("/profile", { ctx =>
///     let session = ctx.session()
///     let userId = session.data.get("userId")
///     // ...
/// })
/// ```
public func session(opts: Array<SessionOption>): MiddlewareFunc {
    // 默认使用内存存储
    let defaultStore = MemoryStore()

    let config = SessionConfig(defaultStore)
    for (opt in opts) {
        opt(config)
    }

    return { next =>
        return { ctx: TangHttpContext =>
            // 获取或创建 session
            let sessionID = config.getSessionIDFromCookie(ctx)
            let session = if (let Some(id) <- sessionID) {
                let loadedSession = config.store.get(id)
                if (let Some(s) <- loadedSession) {
                    s.touch()
                    s
                } else {
                    // session 不存在，创建新的
                    let newID = config.store.generateSessionID()
                    let newSession = MemorySession(newID)
                    config.store.set(newSession)
                    newSession
                }
            } else {
                // 没有 Cookie，创建新的 session
                let newID = config.store.generateSessionID()
                let newSession = MemorySession(newID)
                config.store.set(newSession)
                newSession
            }

            // 将 session 存储到 context
            ctx.kvSet("session", session)

            // 执行下一个处理器
            next(ctx)

            // 保存 session 并设置 Cookie
            config.store.set(session)

            // 构建 Cookie 对象
            var cookie = Cookie(
                config.cookieName,
                session.id,
                path: config.cookiePath,
                domain: config.cookieDomain,
                secure: config.cookieSecure,
                httpOnly: config.cookieHttpOnly
            )

            // 使用框架的 setCookie 方法
            ctx.setCookie(cookie)
        }
    }
}

/// Session 中间件（默认配置）
public func session(): MiddlewareFunc {
    return session(Array<SessionOption>())
}
