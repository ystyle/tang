package tang

import std.io.{StringReader, StringWriter}
import std.collection.ArrayList

public func cleanPath(pa:String):String {
    let p = pa.toRuneArray()
    let stackBufSize = 128
    if (p.size == 0) {
        return "/"
    }
    var buff = ArrayList<Rune>(stackBufSize)
    let n = p.size
    var r = 1
    var w = 1
    if (p[0] != r'/') {
        r = 0
        buff.append(r'/')
    }
    var trailing = n > 1 && p[n-1] == r'/'
    while (r < n) {
        if (p[r] == r'/') {
            r ++
        } else if (p[r] == r'.' && r+1==n) {
            trailing = true
            r++
        } else if (p[r] == r'.' && p[r+1] == r'/') {
            r += 2
        } else if(p[r] == r'.' && p[r+1] == r'.' && (r+2 ==n || p[r+2] == r'/')){
            r += 3
            if (w > 1) {
                w--
                if (buff.size == 0) {
                    while (w > 1 && p[w] != r'/') {
                        w--
                    }
                } else {
                    while (w > 1 && buff[w] != r'/') {
                        w--
                    }
                }
            }
        } else {
            if (w > 1) {
               bufApp(buff, String(p), w, r'/')
                w++
            }
            while (r < n && p[r] != r'/') {
                bufApp(buff, String(p), w, p[r])
                w++
                r++
            }
        }
    }
    if (trailing && w > 1) {
        bufApp(buff, String(p), w, r'/')
        w++
    }
    if (buff.size == 0) {
        return String(p[..w])
    }
    return String(buff[0..w])
}

func bufApp(buf:ArrayList<Rune>, s:String, w:Int64, c:Rune):Unit{
    if (buf.size == 0) {
        if (s.toRuneArray()[w] == c) {
            return
        }
        println(1)
        buf.appendAll(s[..w].toRuneArray())
        println(2)
    }
    if (buf.size > w) {
        buf.remove(w)
        buf.insert(w, c)
    } else {
        buf.append(c)
    }
}