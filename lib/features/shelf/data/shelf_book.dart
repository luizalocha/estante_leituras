enum ReadingStatus {
  wantToRead('quero_ler', 'Quero ler'),
  reading('lendo', 'Lendo'),
  read('lido', 'Lido');

  const ReadingStatus(this.code, this.label);

  /// Valor gravado no Firestore (validado em firestore.rules).
  final String code;
  final String label;

  static ReadingStatus fromCode(Object? code) =>
      ReadingStatus.values.firstWhere((s) => s.code == code,
          orElse: () => ReadingStatus.wantToRead);
}

/// Livro na estante de um usuário. Documento da coleção `books` no Firestore.
class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.author,
    this.year,
    this.coverUrl,
    this.workKey,
    this.status = ReadingStatus.wantToRead,
    this.rating = 0,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  static const maxTitle = 200;
  static const maxNotes = 1000;

  final String id;

  /// UID do dono. As regras do Firestore só liberam o documento para ele.
  final String ownerId;
  final String title;
  final String author;
  final int? year;
  final String? coverUrl;
  final String? workKey;
  final ReadingStatus status;

  /// 0 = sem nota; 1 a 5 estrelas.
  final int rating;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShelfBook copyWith({
    String? id,
    ReadingStatus? status,
    int? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShelfBook(
      id: id ?? this.id,
      ownerId: ownerId,
      title: title,
      author: author,
      year: year,
      coverUrl: coverUrl,
      workKey: workKey,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Campos gravados no Firestore (datas são adicionadas pelo Source).
  Map<String, Object?> toFirestoreFields() => {
        'ownerId': ownerId,
        'title': title,
        'author': author,
        'year': year,
        'coverUrl': coverUrl,
        'workKey': workKey,
        'status': status.code,
        'rating': rating,
        'notes': notes,
      };

  /// Formato do cache local (JSON).
  Map<String, Object?> toJson() => {
        'id': id,
        ...toFirestoreFields(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ShelfBook.fromMap(String id, Map<String, Object?> map) {
    DateTime? date(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final rating = map['rating'];
    final year = map['year'];
    return ShelfBook(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      title: map['title'] as String? ?? '(sem título)',
      author: map['author'] as String? ?? 'Autor desconhecido',
      year: year is int ? year : null,
      coverUrl: map['coverUrl'] as String?,
      workKey: map['workKey'] as String?,
      status: ReadingStatus.fromCode(map['status']),
      rating: rating is int && rating >= 0 && rating <= 5 ? rating : 0,
      notes: map['notes'] as String? ?? '',
      createdAt: date(map['createdAt']),
      updatedAt: date(map['updatedAt']),
    );
  }

  factory ShelfBook.fromJson(Map<String, Object?> json) =>
      ShelfBook.fromMap(json['id'] as String, json);
}
