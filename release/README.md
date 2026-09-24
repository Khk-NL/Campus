# Android 安装包

当前演示包：[Campus-1.0.0+1-preview.apk](./Campus-1.0.0+1-preview.apk)

| 项目 | 值 |
| --- | --- |
| App 版本 | `1.0.0+1`（`apps/mobile/pubspec.yaml`） |
| 构建日期 | 2026-09-24 |
| 构建模式 | Flutter `--release` |
| 签名 | Android Debug 证书，仅供演示和测试安装；**不是正式发布签名** |
| 大小 | 57,848,497 字节（约 55.2 MiB） |
| SHA-256 | `41DFB05F334B463A62D6558D7E7722B6F6574101243B16CAC48D6DA5B10430F6` |

此前的调试包位于 `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`，属于可清理的构建缓存，不在本目录维护；它不能替代这里的 release 模式预览包。

更新安装包时，先修改 `apps/mobile/pubspec.yaml` 中的版本号，再在 `apps/mobile` 运行 `flutter build apk --release`。构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`。将它复制到本目录，以 `Campus-<版本>-preview.apk` 命名，并同步更新本文件的版本、日期、大小和 SHA-256。Windows 可用 `Get-FileHash <APK路径> -Algorithm SHA256` 核对文件。不要把密钥或 `key.properties` 放进本目录。

正式对外发布前，需配置独立的生产签名，并将产物与说明中的“preview / Debug 证书”标识一并更新；仅仅使用 `--release` 构建并不等于已完成正式签名。
