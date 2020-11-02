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
        ..myChild = child
        ..events = [
          StartEvent()..players = [232, 12, 2423, 99],
          EndEvent()..winner = 2423
        ];
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
          r'{"my-number": 13, "my-enum": 2, "my-text": "Hello \"World\"", "my-list": ["one", "two", "three"], "my-serializable": {"my-text": "hi this is the child element", "my-number": 23, "my-serializable": null}, "events": [{"type": 0, "players": [232, 12, 2423, 99]}, {"type": 1, "winner": 2423}]}';

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
      expect(serializable.events, isNotEmpty);
      expect(serializable.events.length, 2);
      expect(serializable.events[0], isA<StartEvent>());
      expect(serializable.events[0].type, EventType.start);
      expect(
          (serializable.events[0] as StartEvent).players, [232, 12, 2423, 99]);

      expect(serializable.events[1], isA<EndEvent>());
      expect(serializable.events[1].type, EventType.end);
      expect((serializable.events[1] as EndEvent).winner, 2423);
    });
  });
}

enum MySerializableEnum { value1, value2, value3 }

enum EventType { start, end }

class Event extends SerializableObject {
  EventType get type => attributes['type'];
  set type(EventType value) => attributes['type'] = value;

  Event(EventType type) {
    this.type = type;
    transformers['type'] =
        (value) => value is EventType ? value.index : EventType.values[value];
  }
}

class StartEvent extends Event {
  StartEvent() : super(EventType.start) {
    listCreators['players'] = () => <int>[];
  }

  List<int> get players => attributes['players'];
  set players(List<int> value) => attributes['players'] = value;
}

class EndEvent extends Event {
  EndEvent() : super(EventType.end);

  int get winner => attributes['winner'];
  set winner(int value) => attributes['winner'] = value;
}

class MySerializable extends SerializableObject {
  MySerializable() {
    listCreators['my-list'] = () => <String>[];
    listCreators['events'] = () => <Event>[];
    objectCreators['my-serializable'] = (map) => MySerializable();
    objectCreators['events'] =
        (map) => map['type'] == 0 ? StartEvent() : EndEvent();
    transformers['my-enum'] = (value) => value is MySerializableEnum
        ? value.index
        : MySerializableEnum.values[value];
  }

  List<Event> get events => attributes['events'];
  set events(List<Event> value) => attributes['events'] = value;

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
