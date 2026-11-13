/// Helper parsing JSON yang toleran terhadap null / tipe angka campuran
/// (MongoDB bisa mengirim int atau double untuk field yang sama).
library;

typedef Json = Map<String, dynamic>;

int asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String asStr(Object? v) => v == null ? '' : '$v';

bool asBool(Object? v) => v == true;

List<T> asList<T>(Object? v, T Function(Json) fromJson) =>
    v is List ? v.whereType<Map>().map((e) => fromJson(Json.from(e))).toList() : <T>[];

Map<String, String> asStrMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', asStr(val))) : <String, String>{};
