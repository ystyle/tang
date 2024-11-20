### basic auth 认证
>详细代码请看 [src/main.cj](/examples/basicauth/src/main.cj)

1. 执行 `cpm update && cpm build` 构建项目
2. 执行 `./bin/main` 启动服务
3. 执行 `curl -v 127.0.0.1:10000/api/user/current` 没设置密码, 可以看到header会提示: 401没有认证
   ```shell
    coder@04bc35645f66:~/project/tang/examples/basicauth$ curl -v 127.0.0.1:10000/api/user/current
    *   Trying 127.0.0.1:10000...
    * Connected to 127.0.0.1 (127.0.0.1) port 10000 (#0)
    > GET /api/user/current HTTP/1.1
    > Host: 127.0.0.1:10000
    > User-Agent: curl/7.74.0
    > Accept: */*
    > 
    * Mark bundle as not supporting multiuse
    < HTTP/1.1 401 Unauthorized
    < Content-Length: 0
    < Date: Thu, 11Aug 2022 09:06:02 GMT
    < Connection: keep-alive
    < Content-Type: text/plain; charset=utf-8
    < Www-Authenticate: basic realm="Restricted"
    < 
    * Connection #0 to host 127.0.0.1 left intact
   ```
4. 执行 `curl -u test:test -v 127.0.0.1:10000/api/user/current` 可以看设置密码后可以正常返回
    ```shell
    curl -u test:test -v 127.0.0.1:10000/api/user/current
    *   Trying 127.0.0.1:10000...
    * Connected to 127.0.0.1 (127.0.0.1) port 10000 (#0)
    * Server auth using Basic with user 'test'
    > GET /api/user/current HTTP/1.1
    > Host: 127.0.0.1:10000
    > Authorization: Basic dGVzdDp0ZXN0
    > User-Agent: curl/7.74.0
    > Accept: */*
    > 
    * Mark bundle as not supporting multiuse
    < HTTP/1.1 200 OK
    < Content-Length: 19
    < Date: Thu, 11Aug 2022 09:06:33 GMT
    < Connection: keep-alive
    < Content-Type: text/plain; charset=utf-8
    < 
    current user: haha
    * Connection #0 to host 127.0.0.1 left intact
    ```