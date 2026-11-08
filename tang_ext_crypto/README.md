# tang_ext_crypto

**tang 的加密类中间件（依赖 stdx.crypto）。**

这五个中间件需要摘要/随机数能力，所以从核心拆出来单独发。
**用不到它们就不需要 stdx**，也不用 `CANGJIE_STDX_PATH`。

```toml
[dependencies]
  "tang" = "2.0.0"
  "tang_ext_crypto" = "2.0.0"
```

```shell
eval "$(cjvs env zsh)" && eval "$(cjvs stdx-env zsh)"   # 需要 stdx 环境
```

## 包含

| 中间件 | import |
|---|---|
| CSRF | `tang_ext_crypto.csrf` |
| Session | `tang_ext_crypto.session` |
| EncryptCookie | `tang_ext_crypto.encryptcookie` |
| ETag | `tang_ext_crypto.etag` |
| Idempotency | `tang_ext_crypto.idempotency` |

## 从 tang 1.0.x 迁移

这五个中间件的 import 从 `tang.middleware.xxx` 改成了 `tang_ext_crypto.xxx`，
并在 `cjpm.toml` 里加上本包依赖。详见 tang 仓的 `docs/MIGRATION.md`。

MulanPSL-2.0
