package tang

/// HTTP Basic 认证的用户信息（原 stdx.encoding.url.UserInfo 的零依赖替身）
public class UserInfo {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        this.username = username
        this.password = password
    }

    public func toString(): String {
        return username + ":" + password
    }
}
