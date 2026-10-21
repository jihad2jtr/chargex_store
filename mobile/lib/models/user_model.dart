class UserModel {
  final String id;
  final String? userId; // Unique client-facing ID (e.g., 8-digit numeric ID)
  final String name;
  final String email;
  final String role; // 'admin' | 'user'
  final double balance;
  final String? phone;
  final String? token;
  final String? refreshToken;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.balance = 0.0,
    this.phone,
    this.token,
    this.refreshToken,
    this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isSupervisor => role.toLowerCase() == 'supervisor';
  bool get isAgent => role.toLowerCase() == 'agent';

  /// Returns the unique custom userId if present, otherwise falls back to MongoDB id
  String get displayId => (userId != null && userId!.isNotEmpty) ? userId! : id;

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token, String? refreshToken}) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? json['customUserId'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      balance: (json['balance'] is num) ? (json['balance'] as num).toDouble() : 0.0,
      phone: json['phone'],
      token: token ?? json['token'],
      refreshToken: refreshToken ?? json['refreshToken'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'balance': balance,
      'phone': phone,
      'token': token,
      'refreshToken': refreshToken,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? role,
    double? balance,
    String? phone,
    String? token,
    String? refreshToken,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      balance: balance ?? this.balance,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
