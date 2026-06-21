import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';

/// Creates a deep copy of [message] with all `id` fields (field tag 1, named
/// "id", 64-bit integer type) regenerated via [nextId].
///
/// Recursively processes all nested messages, including `google.protobuf.Any`
/// packed messages, so ids at every nesting level are regenerated.
///
/// This is used when pasting/duplicating components to avoid id collisions in
/// the chunk system.
GeneratedMessage regenerateIds(
  GeneratedMessage message,
  Int64 Function() nextId,
  TypeRegistry typeRegistry,
) {
  final copy = message.deepCopy();
  _regenerateIdsInPlace(copy, nextId, typeRegistry);
  return copy;
}

void _regenerateIdsInPlace(
  GeneratedMessage message,
  Int64 Function() nextId,
  TypeRegistry typeRegistry,
) {
  // If it has field tag 1, name is "id", and type is int64/uint64, generate a new one
  if (message.info_.fieldInfo.containsKey(1)) {
    final fieldInfo = message.info_.fieldInfo[1]!;
    if (fieldInfo.name == 'id') {
      final baseType = fieldInfo.type & ~PbFieldType.REPEATED_BIT;
      final is64BitInt = baseType == PbFieldType.O6 ||
          baseType == PbFieldType.OS6 ||
          baseType == PbFieldType.OU6 ||
          baseType == PbFieldType.OF6 ||
          baseType == PbFieldType.OSF6 ||
          baseType == PbFieldType.Q6 ||
          baseType == PbFieldType.QS6 ||
          baseType == PbFieldType.QU6 ||
          baseType == PbFieldType.QF6 ||
          baseType == PbFieldType.QSF6;
      if (is64BitInt) {
        message.setField(1, nextId());
      }
    }
  }

  // Recursively process fields
  for (final fieldId in message.info_.fieldInfo.keys) {
    final fieldInfo = message.info_.fieldInfo[fieldId]!;
    if (fieldId == 1 && fieldInfo.name == 'id') continue;

    final value = message.getField(fieldId);

    if (value is GeneratedMessage) {
      if (value is Any) {
        final unpacked = _unpackAny(value, typeRegistry);
        if (unpacked != null) {
          _regenerateIdsInPlace(unpacked, nextId, typeRegistry);
          message.setField(fieldId, Any.pack(unpacked));
        }
      } else {
        _regenerateIdsInPlace(value, nextId, typeRegistry);
      }
    } else if (value is List) {
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is GeneratedMessage) {
          if (item is Any) {
            final unpacked = _unpackAny(item, typeRegistry);
            if (unpacked != null) {
              _regenerateIdsInPlace(unpacked, nextId, typeRegistry);
              value[i] = Any.pack(unpacked);
            }
          } else {
            _regenerateIdsInPlace(item, nextId, typeRegistry);
          }
        }
      }
    } else if (value is Map) {
      for (final key in value.keys) {
        final item = value[key];
        if (item is GeneratedMessage) {
          if (item is Any) {
            final unpacked = _unpackAny(item, typeRegistry);
            if (unpacked != null) {
              _regenerateIdsInPlace(unpacked, nextId, typeRegistry);
              value[key] = Any.pack(unpacked);
            }
          } else {
            _regenerateIdsInPlace(item, nextId, typeRegistry);
          }
        }
      }
    }
  }
}

GeneratedMessage? _unpackAny(Any any, TypeRegistry typeRegistry) {
  final typeUrlParts = any.typeUrl.split('/');
  final qualifiedName = typeUrlParts.last;
  final builderInfo = typeRegistry.lookup(qualifiedName);
  if (builderInfo == null) return null;
  final createEmptyInstance = builderInfo.createEmptyInstance;
  if (createEmptyInstance == null) return null;
  final payload = createEmptyInstance();
  any.unpackInto(payload);
  return payload;
}
