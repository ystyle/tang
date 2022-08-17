### bind query string
>使用bindQuery绑定query参数到对象， 对象需要实现Serializable接口， 详情请看[src/main.cj](/examples/bind_query/src/main.cj)

启动服务后，执行`curl http://127.0.0.1:10000/api/user?id=1\&name=test`可以看到返回了query的参数， 目前只支持简单的对象，字段类型不支持数组和对象

