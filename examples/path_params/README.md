### path_params
>获取路径参数示例

- 以下代码可以获取路径中`:id`的值
  - 执行： `curl 127.0.0.1:10000/api/user/123` 查看输出
  ```cj
    group.get("/user/:id", {w, r => 
        let id = r.params.get("id") ?? "None"
        println("id: ${id}")
        PlainString(w, id)
    })
  ```
- 以下代码可以获取通配符匹配的路径 
  - 执行： `curl 127.0.0.1:10000/api/user/123/test` 查看输出
  ```cj
    group.get("/user/*path", {w, r => 
        let path = r.params.get("path") ?? "not path value"
        let m = r.params.map()
        JSON(w, m)
    })
  ```
