import 'auth_response.dart';

class MeResponse {
  final AuthUser user;
  final String role;
  final List<String>? modules;
  final List<String>? permissions;

  MeResponse({
    required this.user,
    required this.role,
    this.modules,
    this.permissions,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    List<String>? parsedModules;
    final rawModules = json['modules'];
    if (rawModules is Map<String, dynamic>) {
      final keys = <String>[];
      rawModules.forEach((group, items) {
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic> && item['target'] != null) {
              keys.add(item['target'] as String);
            }
          }
        }
      });
      parsedModules = keys;
    } else if (rawModules is List) {
      parsedModules = rawModules.cast<String>();
    }

    return MeResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      role: json['role'] as String,
      modules: parsedModules,
      permissions: (json['permissions'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'role': role,
        'modules': modules,
        'permissions': permissions,
      };
}
