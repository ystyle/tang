package echo

from std import io.*

public func CleanPath(p:String):String {
    let stackBufSize = 128
    if (p == "") {
        return "/"
    }
    var buff = StringStream("")
    let n = p.size()
    var r = 1
    var w = 1
    if (p[0] != '/') {
        r = 0
        if (n + 1 > stackBufSize) {
            buff.ensureCapacity(n + 1)
        }
        buff.appends('/')
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
                if (buff.length() == 0) {
                    while (w > 1 && p[w] != '/') {
                        w--
                    }
                } else {
                    while (w > 1 && buff.getChars()[w] != '/') {
                        w--
                    }
                }
            }
        } else {
            if (w > 1) {
               buff = bufApp(buff, p, w, '/')
                w++
            }
            while (r < n && p[r] != '/') {
                buff = bufApp(buff, p, w, p[r])
                w++
                r++
            }
        }
    }
    if (trailing && w > 1) {
        buff = bufApp(buff, p, w, '/')
        w++
    }
    if (buff.length() == 0) {
        return p[..w]
    }
    return buff.subString(0, w)
}

func bufApp(buf:StringStream, s:String, w:Int64, c:Char):StringStream{
    var b = StringStream(buf.toString())
    if (buf.length() == 0) {
        if (s[w] == c) {
            return buf
        }
        let l = s.size()
        if (l > buf.capacity()) {
            b.ensureCapacity(l)
        } else {
            b = StringStream("")
            b.ensureCapacity(l)
        }
        b.appends(s[..w])
    }
    
    if (b.length() > w) {
        b.setCharAt(w, c)
    } else {
        b.appends(c)
        ()
    }
    return b
}