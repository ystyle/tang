# all() 方法示例

本示例演示如何使用 Tang 的 `all()` 方法匹配所有 HTTP 方法。

## 什么是 all() 方法？

`all()` 方法允许你注册一个处理器来响应所有 HTTP 方法（GET、POST、PUT、DELETE、PATCH、HEAD、OPTIONS）。

## 使用场景

1. **健康检查端点**：接受任意方法的健康检查
2. **CORS 预检**：处理 OPTIONS 请求和其他方法
3. **通用处理**：某些需要统一处理的端点

## 运行示例

```bash
cd examples/all_method
cjpm run
```

## 测试

服务器启动后，可以用不同方法访问：

```bash
# 使用不同的 HTTP 方法访问 /health
curl http://localhost:8080/health
curl -X POST http://localhost:8080/health
curl -X PUT http://localhost:8080/health
curl -X DELETE http://localhost:8080/health

# 访问 /api/version
curl http://localhost:8080/api/version
```

## 优先级规则

当同时注册了具体方法和 `all()` 时，具体方法优先：

```cj
// GET 请求会匹配这个处理器
app.get("/api/data", { ctx =>
    ctx.writeString("GET handler")
})

// 其他所有方法（POST、PUT、DELETE 等）会匹配这个处理器
app.all("/api/data", { ctx =>
    ctx.writeString("All methods handler")
})
```

## 代码说明

```cj
// 匹配所有 HTTP 方法
app.all("/health", { ctx =>
    let method = ctx.method()  // 获取实际的方法名
    ctx.writeString("Method: ${method}")
})

// 在 Group 中使用
let apiGroup = app.group("/api")
apiGroup.all("/version", { ctx => ... })
```
