/// Hàm đọc JSON an toàn (số có thể về dạng int hoặc double).
int asInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

int? asIntOrNull(dynamic v) => v is num ? v.toInt() : null;

bool asBool(dynamic v) => v == true;

String asString(dynamic v, [String fallback = '']) => v is String ? v : fallback;

List<T> asList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) =>
    v is List ? v.map((e) => fromJson(e as Map<String, dynamic>)).toList() : <T>[];
