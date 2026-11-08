package tang.http

import std.collection.ArrayList
import std.net.TcpSocket
import std.convert.*

/// URL 拆解结果（目前只支持 http://，https 需要 TLS，交给扩展成员）
public class UrlParts {
    public var host: String = ""
    public var port: UInt16 = 80
    public var pathAndQuery: String = "/"

    public init() {}
}

/// 解析 `http://host[:port]/path?query`
public func parseUrl(url: String): ?UrlParts {
    if (!url.startsWith("http://")) {
        return None
    }
    let rest = url[7..]
    let slash = rest.indexOf("/")
    let authority = match (slash) {
        case Some(i) => rest[0..i]
        case None => rest
    }
    let pathAndQuery = match (slash) {
        case Some(i) => rest[i..]
        case None => "/"
    }
    let parts = UrlParts()
    let colon = authority.lastIndexOf(":")
    match (colon) {
        case Some(i) =>
            parts.host = authority[0..i]
            match (UInt16.tryParse(authority[i + 1..])) {
                case Some(p) => parts.port = p
                case None => return None
            }
        case None =>
            parts.host = authority
    }
    if (parts.host.isEmpty()) {
        return None
    }
    parts.pathAndQuery = if (pathAndQuery.isEmpty()) { "/" } else { pathAndQuery }
    return Some(parts)
}

/// 客户端响应
public class ClientResponse {
    public var status: UInt16 = 0
    public var headers: ArrayList<(String, String)> = ArrayList<(String, String)>()
    public var body: Array<Byte> = Array<Byte>(0, repeat: 0)

    public init() {}

    public func header(name: String): ?String {
        let lower = name.toAsciiLower()
        for ((k, v) in headers) {
            if (k.toAsciiLower() == lower) {
                return Some(v)
            }
        }
        return None
    }
}

/// 极简 HTTP/1.1 客户端
///
/// 用途：反向代理等**服务端内部**需要访问上游 HTTP 的场景。
/// 不追踪连接复用（每次 Connection: close），不做 TLS ——
/// 需要 https 上游时用扩展成员（stdx.net.tls），核心保持零依赖。
public class HttpClient {
    let timeout: Duration

    public init(timeoutMs!: Int64 = 30000) {
        this.timeout = Duration.millisecond * timeoutMs
    }

    /// 发一个请求并读完整响应
    public func send(method: String, url: String, headers: ArrayList<(String, String)>,
                     body: Array<Byte>): ClientResponse {
        let parts = match (parseUrl(url)) {
            case Some(p) => p
            case None => throw Exception("HttpClient: 只支持 http:// URL，收到 " + url)
        }
        let socket = TcpSocket(parts.host, parts.port)
        socket.connect()
        socket.readTimeout = timeout
        socket.writeTimeout = timeout
        try {
            socket.write(buildRequest(method, parts.pathAndQuery, headers, body))
            return readResponse(socket, method)
        } finally {
            try {
                socket.close()
            } catch (e: Exception) {
                ()
            }
        }
    }

    func buildRequest(method: String, pathAndQuery: String, headers: ArrayList<(String, String)>,
                      body: Array<Byte>): Array<Byte> {
        var sb = StringBuilder()
        sb.append(method)
        sb.append(" ")
        sb.append(pathAndQuery)
        sb.append(" HTTP/1.1\r\n")
        var hasHost = false
        var hasConnection = false
        var hasContentLength = false
        for ((k, v) in headers) {
            let lower = k.toAsciiLower()
            if (lower == "host") {
                hasHost = true
            } else if (lower == "connection") {
                hasConnection = true
            } else if (lower == "content-length") {
                hasContentLength = true
            }
            sb.append(k)
            sb.append(": ")
            sb.append(v)
            sb.append("\r\n")
        }
        if (!hasHost) {
            sb.append("Host: x\r\n")
        }
        if (!hasConnection) {
            sb.append("Connection: close\r\n")
        }
        if (body.size > 0 && !hasContentLength) {
            sb.append("Content-Length: ")
            sb.append(body.size.toString())
            sb.append("\r\n")
        }
        sb.append("\r\n")
        let head = sb.toString().toArray()
        if (body.size == 0) {
            return head
        }
        let out = Array<Byte>(head.size + body.size, repeat: 0)
        var i: Int64 = 0
        while (i < head.size) {
            out[i] = head[i]
            i += 1
        }
        var j: Int64 = 0
        while (j < body.size) {
            out[i + j] = body[j]
            j += 1
        }
        return out
    }

