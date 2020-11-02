import 'dart:convert';

import 'package:enough_serialization/src/serializable.dart';
import 'package:test/test.dart';

void main() {
  group('Serilization Tests', () {
    MySerializable mySerializable;

    setUp(() {
      final child = MySerializable()
        ..myText = 'hi this is the child element'
        ..myNumber = 23
        ..myChild = null;
      mySerializable = MySerializable()
        ..myNumber = 13
        ..myEnum = MySerializableEnum.value3
        ..myText = 'Hello "World"'
        ..myList = ['one', 'two', 'three']
        ..myChild = child;
    });

    test('Serialize', () {
      final serializer = Serializer();
      final json = serializer.serialize(mySerializable);
      print(json);
      expect(json, isNotNull);
      final decoded = JsonCodec().decode(json);
      expect(decoded, isNotNull);
      print(decoded);
    });

    test('Deserialize', () {
      final jsonText =
          r'{"my-number": 13, "my-enum": 2, "my-text": "Hello \"World\"", "my-list": ["one", "two", "three"], "my-serializable": {"my-text": "hi this is the child element", "my-number": 23}}';

      final serializer = Serializer();
      final serializable = MySerializable();
      serializer.deserialize(jsonText, serializable);
      expect(serializable.myNumber, 13);
      expect(serializable.myEnum, MySerializableEnum.value3);
      expect(serializable.myText, 'Hello "World"');
      expect(serializable.myList, isNotEmpty);
      expect(serializable.myList.length, 3);
      expect(serializable.myList, ['one', 'two', 'three']);
      expect(serializable.myChild, isNotNull);
      expect(serializable.myChild.myText, 'hi this is the child element');
      expect(serializable.myChild.myNumber, 23);
    });
  });
}

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
