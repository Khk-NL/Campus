/// 内置 WebView 页面 / the in-app WebView screen (§7).
///
/// §7：web 目标**优先内置 WebView**，只有在 WebView 打不开时才回退系统浏览器。这个页面
/// 就是"优先内置"那一步；它自带两条回退：
///
///   1. 页面加载失败（网络不通、站点拒绝被嵌入）→ 给出失败说明与「用浏览器打开」；
///   2. 平台没有 WebView 实现 → [CampusLauncher] 根本不会推入本页，直接走系统浏览器。
///
/// §7 asks web targets to prefer the in-app WebView and fall back to the system browser.
/// This screen is the "prefer" step, and it carries two fallbacks of its own: a failed load
/// offers the browser explicitly, and a platform without a WebView implementation never
/// reaches this screen at all — the launcher goes straight to the browser.
library;

import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 在内置 WebView 里打开一个网页 / open one page in the in-app WebView.
class WebViewLaunchPage extends StatefulWidget {
  const WebViewLaunchPage({required this.url, this.fallbackUrl, super.key});

  /// 要打开的地址 / the URL to open.
  final String url;

  /// 站内失败时改用哪个地址 / the URL to try when this one fails.
  final String? fallbackUrl;

  @override
  State<WebViewLaunchPage> createState() => _WebViewLaunchPageState();
}

class _WebViewLaunchPageState extends State<WebViewLaunchPage> {
  WebViewController? _controller;

  /// 主文档加载失败了吗 / whether the main document failed to load.
  bool _failed = false;

  /// 是否仍在加载 / whether the page is still loading.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 这里**不**读 InheritedWidget：initState 里读会触发断言（见 CampusRepositoryScope）。
    // No InheritedWidget is read here: doing that in initState trips an assertion (see
    // CampusRepositoryScope for the full explanation).
    _controller = _buildController();
  }

  /// 构造控制器；平台没有 WebView 实现时返回 null 并进入失败态。
  /// Build the controller; when the platform has no WebView implementation this returns null
  /// and the screen shows its failure state.
  WebViewController? _buildController() {
    try {
      return WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) => _update(() => _loading = true),
            onPageFinished: (String url) => _update(() => _loading = false),
            onWebResourceError: (WebResourceError error) {
              // 只对主文档报错：子资源（图片、脚本）失败不该把整页判死。
              // Only a main-document failure counts; a broken sub-resource should not
              // condemn the page.
              if (error.isForMainFrame == false) return;
              _update(() {
                _failed = true;
                _loading = false;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } on Object {
      _failed = true;
      _loading = false;
      return null;
    }
  }

  /// 安全地更新状态：回调可能在页面已经销毁之后到达。
  /// Update state safely; a callback may arrive after the screen is gone.
  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  /// 用系统浏览器打开（§7 的回退分支）。
  /// Open in the system browser, §7's fallback branch.
  Future<void> _openInBrowser() async {
    final Uri? uri = Uri.tryParse(widget.fallbackUrl ?? widget.url);
    if (uri == null) return;
    await openUrlExternally(uri);
  }

  void _retry() {
    final WebViewController? controller = _controller;
    setState(() {
      _failed = false;
      _loading = true;
    });
    if (controller == null) {
      setState(() => _controller = _buildController());
      return;
    }
    controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Uri? uri = Uri.tryParse(widget.url);
    final String title = (uri != null && uri.host.isNotEmpty) ? uri.host : l10n.serviceTypeWeb;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.actionRefresh,
            onPressed: _retry,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: l10n.launchOpenInBrowser,
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _failed
          ? _failure(context, l10n, theme)
          : Stack(
              children: <Widget>[
                if (_controller != null) WebViewWidget(controller: _controller!),
                if (_loading)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
    );
  }

  /// 加载失败时的说明与两个出口 / what a failed load offers.
  Widget _failure(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.public_off, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              l10n.launchWebViewFailed,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: Text(l10n.launchOpenInBrowser),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _retry, child: Text(l10n.actionRetry)),
          ],
        ),
      ),
    );
  }
}
