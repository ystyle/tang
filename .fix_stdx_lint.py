p = '/home/ystyle/Projects/Cangjie/tang/tang_ext_stdx/src/adapter.cj'
s = open(p).read()

# 1) readAll 去掉未使用的 size 参数（body 一律读到 EOF，size 只用于快照记录）
s = s.replace('d.body = readAll(req.body, req.bodySize)', 'd.body = readAll(req.body)')
s = s.replace('func readAll(stream: InputStream, size: ?Int64): Array<Byte> {', 'func readAll(stream: InputStream): Array<Byte> {')

# 2) register 的两个参数要真正被用上（lint G.FUN.02）
old = ('    public func register(path: String, handler: HttpRequestHandler): Unit {' + chr(10)
       + '        throw Exception("tang_ext_stdx: 路由请在 tang 应用上注册（app.get/post/...）")' + chr(10)
       + '    }')
new = ('    public func register(path: String, handler: HttpRequestHandler): Unit {' + chr(10)
       + '        // stdx 风格的路径级注册在这里没有意义：路由都在 tang 应用上注册，' + chr(10)
       + '        // 本 distributor 只把请求整体桥接过去。这里显式拒绝而不是静默接受。' + chr(10)
       + '        throw Exception("tang_ext_stdx: 不支持 stdx 风格注册（path=" + path + ' + chr(10)
       + '            "）；请用 tang 应用注册路由：app.get/post/...")' + chr(10)
       + '    }')
assert old in s, 'register snippet not found'
s = s.replace(old, new)
open(p, 'w').write(s)
print('adapter.cj patched; readAll size removed:', 'size: ?Int64' not in s)