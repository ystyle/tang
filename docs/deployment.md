# 部署建议

本文档提供 Tang 应用的生产环境部署建议和最佳实践。

## 生产环境配置

### Gzip 压缩

推荐在生产环境的 Nginx 或其他反向代理层配置压缩，而不是在应用层处理。

#### 为什么推荐 Nginx 压缩？

1. **性能更好**：
   - Nginx 事件驱动，压缩不影响应用服务器 CPU
   - 应用服务器可以专注业务逻辑处理
   - 充分利用多核架构

2. **配置灵活**：
   - 可以根据路径、文件类型灵活配置
   - 支持压缩阈值、压缩级别等调优
   - 动态调整配置，无需重启应用

3. **维护简单**：
   - 不需要修改应用代码
   - 重新部署时不需要重启应用服务器
   - 配置集中管理，便于维护

#### Nginx 配置示例

```nginx
http {
    # 开启 gzip
    gzip on;

    # 压缩级别（1-9，推荐 6）
    # 级别越高压缩率越高，但 CPU 消耗也越大
    gzip_comp_level 6;

    # 压缩的 MIME 类型
    gzip_types
        application/json
        application/javascript
        text/css
        text/html
        text/plain
        text/xml
        application/xml;

    # 最小压缩文件大小（小于此值不压缩）
    # 建议设置为 1000 字节
    gzip_min_length 1000;

    # 压缩版本（支持 HTTP/1.1）
    gzip_http_version 1.1;

    # 为代理服务器启用压缩
    gzip_proxied any;

    # Vary 头（支持缓存的正确处理）
    gzip_vary on;

    # 缓冲区设置
    gzip_buffers 16 8k;

    # 压缩窗口大小
    gzip_window 512k;
}
```

#### 其他反向代理配置

**Caddy**（自动 HTTPS）：

```
example.com {
    encode gzip {
        level 6
    }
    reverse_proxy localhost:10000
}
```

**Traefik**（云原生反向代理）：

```yaml
http:
  middlewares:
    my-compress:
      compress: true
```

### 应用层压缩的替代方案

如果确实需要在应用层压缩（例如直连场景、无反向代理），可以：

1. **使用 `stdx.compress.zlib` 包自行实现**
   - 参考 `CompressInputStream` 和 `CompressOutputStream` 的使用
   - 根据具体场景定制压缩策略

2. **使用第三方压缩库**
   - 根据性能需求选择合适的实现

3. **示例代码**：

```cj
import stdx.compress.zlib.*
import std.io.*

func compressData(data: Array<Byte>): Array<Byte> {
    let output = ByteBuffer()
    let compressor = CompressOutputStream(
        output,
        wrap: GzipFormat,
        compressLevel: DefaultCompression
    )
    compressor.write(data)
    compressor.close()
    return output.toArray()
}
```

## 反向代理配置

### Nginx 完整配置示例

```nginx
server {
    listen 80;
    server_name example.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL 证书配置
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # SSL 优化
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    # 现代 SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    # Gzip 压缩
    gzip on;
    gzip_comp_level 6;
    gzip_types application/json application/javascript text/css text/html text/plain;
    gzip_min_length 1000;

    # 代理到 Tang 应用
    location / {
        proxy_pass http://localhost:10000;
        proxy_http_version 1.1;

        # 传递真实客户端信息
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

## 性能优化建议

### 应用层优化

1. **连接池配置**：
   - 合理设置最大并发连接数
   - 避免连接泄漏

2. **日志管理**：
   - 生产环境使用合适的日志级别（INFO/WARNING）
   - 定期清理日志文件

3. **内存管理**：
   - 监控应用内存使用
   - 避免大对象长期持有

### 监控和日志

1. **访问日志**：使用 `accesslog` 中间件记录请求日志
2. **错误追踪**：使用 `exception` 中间件捕获异常
3. **请求追踪**：使用 `requestid` 中间件追踪请求链路

## 安全建议

1. **使用 HTTPS**：生产环境必须启用 SSL/TLS
2. **安全响应头**：使用 `security` 中间件添加安全头
3. **CORS 配置**：根据需求配置 `cors` 中间件
4. **认证授权**：根据需要使用 `basicauth` 或其他认证机制

## 部署清单

- [ ] 配置反向代理（Nginx/Caddy/Traefik）
- [ ] 启用 Gzip 压缩
- [ ] 配置 SSL/TLS 证书
- [ ] 设置合理的超时时间
- [ ] 配置日志轮转
- [ ] 设置监控告警
- [ ] 配置自动重启机制
- [ ] 备份策略和灾难恢复

## 相关文档

- [中间件使用](../README.md#中间件)
- [示例代码](../examples/)
- [性能优化建议](#性能优化建议)
