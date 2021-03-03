import 'dart:convert';

import 'package:enough_serialization/src/serializable.dart';
import 'package:test/test.dart';

void main() {
  group('On Demand Serilization Tests', () {
    late MySerializable mySerializable;

    setUp(() {
      final props = {'firstname': 'firstValue', 'second': 'another value'};
      final newsByYear = {
        2020: 'enough serialization started',
        2021: 'the future is there'
      };
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
        ]
        ..properties = props
        ..newsByYear = newsByYear;
    });

    test('Serialize on demand', () {
      final json = mySerializable.serialize();
      print(json);
      expect(json, isNotNull);
      final decoded = JsonCodec().decode(json);
      expect(decoded, isNotNull);
      print(decoded);
    });

    test('Deserialize on demand', () {
      final jsonText =
          r'{"my-number": 13, "my-enum": 2, "my-text": "Hello \"World\"", "my-list": ["one", "two", "three"], "my-serializable": {"my-text": "hi this is the child element", "my-number": 23, "my-serializable": null}, "events": [{"type": 0, "players": [232, 12, 2423, 99]}, {"type": 1, "winner": 2423}], "properties": {"firstname": "firstValue", "second": "another value"}, "news-by-year": {"2020": "enough serialization started", "2021": "the future is there"}}';

      final serializable = MySerializable.deserialize(jsonText);
      expect(serializable.myNumber, 13);
      expect(serializable.myEnum, MySerializableEnum.value3);
      expect(serializable.myText, 'Hello "World"');
      expect(serializable.myList, isNotEmpty);
      expect(serializable.myList!.length, 3);
      expect(serializable.myList, ['one', 'two', 'three']);
      expect(serializable.myChild, isNotNull);
      expect(serializable.myChild!.myText, 'hi this is the child element');
      expect(serializable.myChild!.myNumber, 23);
      expect(serializable.events, isNotEmpty);
      expect(serializable.events!.length, 2);
      expect(serializable.events![0], isA<StartEvent>());
      expect(serializable.events![0].type, EventType.start);
      expect(
          (serializable.events![0] as StartEvent).players, [232, 12, 2423, 99]);

      expect(serializable.events![1], isA<EndEvent>());
      expect(serializable.events![1].type, EventType.end);
      expect((serializable.events![1] as EndEvent).winner, 2423);
      expect(serializable.properties, isNotNull);
      expect(serializable.properties!['firstname'], 'firstValue');
      expect(serializable.properties!['second'], 'another value');
      expect(serializable.newsByYear![2020], 'enough serialization started');
      expect(serializable.newsByYear![2021], 'the future is there');
    });
  });
}

enum MySerializableEnum { value1, value2, value3 }

enum EventType { start, end }

class Event implements OnDemandSerializable {
  EventType? type;

  Event(this.type);

  @override
  void read(Map<String, dynamic> attributes) {
    type = attributes['type'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['type'] = type;
  }
}

class StartEvent extends Event {
  StartEvent() : super(EventType.start);

  List<int>? players;

  @override
  void read(Map<String, dynamic> attributes) {
    super.read(attributes);
    players = attributes['players'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    super.write(attributes);
    attributes['players'] = players;
  }
}

class EndEvent extends Event {
  EndEvent() : super(EventType.end);

  int? winner;

  @override
  void read(Map<String, dynamic> attributes) {
    super.read(attributes);
    winner = attributes['winner'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    super.write(attributes);
    attributes['winner'] = winner;
  }
}

class MySerializable implements OnDemandSerializable {
  List<Event>? events;
  MySerializableEnum? myEnum;
  int? myNumber;
  String? myText;
  List<String>? myList;
  MySerializable? myChild;
  Map<String, String>? properties;
  Map<int, String>? newsByYear;

  String serialize() {
    final serializer = Serializer();
    return serializer.serializeOnDemand(
      this,
      transformers: {
        'news-by-year.key': (value) =>
            value is int ? value.toString() : int.parse(value),
        'my-enum': (value) => value is MySerializableEnum
            ? value.index
            : MySerializableEnum.values[value],
        // for event classes:
        'type': (value) =>
            value is EventType ? value.index : EventType.values[value],
      },
    );
  }

  static MySerializable deserialize(String jsonText) {
    final serializer = Serializer();
    final target = MySerializable();
    serializer.deserializeOnDemand(
      jsonText,
      target,
      transformers: {
        'news-by-year.key': (value) =>
            value is int ? value.toString() : int.parse(value),
        'my-enum': (value) => value is MySerializableEnum
            ? value.index
            : MySerializableEnum.values[value],
        // for event classes:
        'type': (value) =>
            value is EventType ? value.index : EventType.values[value],
      },
      objectCreators: {
        'my-list': (map) => <String>[],
        'events': (map) => <Event>[],
        'my-serializable': (map) => MySerializable(),
        'events.value': (map) => map!['type'] == 0 ? StartEvent() : EndEvent(),
        'properties': (map) => <String, String>{},
        'news-by-year': (map) => <int, String>{},
        // for StartEvent instances:
        'players': (map) => <int>[],
      },
    );
    return target;
  }

  @override
  void read(Map<String, dynamic> attributes) {
    events = attributes['events'];
    myEnum = attributes['my-enum'];
    myNumber = attributes['my-number'];
    myText = attributes['my-text'];
    myList = attributes['my-list'];
    myChild = attributes['my-serializable'];
    properties = attributes['properties'];
    newsByYear = attributes['news-by-year'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['events'] = events;
    attributes['my-enum'] = myEnum;
    attributes['my-number'] = myNumber;
    attributes['my-text'] = myText;
    attributes['my-list'] = myList;
    attributes['my-serializable'] = myChild;
    attributes['properties'] = properties;
    attributes['news-by-year'] = newsByYear;
  }
}
