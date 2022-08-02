package tang

from std import io.*

public func CleanPath(p:String):String {
    let stackBufSize = 128
    if (p == "") {
        return "/"
    }
    var buff = StringBuilder()
    let n = p.size()
    var r = 1
    var w = 1
    if (p[0] != '/') {
        r = 0
        buff.append('/')
    }
    var trailing = n > 1 && p[n-1] == '/'
    while (r < n) {
        if (p[r] == '/') {
            r ++
        } else if (p[r] == '.' && r+1==n) {
            trailing = true
            r++
        } else if (p[r] == '.' && p[r+1] == '/') {
            r += 2
        } else if(p[r] == '.' && p[r+1] == '.' && (r+2 ==n || p[r+2] == '/')){
            r += 3
            if (w > 1) {
                w--
                if (buff.size() == 0) {
                    while (w > 1 && p[w] != '/') {
                        w--
                    }
                } else {
                    while (w > 1 && buff.get(w) != '/') {
                        w--
                    }
                }
            }
        } else {
            if (w > 1) {
               bufApp(buff, p, w, '/')
                w++
            }
            while (r < n && p[r] != '/') {
                bufApp(buff, p, w, p[r])
                w++
                r++
            }
        }
    }
    if (trailing && w > 1) {
        bufApp(buff, p, w, '/')
        w++
    }
    if (buff.size() == 0) {
        return p[..w]
    }
    return buff.toString()[0..w]
}

func bufApp(buf:StringBuilder, s:String, w:Int64, c:Char):Unit{
    if (buf.size() == 0) {
        if (s[w] == c) {
            return
        }
        buf.append(s[..w])
    }
    if (buf.size() > w) {
        buf.remove(w)
        buf.insert(w, c)
    } else {
        buf.append(c)
    }
}