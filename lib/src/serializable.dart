import 'dart:convert';

/// Basic interface for serializable classes.
/// Consider to extends `SerializableObject` for a simpler implementation,
/// but `Serializable` is not complex to implement.
abstract class Serializable {
  /// Holds all values that should be serialized.
  /// Can either be generated upon demand or used all the time.
  /// Example for using attributes as the data store:
  /// ```
  ///  MySerializableEnum get myEnum => attributes['my-enum'];
  ///  set myEnum(MySerializableEnum value) => attributes['my-enum'] = value;
  /// ```
  Map<String, dynamic> get attributes;

  /// Define any transformations for values.
  /// You can transform an enumeration to an int and the other way round:
  /// ```dart
  ///    transformers['my-enum'] = (value) => value is MySerializableEnum
  ///        ? value.index
  ///        : MySerializableEnum.values[value];
  /// ```
  /// You can also transform `Map` keys and `Map` or `List` values by using the
  /// parent's key with `.key` appended, this is required when you have non-`String` keys in your `Map`:
  /// ```dart
  ///   // example for transformation of `int` keys of a map:
  ///    transformers['my-map.key'] = (value) => value is int ? value.toString() : int.parse(value);
  /// ```
  Map<String, dynamic Function(dynamic)> get transformers;

  /// Define functions that create new complex serializable or Map instances for nested objects.
  /// You can evaluate the provided map value to select a specific subclass, if needed.
  /// ```
  ///   objectCreators['my-serializable'] = (map) => MySerializable();
  ///   objectCreators['event'] = (map) => map['type'] == 0 ? StartEvent() : EndEvent();
  ///   objectCreators['my-list'] = (map) => <String>[]; // for lists the map parameter will be null
  ///   objectCreators['my-map'] = (map) => <int, MySerializable>{};
  ///   objectCreators['my-map.value'] = (map) => MySerializable();
  ///```
  ///
  Map<String, dynamic Function(Map<String, dynamic>)> get objectCreators;
}

/// Implementation of `Serializable`.
/// Extend this class if in doubt.
class SerializableObject implements Serializable {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic Function(dynamic)> _transformers = {};
  final Map<String, dynamic Function(Map<String, dynamic>)> _objectCreators =
      {};
  @override
  Map<String, dynamic> get attributes => _attributes;

  @override
  Map<String, dynamic Function(dynamic)> get transformers => _transformers;

  @override
  Map<String, dynamic Function(Map<String, dynamic>)> get objectCreators =>
      _objectCreators;
}

/// Serializes to and deserializes from JSON.
class Serializer {
  /// Serializes the specified [serializable] instance.
  /// Generates the JSON text representation.
  String serialize(Serializable serializable) {
    final buffer = StringBuffer();
    _serializeAttributes(serializable, serializable.attributes, buffer);
    return buffer.toString();
  }

  /// Deserializes the given [jsonText] into the specified serializable [target].
  void deserialize(String jsonText, Serializable target) {
    final decoder = JsonDecoder();
    final json = decoder.convert(jsonText) as Map<String, dynamic>;
    _deserializeAttributes(json, target);
  }

  void _serializeAttributes(Serializable parent,
      final Map<String, dynamic> attributes, final StringBuffer buffer) {
    buffer.write('{');
    var writeSeparator = false;
    for (final key in attributes.keys) {
      if (writeSeparator) {
        buffer.write(', ');
      }
      buffer..write('"')..write(key)..write('": ');
      final value = attributes[key];
      _serializeValue(parent, key, value, buffer);
      writeSeparator = true;
    }
    buffer.write('}');
  }

  void _serializeValue(Serializable parent, final String key,
      final dynamic value, final StringBuffer buffer) {
    if (value == null) {
      buffer.write('null');
    } else if (value is String) {
      final text = value.replaceAll('"', r'\"');
      buffer..write('"')..write(text)..write('"');
    } else if (value is int) {
      buffer.write(value);
    } else if (value is double) {
      buffer.write(value);
    } else if (value is bool) {
      buffer.write(value);
    } else if (value is List) {
      var writeSeparator = false;
      buffer.write('[');
      for (final child in value) {
        if (writeSeparator) {
          buffer.write(', ');
        }
        _serializeValue(parent, key, child, buffer);
        writeSeparator = true;
      }
      buffer.write(']');
    } else if (value is Map<String, dynamic>) {
      _serializeAttributes(parent, value, buffer);
    } else if (value is Map) {
      final keyTransformer = parent.transformers['$key.key'];
      if (keyTransformer == null) {
        throw StateError(
            'Invalid map with non-String keys encountered, unable to serialize: "$key": $value. Define a corresponding transformer "$key.key" to transform the keys of this map to String.');
      }
      final transformedMap = <String, dynamic>{};
      for (var mapKey in value.keys) {
        transformedMap[keyTransformer(mapKey)] = value[mapKey];
      }
      _serializeAttributes(parent, transformedMap, buffer);
    } else if (value is Serializable) {
      _serializeAttributes(value, value.attributes, buffer);
    } else {
      final transform = parent.transformers[key];
      if (transform == null) {
        throw StateError(
            'Invalid value encountered, unable to serialize: "$key": $value. Define a corresponding transformer.');
      }
      final transformedValue = transform(value);
      _serializeValue(parent, key, transformedValue, buffer);
    }
  }

  void _deserializeAttributes(
      final Map<String, dynamic> json, final Serializable object,
      [String parentKey]) {
    for (final key in json.keys) {
      final value = json[key];
      object.attributes[key] = _deserializeValue(object, key, value);
    }
  }

  dynamic _deserializeValue(
      final Serializable parent, final String key, dynamic value) {
    final transform = parent.transformers[key];
    if (transform != null) {
      return transform(value);
    }
    if (value == null ||
        value is String ||
        value is int ||
        value is double ||
        value is bool) {
      return value;
    } else if (value is List) {
      final function = parent.objectCreators[key];
      if (function == null) {
        throw StateError(
            'Deserialization Warning: no objectCreator for List "$key" defined.');
      }
      final listValue = function(null);
      for (final subValue in value) {
        listValue.add(_deserializeValue(parent, '$key.value', subValue));
      }
      return listValue;
    } else if (value is Map<String, dynamic>) {
      // this is a complex object
      final function = parent.objectCreators[key];
      if (function == null) {
        throw StateError(
            'Unknown map or serializable  for object "$key": please define a corresponding objectCreator.');
      }
      final serializableOrMap = function(value);
      if (serializableOrMap is Serializable) {
        _deserializeAttributes(value, serializableOrMap, key);
      } else if (serializableOrMap is Map) {
        final keyTransformer = parent.transformers['$key.key'];
        for (final subKey in value.keys) {
          dynamic mapKey = subKey;
          if (keyTransformer != null) {
            mapKey = keyTransformer(subKey);
          }
          final deserializedValue =
              _deserializeValue(parent, '$mapKey.value', value[subKey]);
          serializableOrMap[mapKey] = deserializedValue;
        }
      } else {
        throw StateError(
            'Unsupported type ${serializableOrMap.runtimeType} for field "$key" - please return either Serializable or Map in your objectCreator.');
      }
      return serializableOrMap;
    } else {
      throw StateError(
          'Unsupported type ${value.runtimeType} for element "$key". Define a corresponding transformer.');
    }
  }
}
