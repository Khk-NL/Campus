# Campulse Android 安装包

当前版本：[Campulse-latest.apk](./Campulse-latest.apk)。也可从 [GitHub Release](https://github.com/Khk-NL/Campus/releases/tag/campulse-preview) 下载。

安装包由 GitHub Actions 自动构建，不使用本地打包脚本发布。推送移动端或构建配置到 main 后，会运行检查与测试、构建连接公网服务的 APK、校验证书并更新本目录。

版本 1.1.0；Android 版本代码为 `1000 + GitHub 构建序号`。构建来源见 [Campulse-latest.json](./Campulse-latest.json)，文件校验见 [Campulse-latest.apk.sha256](./Campulse-latest.apk.sha256)。

Android 包名保留 `cn.campus.campus_mobile`。预览证书 MD5 为 `3b8a0599b4ce81f2f2932c8121c8b4e4`；这是应用签名，不是 APK 文件校验值。

## 旧版归档

[Campus-1.0.0+2-preview.apk](./Campus-1.0.0+2-preview.apk)

| 项目 | 值 |
| --- | --- |
| App 版本 | `1.0.0+2`（`apps/mobile/pubspec.yaml`） |
| 构建日期 | 2026-09-24 |
| 构建模式 | Flutter `--release` |
| 签名 | Android Debug 证书，仅供演示和测试安装；**不是正式发布签名** |
| 大小 | 57,848,405 字节（约 55.2 MiB） |
| SHA-256 | `0B95B8F2CA37DACC27F4664428EB08C5FD18F50FDFED9AFDE559CA3D9CE74A54` |

此前的调试包位于 `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`，属于可清理的构建缓存，不在本目录维护；它不能替代这里的 release 模式预览包。

上述构建信息仅对应旧版归档。旧文件名称不更改，避免破坏已有下载链接。今后使用 GitHub Actions 发布；不要把密钥或 `key.properties` 放进本目录。

上一版：[Campus-1.0.0+1-preview.apk](./Campus-1.0.0+1-preview.apk)。

正式对外发布前，需配置独立的生产签名，并将产物与说明中的“preview / Debug 证书”标识一并更新；仅仅使用 `--release` 构建并不等于已完成正式签名。
