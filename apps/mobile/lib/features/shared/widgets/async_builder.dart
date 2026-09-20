/// 一次性异步加载的封装 / a tiny wrapper for one-shot async loads.
///
/// 页面常见的形态是"进入时拉一次数据，然后展示"。与其让每个 Tab 各写一遍
/// `FutureBuilder` + 加载态 + 错误态，不如把这三态收在一个组件里。
///
/// Screens usually load once on entry and then render. Rather than repeat
/// `FutureBuilder` plus loading and error states in every tab, the three states live
/// here.
library;

import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// 加载 [future] 并渲染三种状态 / loads [future] and renders its three states.
class AsyncBuilder<T> extends StatefulWidget {
  const AsyncBuilder({
    required this.future,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    super.key,
  });

  /// 要加载的数据；[key] 变化时会重新加载。
  /// The data to load; a new [key] triggers a reload.
  final Future<T> future;

  /// 成功时的渲染回调 / renders the loaded value.
  final Widget Function(BuildContext context, T value) builder;

  /// 自定义加载态 / an optional custom loading state.
  final WidgetBuilder? loadingBuilder;

  /// 自定义错误态 / an optional custom error state.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<AsyncBuilder<T>> createState() => AsyncBuilderState<T>();
}

/// [AsyncBuilder] 的状态，公开是为了让页面能主动触发重载。
/// The state of [AsyncBuilder], public so a screen can trigger a reload.
class AsyncBuilderState<T> extends State<AsyncBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  @override
  void didUpdateWidget(AsyncBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.future, widget.future)) {
      _future = widget.future;
    }
  }

  /// 重新加载（由外部调用时需先换掉 future）。
  /// Reload; callers replace the future first.
  void reload(Future<T> future) {
    // 块体而非箭头体：`setState(() => _future = future)` 会把 Future 当作返回值交给
    // setState，触发 "setState() callback argument returned a Future" 断言。
    // A block body, not an arrow: `setState(() => _future = future)` hands the Future back as
    // setState's return value and trips the assertion.
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ?? const LoadingView();
        }
        final Object? error = snapshot.error;
        if (error != null) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, error);
          }
          return ErrorRetryView(details: error.toString(), onRetry: () {});
        }
        final T? value = snapshot.data;
        if (value == null) return const LoadingView();
        return widget.builder(context, value);
      },
    );
  }
}
