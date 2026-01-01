### todo示例
>todoList完整的curd操作接口

- 创建一个todo：  `curl -X POST 127.0.0.1:10000/api/todo --data-raw '{"content":"test"}'`
- 查询一个todo:   `curl -X GET 127.0.0.1:10000/api/todo/3`
- 查询所有的todo: `curl 127.0.0.1:10000/api/todo`
- 更新一个todo:   `curl -X PUT 127.0.0.1:10000/api/todo --data-raw '{"id":1, "content":"my tang demo"}'`
- 删除一个todo:   `curl -X DELETE 127.0.0.1:10000/api/todo/3`