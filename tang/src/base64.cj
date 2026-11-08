package tang

import std.collection.ArrayList

/// Base64 解码（零依赖）
///
/// 原实现用 stdx.encoding.base64.fromBase64String，只被 Basic 认证解 header 用到，
/// 这里补一个最小实现，去掉该 stdx 依赖。支持标准字母表，忽略空白，接受缺失 padding。
public func fromBase64String(s: String): ?Array<Byte> {
    let out = ArrayList<Byte>()
    var acc: Int64 = 0
    var bits: Int64 = 0
    for (c in s.toArray()) {
        var v: Int64 = -1
        if (c >= 65 && c <= 90) {
            v = Int64(c - 65)                 // A-Z
        } else if (c >= 97 && c <= 122) {
            v = Int64(c - 97) + 26            // a-z
        } else if (c >= 48 && c <= 57) {
            v = Int64(c - 48) + 52            // 0-9
        } else if (c == 43) {
            v = 62                            // '+'
        } else if (c == 47) {
            v = 63                            // '/'
        } else if (c == 61) {
            break                             // '=' padding
        } else {
            continue                          // 忽略空白与换行
        }
        acc = (acc << 6) | v
        bits += 6
        if (bits >= 8) {
            bits -= 8
            out.add(UInt8((acc >> bits) & 0xFF))
        }
    }
    if (out.size == 0) {
        return None
    }
    let result = Array<Byte>(out.size, repeat: 0)
    var i: Int64 = 0
    while (i < out.size) {
        result[i] = out[i]
        i += 1
    }
    return Some(result)
}
