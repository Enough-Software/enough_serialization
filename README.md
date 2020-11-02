
Serialize to and deserialize from JSON in runtime. 
This pure Dart library does not depend on build time generation.

## Installation

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_serialization: ^1.0.0
```
The latest version or `enough_serialization` is [![enough_serialization version](https://img.shields.io/pub/v/enough_serialization.svg)](https://pub.dartlang.org/packages/enough_serialization).


## Usage

A simple usage example:

```dart
import 'package:enough_serialization/enough_serialization.dart';

enum MySerializableEnum { value1, value2, value3 }

class MySerializable extends SerializableObject {
  MySerializable() {
    deserializers['my-list'] = () => <String>[];
    deserializers['my-serializable'] = () => MySerializable();
    transformers['my-enum'] = (value) => value is MySerializableEnum
        ? value.index
        : MySerializableEnum.values[value];
  }

  MySerializableEnum get myEnum => attributes['my-enum'];
  set myEnum(MySerializableEnum value) => attributes['my-enum'] = value;

  int get myNumber => attributes['my-number'];
  set myNumber(int value) => attributes['my-number'] = value;

  String get myText => attributes['my-text'];
  set myText(String value) => attributes['my-text'] = value;

  List<String> get myList => attributes['my-list'];
  set myList(List<String> value) => attributes['my-list'] = value;

  MySerializable get myChild => attributes['my-serializable'];
  set myChild(MySerializable value) => attributes['my-serializable'] = value;
}

void main() {
  final json = serialize();
  print('seralized: $json');
  final deserialized = deserialize(json);
  print('deserialized: $deserialized');
}

String serialize() {
  final child = MySerializable()
    ..myText = 'hi this is the child element'
    ..myNumber = 23
    ..myChild = null;
  final parent = MySerializable()
    ..myNumber = 13
    ..myEnum = MySerializableEnum.value2
    ..myText = 'Hello "World"'
    ..myList = ['one', 'two', 'three']
    ..myChild = child;
  final serializer = Serializer();
  final json = serializer.serialize(parent);
  return json;
}

MySerializable deserialize(String json) {
  final serializer = Serializer();
  final mySerializable = MySerializable();
  serializer.deserialize(json, mySerializable);
  return mySerializable;
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Enough-Software/enough_serialization/issues

## License

Licensed under the [MIT License](LICENSE).