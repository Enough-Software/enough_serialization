// Problems:
// - how to create class for a nested objects when de-serializing?
// -> possible solution: create "Serializable Function creator(String name)"
// -> but what if there are several hierarchies of nested objects?

import 'dart:convert';

abstract class Serializable {
  Map<String, dynamic> get attributes;
  Map<String, dynamic Function(dynamic)> get transformers;
  Map<String, dynamic Function()> get deserializers;
}

class SerializableObject implements Serializable {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic Function(dynamic)> _transformers = {};
  final Map<String, dynamic Function()> _deserializers = {};

  @override
  Map<String, dynamic> get attributes => _attributes;

  @override
  Map<String, dynamic Function()> get deserializers => _deserializers;

  @override
  Map<String, dynamic Function(dynamic)> get transformers => _transformers;
}

class Serializer {
  String serialize(Serializable serializable) {
    final buffer = StringBuffer();
    _serializeAttributes(serializable, serializable.attributes, buffer);
    return buffer.toString();
  }

  void deserialize(String jsonText, Serializable object) {
    final decoder = JsonDecoder();
    final json = decoder.convert(jsonText) as Map<String, dynamic>;
    _deserializeAttributes(json, object);
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
    } else if (value is Serializable) {
      _serializeAttributes(value, value.attributes, buffer);
    } else {
      final transform = parent.transformers[key];
      if (transform == null) {
        throw StateError(
            'Invalid value encountered, unable to serialize: "$key": $value');
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
    if (value is String || value is int || value is double || value is bool) {
      return value;
    } else if (value is List) {
      final function = parent.deserializers[key];
      if (function == null) {
        throw StateError(
            'Deserialization Warning: no deserializer for List "$key" defined.');
      }
      final listValue = function();
      for (final subValue in value) {
        listValue.add(_deserializeValue(parent, key, subValue));
      }
      return listValue;
    } else if (value is Map<String, dynamic>) {
      // this is a complex object
      final function = parent.deserializers[key];
      if (function == null) {
        throw StateError(
            'Deserialization Warning: no deserializer for object "$key" defined.');
      }
      final serializable = function() as Serializable;
      if (serializable == null) {
        throw StateError(
            'Deserialization Warning: deserializer for object "$key" creates non-serializable object${function()}.');
      }
      _deserializeAttributes(value, serializable, key);
      return serializable;
    } else {
      throw StateError(
          'Unsupported type ${value.runtimeType} for element "$key".');
    }
  }
}
