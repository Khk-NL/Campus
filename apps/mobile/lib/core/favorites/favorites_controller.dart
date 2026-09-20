/// 按板块隔离的收藏 / favorites, isolated per board.
///
/// 「应用」Tab 的三个分组各有**一份自己的收藏**：收藏是"我在这一组里常用什么"，因此
/// 一组里的勾选不会改变另一组的排序，也不会让同一门服务在两处被收藏（服务本身只属于
/// 一组，见 `ServiceGrouping`）。
///
/// 这一层刻意做得很薄，而且**不认识任何高校**：它只知道"有若干板块，每个板块是一组键"。
/// 板块 id 与键都由调用方给出（`ServiceGrouping.favoriteScopeOf` / `favoriteKeyOf`），
/// 因此通用层不出现任何校名或具体分组名。
///
/// Each of the Apps tab's three groups has **its own** favorite list: a favorite means "what I
/// use in this group", so ticking one group never reorders another, and the same service is
/// never favorited twice (a service belongs to exactly one group — see `ServiceGrouping`).
///
/// This layer is deliberately thin and **knows no university**: it only knows that several
/// boards exist and that each holds a set of keys. Both the board ids and the keys come from
/// the caller, so the generic layer names no school and no concrete group.
library;

// 私有字段无法用 `this.` 形参初始化（Dart 不允许下划线开头的具名形参），因此本文件有意
// 使用初始化列表，与 `core/app_state.dart` 的处理一致。
// A private field cannot be initialised through a `this.` formal (Dart forbids a named
// parameter starting with an underscore), so this file deliberately assigns in the
// initializer list, exactly as `core/app_state.dart` does.
// ignore_for_file: prefer_initializing_formals
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:flutter/foundation.dart';

/// 收藏的读写与通知 / reading, writing and broadcasting favorites.
class FavoritesController extends ChangeNotifier {
  FavoritesController({required PreferenceStore preferences}) : _preferences = preferences;

  final PreferenceStore _preferences;

  /// 每个板块的键集合，读一次后缓存，避免每次 build 都碰存储。
  /// One set per board, cached after the first read so a build never touches storage.
  final Map<String, Set<String>> _cache = <String, Set<String>>{};

  /// 某个板块的全部收藏键（**只读**使用；修改请走 [toggle]）。
  /// Every favorite key of one board (read-only; mutate through [toggle]).
  Set<String> keysOf(String boardId) => _cache.putIfAbsent(
        boardId,
        () => _preferences.readFavoriteKeys(boardId),
      );

  /// 某个板块里是否收藏了某个键 / whether one board has favorited a key.
  bool contains(String boardId, String key) => keysOf(boardId).contains(key);

  /// 切换收藏 / toggle a favorite.
  ///
  /// 先通知再落盘：界面必须**立刻**反映（列表马上重排），写存储晚几十毫秒无妨。
  /// Notify first, persist second: the UI must reflect the change at once (the list reorders
  /// immediately) while the write lands a few milliseconds later.
  Future<void> toggle(String boardId, String key) async {
    final Set<String> keys = keysOf(boardId);
    if (!keys.remove(key)) keys.add(key);
    notifyListeners();
    await _preferences.writeFavoriteKeys(boardId, keys);
  }
}
