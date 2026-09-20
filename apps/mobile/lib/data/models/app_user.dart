/// 学生身份 / the student identity (§6 User, §17 roles).
///
/// §17 要求不把角色写死成学校行政体系，因此这里只有平台角色联合类型，`teacher`
/// 这类校内称谓不出现在代码里。
///
/// §17 forbids hard-coding school administrative roles, so this file holds only the
/// platform role union; in-school titles never appear in code.
library;

import 'package:campus_mobile/data/models/json_utils.dart';

/// 平台级角色（§17）/ platform-wide roles (§17).
enum PlatformRole {
  user('user'),
  publisher('publisher'),
  developer('developer'),
  moderator('moderator'),
  admin('admin');

  const PlatformRole(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [user]（最小权限，§15）。
  /// Parse a wire value; unknown values fall back to [user], the least privilege
  /// option (§15).
  static PlatformRole fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final PlatformRole role in values) {
      if (role.wireValue == wire) return role;
    }
    return PlatformRole.user;
  }
}

/// 当前登录用户 / the signed-in user.
class AppUser {
  const AppUser({
    required this.id,
    required this.universityId,
    required this.externalUserId,
    required this.name,
    required this.roles,
    this.avatarUrl,
  });

  /// 用户主键 / the user id.
  final String id;

  /// 所属高校 / the owning university.
  final String universityId;

  /// 学校系统内的标识（学号）/ the id inside the school system.
  final String externalUserId;

  /// 姓名 / the display name.
  final String name;

  /// 头像 / an avatar URL.
  final String? avatarUrl;

  /// 平台角色 / platform roles.
  final List<PlatformRole> roles;

  /// 是否具备某项平台角色（§15 默认拒绝）。
  /// Whether the user holds a platform role; deny by default (§15).
  bool hasRole(PlatformRole role) => roles.contains(role);

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static AppUser? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    return AppUser(
      id: id,
      universityId: asString(json['universityId']) ?? '',
      externalUserId: asString(json['externalUserId']) ?? '',
      name: asNonEmptyString(json['name']) ?? id,
      avatarUrl: asNonEmptyString(json['avatarUrl']),
      roles: <PlatformRole>[
        for (final String role in asStringList(json['roles'])) PlatformRole.fromWire(role),
      ],
    );
  }

  @override
  String toString() => 'AppUser($id, $name)';
}
