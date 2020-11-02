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
  /// ```
  ///    transformers['my-enum'] = (value) => value is MySerializableEnum
  ///        ? value.index
  ///        : MySerializableEnum.values[value];
  /// ```
  Map<String, dynamic Function(dynamic)> get transformers;

  /// Define functions that create new non-generic lists.
  /// ```
  ///    listCreators['my-list'] = () => <String>[];
  ///```
  Map<String, List Function()> get listCreators;

  /// Define functions that create new complex serializable instances for nested objects.
  /// You can evaluate the provided map value to select a specific subclass, if needed.
  /// ```
  ///    objectCreators['my-serializable'] = (map) => MySerializable();
  ///    objectCreators['event'] = (map) => map['type'] == 1 ? StartEvent() : EndEvent();
  ///```
  Map<String, Serializable Function(Map<String, dynamic>)> get objectCreators;
}

/// Implementation of `Serializable`.
/// Extend this class if in doubt.
class SerializableObject implements Serializable {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic Function(dynamic)> _transformers = {};
  final Map<String, List Function()> _listCreators = {};
  final Map<String, Serializable Function(Map<String, dynamic>)>
      _objectCreators = {};
  @override
  Map<String, dynamic> get attributes => _attributes;

  @override
  Map<String, List Function()> get listCreators => _listCreators;

  @override
  Map<String, dynamic Function(dynamic)> get transformers => _transformers;

  @override
  Map<String, Serializable Function(Map<String, dynamic>)> get objectCreators =>
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
    } else if (value is Serializable) {
      _serializeAttributes(value, value.attributes, buffer);
    } else {
      final transform = parent.transformers[key];
      if (transform == null) {
        throw StateError(
            'Invalid value encountered, unable to serialize: "$key": $value. Define a corresponing transformer.');
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
      final function = parent.listCreators[key];
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
      final function = parent.objectCreators[key];
      if (function == null) {
        throw StateError(
            'Deserialization Warning: no deserializer for object "$key" defined.');
      }
      final serializable = function(value);
      _deserializeAttributes(value, serializable, key);
      return serializable;
    } else {
      throw StateError(
          'Unsupported type ${value.runtimeType} for element "$key". Define a corresponding transformer.');
    }
  }
}
