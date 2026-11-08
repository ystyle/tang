package tang.websocket

import std.collection.ArrayList
import std.overflow.*

/// SHA-1（RFC 3174）与 Base64 编码的最小实现
///
/// 为什么自己写：WebSocket 握手要用
/// `Base64(SHA1(clientKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))` 算 accept key，
/// 而仓颉 std 里没有 SHA1，stdx 有但要拉一整条 stdx 依赖链。
/// 这两个算法各几十行、无密钥、无状态，自己实现比引依赖划算 —— 也让 websocket 留在零 stdx 核心。
public func sha1(data: Array<Byte>): Array<Byte> {
    var h0: UInt32 = 0x67452301
    var h1: UInt32 = 0xEFCDAB89
    var h2: UInt32 = 0x98BADCFE
    var h3: UInt32 = 0x10325476
    var h4: UInt32 = 0xC3D2E1F0

    // 补位：0x80 + 0x00... + 64bit 大端长度
    let bitLen = UInt64(data.size) * 8
    var padded = ArrayList<Byte>()
    for (b in data) {
        padded.add(b)
    }
    padded.add(0x80)
    while (padded.size % 64 != 56) {
        padded.add(0)
    }
    var i: Int64 = 7
    while (i >= 0) {
        padded.add(UInt8((bitLen >> UInt64(i * 8)) & 0xFF))
        i -= 1
    }

    var blockStart: Int64 = 0
    while (blockStart < padded.size) {
        var w = Array<UInt32>(80, repeat: 0)
        var t: Int64 = 0
        while (t < 16) {
            let p = blockStart + t * 4
            w[t] = (UInt32(padded[p]) << 24) | (UInt32(padded[p + 1]) << 16) |
                   (UInt32(padded[p + 2]) << 8) | UInt32(padded[p + 3])
            t += 1
        }
        while (t < 80) {
            w[t] = rotl(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16], 1)
            t += 1
        }
        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4
        t = 0
        while (t < 80) {
            var f: UInt32 = 0
            var k: UInt32 = 0
            if (t < 20) {
                f = (b & c) | ((b ^ 0xFFFFFFFF) & d)
                k = 0x5A827999
            } else if (t < 40) {
                f = b ^ c ^ d
                k = 0x6ED9EBA1
            } else if (t < 60) {
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDC
            } else {
                f = b ^ c ^ d
                k = 0xCA62C1D6
            }
            let temp = rotl(a, 5).wrappingAdd(f).wrappingAdd(e).wrappingAdd(k).wrappingAdd(w[t])
            e = d
            d = c
            c = rotl(b, 30)
            b = a
            a = temp
            t += 1
        }
        h0 = h0.wrappingAdd(a)
        h1 = h1.wrappingAdd(b)
        h2 = h2.wrappingAdd(c)
        h3 = h3.wrappingAdd(d)
        h4 = h4.wrappingAdd(e)
        blockStart += 64
    }

    let out = Array<Byte>(20, repeat: 0)
    let hs = [h0, h1, h2, h3, h4]
    var idx: Int64 = 0
    for (h in hs) {
        out[idx * 4] = UInt8((h >> 24) & 0xFF)
        out[idx * 4 + 1] = UInt8((h >> 16) & 0xFF)
        out[idx * 4 + 2] = UInt8((h >> 8) & 0xFF)
        out[idx * 4 + 3] = UInt8(h & 0xFF)
        idx += 1
    }
    return out
}

func rotl(x: UInt32, n: UInt32): UInt32 {
    if (n == 0) {
        return x
    }
    return (x << n) | (x >> (32 - n))
}

/// 标准 Base64 编码（带 padding）
public func base64Encode(data: Array<Byte>): String {
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toArray()
    let sb = StringBuilder()
    var i: Int64 = 0
    while (i + 2 < data.size) {
        let n = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8) | Int64(data[i + 2])
        sb.append(String.fromUtf8([alphabet[(n >> 18) & 63]]))
        sb.append(String.fromUtf8([alphabet[(n >> 12) & 63]]))
        sb.append(String.fromUtf8([alphabet[(n >> 6) & 63]]))
        sb.append(String.fromUtf8([alphabet[n & 63]]))
        i += 3
    }
    let rest = data.size - i
    if (rest == 1) {
        let n = Int64(data[i]) << 16
        sb.append(String.fromUtf8([alphabet[(n >> 18) & 63]]))
        sb.append(String.fromUtf8([alphabet[(n >> 12) & 63]]))
        sb.append("==")
    } else if (rest == 2) {
        let n = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8)
        sb.append(String.fromUtf8([alphabet[(n >> 18) & 63]]))
        sb.append(String.fromUtf8([alphabet[(n >> 12) & 63]]))
        sb.append(String.fromUtf8([alphabet[(n >> 6) & 63]]))
        sb.append("=")
    }
    return sb.toString()
}
