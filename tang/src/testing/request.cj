package tang.testing

import std.collection.ArrayList
import ystyle::tachyon.DetachedRequest

/// 测试请求构造器
///
/// 直接构造 tachyon 的 DetachedRequest（不绑定 socket），
/// 所以测一条路由不需要起真实服务、不需要占端口、不需要 HTTP 客户端。
public class TestRequest {
    var method: String = "GET"
    var target: String = "/"
    var host: String = "example.com"
    var headers: ArrayList<(String, String)> = ArrayList<(String, String)>()
    var bodyBytes: Array<Byte> = Array<Byte>(0, repeat: 0)

    private init(method: String, target: String) {
        this.method = method
        this.target = target
    }

    public static func get(target: String): TestRequest {
        return TestRequest("GET", target)
    }

    public static func post(target: String): TestRequest {
        return TestRequest("POST", target)
    }

    public static func put(target: String): TestRequest {
        return TestRequest("PUT", target)
    }

    public static func patch(target: String): TestRequest {
        return TestRequest("PATCH", target)
    }

    public static func delete(target: String): TestRequest {
        return TestRequest("DELETE", target)
    }

    public static func head(target: String): TestRequest {
        return TestRequest("HEAD", target)
    }

    public static func options(target: String): TestRequest {
        return TestRequest("OPTIONS", target)
    }

    /// 自定义方法
    public static func of(method: String, target: String): TestRequest {
        return TestRequest(method, target)
    }

    public func header(name: String, value: String): TestRequest {
        this.headers.add((name, value))
        return this
    }

    public func setHost(host: String): TestRequest {
        this.host = host
        return this
    }

    /// 设置 body（字符串）
    public func body(content: String): TestRequest {
        this.bodyBytes = content.toArray()
        return this
    }

    /// 设置 body（字节）
    public func body(content: Array<Byte>): TestRequest {
        this.bodyBytes = content
        return this
    }

    /// 设置 JSON body（自动带上 Content-Type）
    public func json(content: String): TestRequest {
        if (this.headerValue("Content-Type") == None) {
            this.headers.add(("Content-Type", "application/json"))
        }
        return this.body(content)
    }

    /// 设置表单 body（自动带上 Content-Type）
    public func form(content: String): TestRequest {
        if (this.headerValue("Content-Type") == None) {
            this.headers.add(("Content-Type", "application/x-www-form-urlencoded"))
        }
        return this.body(content)
    }

    func headerValue(name: String): ?String {
        for ((k, v) in headers) {
            if (k == name) {
                return Some(v)
            }
        }
        return None
    }

    /// 转成 tachyon 的请求快照
    public func build(): DetachedRequest {
        let r = DetachedRequest()
        r.method = method
        r.target = target
        r.host = host
        var hasContentLength = false
        for (h in headers) {
            if (h[0] == "Content-Length") {
                hasContentLength = true
            }
            r.headers.add(h)
        }
        if (bodyBytes.size > 0) {
            r.body = bodyBytes
            if (!hasContentLength) {
                r.headers.add(("Content-Length", bodyBytes.size.toString()))
            }
        }
        return r
    }
}

/// 从原始 HTTP 报文构造测试请求（贴近「贴一段 packet」的调试习惯）
///
/// 例：`"GET /api/users?page=2 HTTP/1.1\r\nHost: x\r\n\r\n"`
public func request(raw: String): TestRequest {
    let sep = raw.indexOf("\r\n\r\n")
    let head = match (sep) {
        case Some(i) => raw[0..i]
        case None => raw
    }
    let body = match (sep) {
        case Some(i) => raw[i + 4..]
        case None => ""
    }
    let lines = head.split("\r\n")
    var method = "GET"
    var target = "/"
    let req = if (lines.size > 0) {
        let parts = lines[0].split(" ")
        if (parts.size >= 2) {
            method = parts[0]
            target = parts[1]
        }
        TestRequest.of(method, target)
    } else {
        TestRequest.get("/")
    }
    var i = 1
    while (i < lines.size) {
        let line = lines[i]
        i += 1
        let colon = line.indexOf(":")
        if (let Some(c) <- colon) {
            let name = line[0..c]
            let value = line[c + 1..].trimAscii()
            req.header(name, value)
        }
    }
    if (!body.isEmpty()) {
        req.body(body)
    }
    return req
}
