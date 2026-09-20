/// 数据仓库的作用域 / a scope that exposes the repository to the widget tree.
///
/// 与 [AppScope] 分开是有意的：`AppScope` 持有会变化的状态（语言、主题、数据源），
/// 而仓库本身是不变的。分开之后，页面可以只订阅仓库而不被语言切换重建，反之亦然。
///
/// Kept separate from `AppScope` on purpose: `AppScope` holds mutable state (language,
/// theme, data source) while the repository never changes. Split this way, a screen can
/// depend on the repository without being rebuilt by a language switch.
library;

import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:flutter/widgets.dart';

/// 暴露仓库的 InheritedWidget / the InheritedWidget that carries the repository.
class CampusRepositoryScope extends InheritedWidget {
  const CampusRepositoryScope({
    required this.repository,
    required super.child,
    super.key,
  });

  /// 当前仓库 / the current repository.
  final CampusRepository repository;

  /// 取当前仓库，并在仓库变化时重建调用方。用于 `build()`。
  /// Read the repository and rebuild the caller when it changes. Use this in `build()`.
  static CampusRepository of(BuildContext context) {
    final CampusRepositoryScope? scope =
        context.dependOnInheritedWidgetOfExactType<CampusRepositoryScope>();
    assert(scope != null, 'CampusRepositoryScope.of() called outside the scope');
    return scope!.repository;
  }

  /// 只读一次、**不订阅**变化。用于 `initState()` 与按钮回调。
  ///
  /// 必须区分这两个方法：Flutter 禁止在 `initState()` 里调用
  /// `dependOnInheritedWidgetOfExactType` —— 此时元素尚未完成挂载，Flutter 会直接抛
  /// 断言（`dependOnInheritedWidgetOfExactType() was called before initState()
  /// completed`）。`getInheritedWidgetOfExactType` 只查询当前值、不注册依赖，因此在
  /// `initState()` 里是合法的。
  ///
  /// 这不是纯粹的风格问题：仓库在应用生命周期内不变，**不需要**订阅，用 `of()` 只会
  /// 招来那个断言。
  ///
  /// Read once **without** subscribing. Use this from `initState()` and button callbacks.
  ///
  /// The distinction is required, not stylistic: Flutter forbids
  /// `dependOnInheritedWidgetOfExactType` inside `initState()` — the element has not finished
  /// mounting and Flutter throws (`... was called before initState() completed`).
  /// `getInheritedWidgetOfExactType` only queries the current value without registering a
  /// dependency, so it is legal there. The repository never changes, so there is nothing to
  /// subscribe to anyway.
  static CampusRepository read(BuildContext context) {
    final CampusRepositoryScope? scope =
        context.getInheritedWidgetOfExactType<CampusRepositoryScope>();
    assert(scope != null, 'CampusRepositoryScope.read() called outside the scope');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(CampusRepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
