class LoginResponse {
  final String token;
  final String? tokenType;
  final int? expiresIn;

  LoginResponse({
    required this.token,
    this.tokenType,
    this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: (json['access_token'] ?? json['token']) as String,
        tokenType: json['token_type'] as String?,
        expiresIn: json['expires_in'] as int?,
      );
}

class AuthUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        photoUrl: json['photo'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'photo': photoUrl,
      };
}
