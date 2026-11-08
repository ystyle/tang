package tang.testing

import std.collection.ArrayList
import ystyle::tachyon.DetachedResponse

/// 测试响应记录器
///
/// 对应 Go `httptest.NewRecorder()` 的角色：把 handler 写出的响应原样留下来，
/// 供断言使用（不经过网络）。
public class TestResponse {
    public let status: UInt16
    public let body: String
    public let headers: ArrayList<(String, String)>

    init(resp: DetachedResponse) {
        this.status = resp.statusCode
        this.body = String.fromUtf8(resp.body)
        this.headers = resp.headers
    }

    /// 取响应头（大小写不敏感）
    public func header(name: String): ?String {
        let lower = name.toAsciiLower()
        for ((k, v) in headers) {
            if (k.toAsciiLower() == lower) {
                return Some(v)
            }
        }
        return None
    }

    /// 是否有该响应头
    public func hasHeader(name: String): Bool {
        match (header(name)) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 断言状态码（失败直接抛异常，测试框架会标红）
    public func assertStatus(expected: UInt16): TestResponse {
        if (status != expected) {
            throw AssertException("状态码不匹配：期望 " + expected.toString() + "，实际 " + status.toString() +
                "，body=" + body)
        }
        return this
    }

    /// 断言 body 完全相等
    public func assertBody(expected: String): TestResponse {
        if (body != expected) {
            throw AssertException("body 不匹配：期望 [" + expected + "]，实际 [" + body + "]")
        }
        return this
    }

    /// 断言 body 包含子串
    public func assertBodyContains(sub: String): TestResponse {
        if (let None <- body.indexOf(sub)) {
            throw AssertException("body 不包含 [" + sub + "]，实际 [" + body + "]")
        }
        return this
    }

    /// 断言响应头等于期望值
    public func assertHeader(name: String, expected: String): TestResponse {
        match (header(name)) {
            case Some(v) =>
                if (v != expected) {
                    throw AssertException("响应头 " + name + " 不匹配：期望 [" + expected + "]，实际 [" + v + "]")
                }
            case None =>
                throw AssertException("缺少响应头 " + name)
        }
        return this
    }

    /// 断言响应头包含子串（如 Content-Type 的 charset）
    public func assertHeaderContains(name: String, sub: String): TestResponse {
        match (header(name)) {
            case Some(v) =>
                if (let None <- v.indexOf(sub)) {
                    throw AssertException("响应头 " + name + " 不包含 [" + sub + "]，实际 [" + v + "]")
                }
            case None =>
                throw AssertException("缺少响应头 " + name)
        }
        return this
    }
}

/// 测试断言失败异常
public class AssertException <: Exception {
    public init(message: String) {
        super(message)
    }
}
