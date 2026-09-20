class User {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final int trophies;
  final int gamesPlayed;
  final int gamesWon;
  final DateTime createdAt;
  final DateTime lastSeen;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.trophies = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    required this.createdAt,
    required this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'],
      trophies: json['trophies'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      gamesWon: json['gamesWon'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastSeen: DateTime.parse(json['lastSeen'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'trophies': trophies,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    int? trophies,
    int? gamesPlayed,
    int? gamesWon,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      trophies: trophies ?? this.trophies,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0.0;
}
