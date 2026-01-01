package tang

import std.collection.ArrayList

public func cleanPath(pa:String):String {
    let p = pa.toArray()
    let stackBufSize = 128
    if (p.size == 0) {
        return "/"
    }
    var buff = ArrayList<UInt8>(stackBufSize)
    let n = p.size
    var r = 1
    var w = 1
    if (p[0] != b'/') {
        r = 0
        buff.add(b'/')
    }
    var trailing = n > 1 && p[n-1] == b'/'
    while (r < n) {
        if (p[r] == b'/') {
            r ++
        } else if (p[r] == b'.' && r+1==n) {
            trailing = true
            r++
        } else if (p[r] == b'.' && p[r+1] == b'/') {
            r += 2
        } else if(p[r] == b'.' && p[r+1] == b'.' && (r+2 ==n || p[r+2] == b'/')){
            r += 3
            if (w > 1) {
                w--
                if (buff.size == 0) {
                    while (w > 1 && p[w] != b'/') {
                        w--
                    }
                } else {
                    while (w > 1 && buff[w] != b'/') {
                        w--
                    }
                }
            }
        } else {
            if (w > 1) {
               bufApp(buff, String.fromUtf8(p), w, b'/')
                w++
            }
            while (r < n && p[r] != b'/') {
                bufApp(buff, String.fromUtf8(p), w, p[r])
                w++
                r++
            }
        }
    }
    if (trailing && w > 1) {
        bufApp(buff, String.fromUtf8(p), w, b'/')
        w++
    }
    if (buff.size == 0) {
        return String.fromUtf8(p[..w])
    }
    return String.fromUtf8(buff[0..w].toArray())
}

func bufApp(buf:ArrayList<UInt8>, s:String, w:Int64, c:UInt8):Unit{
    if (buf.size == 0) {
        if (s.toArray()[w] == c) {
            return
        }
        println(1)
        buf.add(all:s[..w].toArray())
        println(2)
    }
    if (buf.size > w) {
        buf.remove(at:w)
        buf.add(c, at: w)
    } else {
        buf.add(c)
    }
}