    func readResponse(socket: TcpSocket, method: String): ClientResponse {
        var buf = ArrayList<Byte>()
        let chunk = Array<Byte>(8192, repeat: 0)
        var headerEnd: Int64 = -1
        // 先读到 header 结束
        while (headerEnd < 0) {
            let n = socket.read(chunk)
            if (n <= 0) {
                throw Exception("HttpClient: 上游提前关闭连接")
            }
            var k: Int64 = 0
            while (k < n) {
                buf.add(chunk[k])
                k += 1
            }
            headerEnd = findHeaderEnd(buf)
        }
        let resp = ClientResponse()
        parseHead(buf, headerEnd, resp)
        // 再按 Content-Length / chunked 读 body
        var bodyStart = headerEnd + 4
        let cl = match (resp.header("Content-Length")) {
            case Some(v) => Int64.tryParse(v) ?? -1
            case None => -1
        }
        let chunked = match (resp.header("Transfer-Encoding")) {
            case Some(v) => v.toAsciiLower().contains("chunked")
            case None => false
        }
        if (method == "HEAD" || resp.status == 204 || resp.status == 304) {
            resp.body = Array<Byte>(0, repeat: 0)
            return resp
        }
        if (chunked) {
            resp.body = readChunked(socket, buf, bodyStart)
        } else if (cl >= 0) {
            while (buf.size - bodyStart < cl) {
                let n = socket.read(chunk)
                if (n <= 0) {
                    break
                }
                var k: Int64 = 0
                while (k < n) {
                    buf.add(chunk[k])
                    k += 1
                }
            }
            let available = buf.size - bodyStart
            let take = if (available < cl) { available } else { cl }
            resp.body = subBytes(buf, bodyStart, take)
        } else {
            // 无长度：读到连接关闭
            while (true) {
                let n = try {
                    socket.read(chunk)
                } catch (e: Exception) {
                    0
                }
                if (n <= 0) {
                    break
                }
                var k: Int64 = 0
                while (k < n) {
                    buf.add(chunk[k])
                    k += 1
                }
            }
            resp.body = subBytes(buf, bodyStart, buf.size - bodyStart)
        }
        return resp
    }

    func readChunked(socket: TcpSocket, buf: ArrayList<Byte>, start: Int64): Array<Byte> {
        let out = ArrayList<Byte>()
        let chunk = Array<Byte>(8192, repeat: 0)
        var pos = start
        while (true) {
            // 找本行行尾
            var lineEnd: Int64 = -1
            while (lineEnd < 0) {
                var i = pos
                while (i + 1 < buf.size) {
                    if (buf[i] == 13 && buf[i + 1] == 10) {
                        lineEnd = i
                        break
                    }
                    i += 1
                }
                if (lineEnd < 0) {
                    let n = socket.read(chunk)
                    if (n <= 0) {
                        return toArray(out)
                    }
                    var k: Int64 = 0
                    while (k < n) {
                        buf.add(chunk[k])
                        k += 1
                    }
                }
            }
            let sizeLine = StringBuilder()
            var i = pos
            while (i < lineEnd) {
                sizeLine.append(String.fromUtf8([buf[i]]))
                i += 1
            }
            let sizeHex = sizeLine.toString().split(";")[0].trimAscii()
            let size = match (Int64.tryParse(sizeHex)) {
                case Some(v) => v
                case None => return toArray(out)   // 十六进制解析失败记 0
            }
            if (size <= 0) {
                return toArray(out)
            }
            var need = pos + (lineEnd - pos) + 2 + size
            while (buf.size < need + 2) {
                let n = socket.read(chunk)
                if (n <= 0) {
                    break
                }
                var k: Int64 = 0
                while (k < n) {
                    buf.add(chunk[k])
                    k += 1
                }
            }
            var dataStart = lineEnd + 2
            var j: Int64 = 0
            while (j < size && dataStart + j < buf.size) {
                out.add(buf[dataStart + j])
                j += 1
            }
            pos = dataStart + size + 2   // 跳过分块后的 CRLF
        }
        return toArray(out)
    }

    func findHeaderEnd(buf: ArrayList<Byte>): Int64 {
        var i: Int64 = 0
        let n = buf.size
        while (i + 3 < n) {
            if (buf[i] == 13 && buf[i + 1] == 10 && buf[i + 2] == 13 && buf[i + 3] == 10) {
                return i
            }
            i += 1
        }
        return -1
    }

    func parseHead(buf: ArrayList<Byte>, end: Int64, resp: ClientResponse): Unit {
        let text = StringBuilder()
        var i: Int64 = 0
        while (i < end) {
            text.append(String.fromUtf8([buf[i]]))
            i += 1
        }
        let lines = text.toString().split("\r\n")
        if (lines.size == 0) {
            return
        }
        // 状态行：HTTP/1.1 200 OK
        let statusLine = lines[0].split(" ")
        if (statusLine.size >= 2) {
            resp.status = UInt16.tryParse(statusLine[1]) ?? 0
        }
        var li: Int64 = 1
        while (li < lines.size) {
            let line = lines[li]
            li += 1
            let colon = line.indexOf(":")
            if (let Some(c) <- colon) {
                resp.headers.add((line[0..c].trimAscii(), line[c + 1..].trimAscii()))
            }
        }
    }

    func subBytes(buf: ArrayList<Byte>, start: Int64, count: Int64): Array<Byte> {
        let n = if (count < 0) { 0 } else { count }
        let out = Array<Byte>(n, repeat: 0)
        var i: Int64 = 0
        while (i < n && start + i < buf.size) {
            out[i] = buf[start + i]
            i += 1
        }
        return out
    }

    func toArray(buf: ArrayList<Byte>): Array<Byte> {
        let out = Array<Byte>(buf.size, repeat: 0)
        var i: Int64 = 0
        while (i < buf.size) {
            out[i] = buf[i]
            i += 1
        }
        return out
    }
}
