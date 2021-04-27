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
  Map<String, dynamic Function(Map<String, dynamic>?)> get objectCreators;
}

/// Supports classes with normal fields.
/// Instead of always keeping field values in the `attributes` field,
/// the fields and their values are only written/read on demand when needed.
abstract class OnDemandSerializable {
  /// Sets all field keys and values in the specified [attributes] map.
  /// This method is called before the serialization.
  ///
  /// Note: if you have complex fields such as nested objects, non generic lists or maps, you need to implement
  /// both `Serializable` and `OnDemandSerializable`, extend `SerializableObject` and implement `OnDemandSerializable`,
  /// or specify the corresponding `transformers` and `objectCreators` in the `Serializer` on demand methods.
  ///
  /// Compare `Serializer.serializeOnDemand()` and `Serializer.deserializeOnDemand()` methods.
  /// ```dart
  /// attributes['name'] = name;
  /// attributes['price'] = price;
  /// ```
  void write(Map<String, dynamic> attributes);

  /// Reads all field keys and values from the specified [attributes] map.
  /// This method is called after the de-serialization.
  ///
  /// Note: if you have complex fields such as nested objects, non generic lists or maps, you need to implement
  /// both `Serializable` and `OnDemandSerializable`, extend `SerializableObject` and implement `OnDemandSerializable`,
  /// or specify the corresponding `transformers` and `objectCreators` in the `Serializer` on demand methods.
  ///
  /// Compare `Serializer.serializeOnDemand()` and `Serializer.deserializeOnDemand()` methods.
  /// ```dart
  /// name = attributes['name'];
  /// price = attributes['price'];
  /// ```
  void read(Map<String, dynamic> attributes);
}

/// Implementation of [Serializable].
/// Extend this class if in doubt. Use the `attributes` field to store and retrieve values, e.g.
/// ```dart
///  int get price => attributes['price'];
///  set price(int value) => attributes['price'] = value;
/// ```
/// Define creators and transformers as necessary in `objectCreators` and `transformers`.
class SerializableObject implements Serializable {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic Function(dynamic)> _transformers = {};
  final Map<String, dynamic Function(Map<String, dynamic>?)> _objectCreators =
      {};
  @override
  Map<String, dynamic> get attributes => _attributes;

  @override
  Map<String, dynamic Function(dynamic)> get transformers => _transformers;

  @override
  Map<String, dynamic Function(Map<String, dynamic>?)> get objectCreators =>
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

  /// Serializes the given list of [serializables].
  /// Generates the JSON text representation.
  String serializeList(List<Serializable> serializables) {
    final buffer = StringBuffer();
    _serializeValue(null, null, serializables, buffer);
    return buffer.toString();
  }

  /// Serializes an OnDemandSerializable object.
  String serializeOnDemand(OnDemandSerializable onDemandSerializable,
      {Map<String, dynamic Function(dynamic)>? transformers}) {
    if (onDemandSerializable is Serializable) {
      final serializable = onDemandSerializable as Serializable;
      onDemandSerializable.write(serializable.attributes);
      return serialize(serializable);
    }
    final genericSerializable = SerializableObject();
    if (transformers != null) {
      genericSerializable.transformers.addAll(transformers);
    }
    onDemandSerializable.write(genericSerializable.attributes);
    return serialize(genericSerializable);
  }

  /// Deserializes the given [jsonText] into the specified serializable [target].
  void deserialize(String jsonText, Serializable target) {
    final decoder = JsonDecoder();
    final json = decoder.convert(jsonText) as Map<String, dynamic>;
    _deserializeAttributes(json, target);
  }

  /// Deserializes the given [jsonText] into the specified list of serializables [target].
  void deserializeList(String jsonText, List<Serializable> targetList,
      Serializable Function(Map<String, dynamic>) creator) {
    final decoder = JsonDecoder();
    final jsonList = decoder.convert(jsonText) as List<dynamic>;
    for (final json in jsonList) {
      final target = creator(json);
      _deserializeAttributes(json, target);
      targetList.add(target);
    }
  }

  /// Deserializes the specied [jsonText] into the OnDemandSerializable [target].
  /// Specify [transformers] to transform values such as enums or non-String Map keys.
  /// Specify [objectCreators] when you have Lists, Map or nested objects.
  void deserializeOnDemand(String jsonText, OnDemandSerializable target,
      {Map<String, dynamic Function(dynamic)>? transformers,
      Map<String, dynamic Function(Map<String, dynamic>?)>? objectCreators}) {
    if (target is Serializable) {
      final serializable = target as Serializable;
      deserialize(jsonText, serializable);
      target.read(serializable.attributes);
    }
    final genericSerializable = SerializableObject();
    if (transformers != null) {
      genericSerializable.transformers.addAll(transformers);
    }
    if (objectCreators != null) {
      genericSerializable.objectCreators.addAll(objectCreators);
    }
    deserialize(jsonText, genericSerializable);
    target.read(genericSerializable.attributes);
  }

  void _serializeAttributes(Serializable? parent,
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

  void _serializeValue(Serializable? parent, final String? key,
      final dynamic value, final StringBuffer buffer) {
    if (value == null) {
      buffer.write('null');
    } else if (value is String) {
      final text = value.replaceAll('"', r'\"').replaceAll('\n', '\\n');
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
      final keyTransformer = parent!.transformers['$key.key'];
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
    } else if (value is OnDemandSerializable) {
      final genericSerializable = SerializableObject();
      genericSerializable.transformers.addAll(parent!.transformers);
      value.write(genericSerializable.attributes);
      _serializeAttributes(
          genericSerializable, genericSerializable.attributes, buffer);
    } else {
      final transform = parent!.transformers[key!];
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
      [String? parentKey]) {
    for (final key in json.keys) {
      final value = json[key];
      object.attributes[key] = _deserializeValue(object, key, value);
    }
  }

  dynamic _deserializeValue(
      final Serializable parent, final String key, dynamic value) {
    final transform = parent == null ? null : parent.transformers[key];
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
      // this is a nested object or a nested map
      final dynamic Function(Map<String, dynamic>)? function =
          parent == null ? null : parent.objectCreators[key];
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
      } else if (serializableOrMap is OnDemandSerializable) {
        final genericSerializable = SerializableObject();
        genericSerializable.objectCreators.addAll(parent.objectCreators);
        genericSerializable.transformers.addAll(parent.transformers);
        _deserializeAttributes(value, genericSerializable, key);
        serializableOrMap.read(genericSerializable.attributes);
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
