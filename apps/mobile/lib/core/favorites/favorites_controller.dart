import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:flutter/foundation.dart';

// ignore_for_file: prefer_initializing_formals

/// The directory is global; favorite records are isolated by user and board.
class FavoritesController extends ChangeNotifier {
  FavoritesController({required PreferenceStore preferences})
    : _preferences = preferences;
  final PreferenceStore _preferences;
  final Map<String, Set<String>> _cache = {};
  final Set<String> _busy = {};
  String? _userId;
  CampusFavoritesRepository? _remote;
  int _generation = 0;
  Future<void>? _hydrating;

  String _storageKey(String board) =>
      _userId == null ? board : 'user:$_userId:$board';
  Set<String> keysOf(String board) => _cache.putIfAbsent(
    board,
    () => _preferences.readFavoriteKeys(_storageKey(board)),
  );
  bool contains(String board, String key) => keysOf(board).contains(key);

  Future<void> bindUser(String? id, {CampusFavoritesRepository? remote}) async {
    final generation = ++_generation;
    _userId = id;
    _remote = id == null ? null : remote;
    _cache.clear();
    _busy.clear();
    _hydrating = null;
    notifyListeners();
    if (_remote == null) return;
    final task = _hydrate(id!, generation, _remote!);
    _hydrating = task;
    try {
      await task;
    } finally {
      if (generation == _generation) _hydrating = null;
    }
  }

  Future<void> _hydrate(
    String id,
    int generation,
    CampusFavoritesRepository remote,
  ) async {
    final result = await remote.fetchFavorites();
    if (generation != _generation) return;
    final boards = {
      ..._preferences.readFavoriteBoards(id),
      ...result.keys,
      ..._cache.keys,
    };
    for (final board in boards) {
      if (generation != _generation) return;
      _cache[board] = result[board] ?? <String>{};
      await _preferences.writeFavoriteKeys('user:$id:$board', _cache[board]!);
    }
    await _preferences.writeFavoriteBoards(id, boards);
    if (generation == _generation) notifyListeners();
  }

  Future<void> toggle(String board, String key) async {
    final started = _generation;
    await _hydrating;
    if (started != _generation) return;
    final operation = '$board:$key', generation = _generation;
    if (!_busy.add(operation)) return;
    final storageKey = _storageKey(board),
        selected = !contains(board, key),
        userId = _userId;
    try {
      await _remote?.setFavorite(board, key, selected);
      if (generation != _generation) return;
      final keys = keysOf(board);
      if (selected) {
        keys.add(key);
      } else {
        keys.remove(key);
      }
      notifyListeners();
      await _preferences.writeFavoriteKeys(storageKey, keys);
      if (userId != null) {
        await _preferences.writeFavoriteBoards(userId, {
          ..._preferences.readFavoriteBoards(userId),
          board,
        });
      }
    } finally {
      if (generation == _generation) _busy.remove(operation);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
