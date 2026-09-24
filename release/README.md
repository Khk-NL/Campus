# Android 安装包

当前演示包：[Campus-1.0.0+2-preview.apk](./Campus-1.0.0+2-preview.apk)

| 项目 | 值 |
| --- | --- |
| App 版本 | `1.0.0+2`（`apps/mobile/pubspec.yaml`） |
| 构建日期 | 2026-09-24 |
| 构建模式 | Flutter `--release` |
| 签名 | Android Debug 证书，仅供演示和测试安装；**不是正式发布签名** |
| 大小 | 57,848,405 字节（约 55.2 MiB） |
| SHA-256 | `0B95B8F2CA37DACC27F4664428EB08C5FD18F50FDFED9AFDE559CA3D9CE74A54` |

此前的调试包位于 `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`，属于可清理的构建缓存，不在本目录维护；它不能替代这里的 release 模式预览包。

更新安装包时，先修改 `apps/mobile/pubspec.yaml` 中的版本号，再从仓库根目录运行 `build_apk.cmd`。脚本会构建 release 模式 APK、复制到本目录，并打印 SHA-256；同一版本已有不同内容时会停止，避免覆盖旧包。构建完成后同步更新本文件的版本、日期、大小和 SHA-256。不要把密钥或 `key.properties` 放进本目录。

上一版：[Campus-1.0.0+1-preview.apk](./Campus-1.0.0+1-preview.apk)。

正式对外发布前，需配置独立的生产签名，并将产物与说明中的“preview / Debug 证书”标识一并更新；仅仅使用 `--release` 构建并不等于已完成正式签名。
