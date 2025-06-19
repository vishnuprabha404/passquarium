class PasswordEntry {
  final String id;
  final String website;
  final String domain;
  final String username;
  final String encryptedPassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordEntry({
    required this.id,
    required this.website,
    required this.domain,
    required this.username,
    required this.encryptedPassword,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] ?? '',
      website: map['website'] ?? '',
      domain: map['domain'] ?? '',
      username: map['username'] ?? '',
      encryptedPassword: map['encrypted_password'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'website': website,
      'domain': domain,
      'username': username,
      'encrypted_password': encryptedPassword,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PasswordEntry copyWith({
    String? id,
    String? website,
    String? domain,
    String? username,
    String? encryptedPassword,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      website: website ?? this.website,
      domain: domain ?? this.domain,
      username: username ?? this.username,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PasswordEntry(id: $id, website: $website, domain: $domain, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PasswordEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 