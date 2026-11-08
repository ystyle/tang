# _disabled —— 暂不参与编译的文件

这里的东西**不是被遗忘**，是当前分支（feat/tachyon-backend）下暂时无法编译，
每条都写清了原因和后续做法。

## 为什么移出

HTTP 层已从 stdx.net.http 换成 tachyon，凡是直接依赖 stdx 类型的代码都要重写或重做。

| 文件 | 原因 | 后续 |
|---|---|---|
| fromstd_test.cj | 测旧版 fromStd()（基于 stdx server 的 tang Router 注册） | 已由 tang_ext_stdx 覆盖（serve + fromStd），此文件仅留作历史参考 |
| router_register_test.cj | 测 stdx 风格的 Router.register(path, HttpRequestHandler) | stdx 路由注册改由 tang_ext_stdx 的 serve 承担，不再提供同名 API |

## 已经重写回来的

- mount_test.cj → 用 tachyon server + 裸 socket 客户端重写，已回到 tang/src
- listen_test.cj → 同上（builder 回调 + stop 释放服务）
- staticfile → 已用 tachyon 的 FileServer 重写在 core（tang/src/middleware/staticfile），
  目录索引/Range/If-Modified-Since/路径穿越防护都由 FileServer 负责，测试走 detached ctx
- proxy → 用 core 自带极简 HTTP 客户端（tang.http）重写在 core，零 stdx
- compose → 重做为 tang.compose.ComposeRouter（运行时按前缀委派，非 stdx distributor）
- e2e 辅助在 tang/src/e2e_helpers_test.cj（零依赖：TcpServerSocket + TcpSocket）
