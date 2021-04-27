
Serialize to and deserialize from JSON in runtime. 
This pure Dart library does not depend on build time code generation.

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_serialization: ^1.4.0
```
The latest version or `enough_serialization` is [![enough_serialization version](https://img.shields.io/pub/v/enough_serialization.svg)](https://pub.dartlang.org/packages/enough_serialization).


## Usage

You can choose between two serialization modes:

1. Extend `SerializableObject` or implement `Serializable` for full control and complex cases. You have to store your field values in a dynamic map, however.
2. Implement `OnDemandSerializable` to only write and read your field values to/from a dynamic map when needed. This comes with limitations when having deep nested structures - in that case any serialization names of complex fields must be unique.  

### Serialization with `Serializable` and `SerializableObject`

The easiest way is 
 * extend `SerializableObject`
 * define a `get` and `set` field for each supported attribute and retrieve value from / store values to the `attributes` map.
 * if you have nested objects such as lists, maps or other serializable objects, define a function that creates new object instances for the corresponding attribute name in the `objectCreators` field.
 * if you want to store other values such as an `enum`, register a transformation function in the `transformer` field. This can also be done for map keys and for map/list values.

#### Simple Example
When you have only basic fields such as `String`, `int`, `double`, `bool` the usage is straight forward:

```dart
import 'package:enough_serialization/enough_serialization.dart';

class SimpleArticle extends SerializableObject {
  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  int get price => attributes['price'];
  set price(int value) => attributes['price'] = value;

  double get popularity => attributes['popularity'];
  set popularity(double value) => attributes['popularity'] = value;
}

void main() {
  final article = SimpleArticle()
    ..name = 'Remote Control'
    ..price = 2499
    ..popularity = 0.1;
  final serializer = Serializer();
  final json = serializer.serialize(article);
  print('serialized article: $json');

  final inputJson =
      '{"name": "Remote Control", "price": 2499, "popularity": 0.1}';
  final deserializedArticle = SimpleArticle();
  serializer.deserialize(inputJson, deserializedArticle);
  print('name: ${deserializedArticle.name}');
  print('price: ${deserializedArticle.price}');
  print('popularity: ${deserializedArticle.popularity}');
}
```

#### Enum Example
Enumerations cannot be serialized or deserialized automatically. To support `enum` fields, register a `transformer` function:
```dart
transformers['area'] = (value) =>
        value is ArticleArea ? value.index : ArticleArea.values[value];
```
Here's a complete example:

```dart
enum ArticleArea { electronics, music }

class ArticleWithEnum extends SerializableObject {
  ArticleWithEnum() {
    transformers['area'] = (value) =>
        value is ArticleArea ? value.index : ArticleArea.values[value];
  }

  ArticleArea get area => attributes['area'];
  set area(ArticleArea value) => attributes['area'] = value;

  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;
}

void main() {
  final article = ArticleWithEnum()
    ..area = ArticleArea.electronics
    ..name = 'Remote Control';
  final serializer = Serializer();
  final json = serializer.serialize(article);
  print('serialized article: $json');

  final inputJson = '{"area": 0, "name": "Remote Control"}';
  final deserializedArticle = ArticleWithEnum();
  serializer.deserialize(inputJson, deserializedArticle);
  print('area: ${deserializedArticle.area}');
  print('name: ${deserializedArticle.name}');
}
```

#### Lists and Nested Serializable Objects
When you have nested objects, register a creation function in the `objectCreators` field. For nested maps and objects this function 
receives a `Map<String,dynamic>` parameter with the values of the nested child object. If needed, you can evaluate 
these values to determine which kind of object you need to create:

```dart
// create a list:
objectCreators['articles'] = (map) => <Article>[];
// create a nested simple object:
objectCreators['band'] = (map) => Band();
// created a nested complex field in a list:
objectCreators['articles.value'] = (map) {
      final int areaIndex = map['area'];
      final area = ArticleArea.values[areaIndex];
      switch (area) {
        case ArticleArea.electronics:
          return ElectronicsArticle();
        case ArticleArea.music:
          return MusicArticle();
      }
      return Article();
    };
```

Here's a complete example with nested objects and complex list elements:
```dart
enum ArticleArea { electronics, music }

class Article extends SerializableObject {
  Article() {
    transformers['area'] = (value) =>
        value is ArticleArea ? value.index : ArticleArea.values[value];
  }

  ArticleArea get area => attributes['area'];
  set area(ArticleArea value) => attributes['area'] = value;

  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  int get price => attributes['price'];
  set price(int value) => attributes['price'] = value;
}

class ElectronicsArticle extends Article {
  ElectronicsArticle() {
    area = ArticleArea.electronics;
  }

  String get recommendation => attributes['recommendation'];
  set recommendation(String value) => attributes['recommendation'] = value;
}

class MusicArticle extends Article {
  MusicArticle() {
    area = ArticleArea.music;
    objectCreators['band'] = (map) => Band();
  }

  Band get band => attributes['band'];
  set band(Band value) => attributes['band'] = value;
}

class Band extends SerializableObject {
  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  int get year => attributes['year'];
  set year(int value) => attributes['year'] = value;

  Band({String name, int year}) {
    this.name = name;
    this.year = year;
  }
}

class Order extends SerializableObject {
  Order() {
    objectCreators['articles'] = (map) => <Article>[];
    objectCreators['articles.value'] = (map) {
      final int areaIndex = map['area'];
      final area = ArticleArea.values[areaIndex];
      switch (area) {
        case ArticleArea.electronics:
          return ElectronicsArticle();
        case ArticleArea.music:
          return MusicArticle();
      }
      return Article();
    };
  }

  List<Article> get articles => attributes['articles'];
  set articles(List<Article> value) => attributes['articles'] = value;
}

void main() {
  final order = Order()
    ..articles = [
      ElectronicsArticle()
        ..name = 'CD Player'
        ..price = 3799
        ..recommendation = 'Consider our streaming option, too!',
      ElectronicsArticle()
        ..name = 'MC Tape Deck'
        ..price = 12399
        ..recommendation = 'Old school, like it!',
      MusicArticle()
        ..name = 'The white album'
        ..price = 1899
        ..band = Band(name: 'Beatles', year: 1962)
    ];
  final serializer = Serializer();
  final json = serializer.serialize(order);
  print('order: $json');

  final inputJson =
      '{"articles": [{"area": 0, "name": "CD Player", "price": 3799, "recommendation": "Consider our streaming option, too!"}, '
      '{"area": 0, "name": "MC Tape Deck", "price": 12399, "recommendation": "Old school, like it!"}, '
      '{"area": 1, "name": "The white album", "price": 1899, "band": {"name": "Beatles", "year": 1962}}]}';
  final deserializedOrder = Order();
  serializer.deserialize(inputJson, deserializedOrder);
  for (var i = 0; i < deserializedOrder.articles.length; i++) {
    final article = deserializedOrder.articles[i];
    print('$i: area: ${article.area}');
    print('$i: name: ${article.name}');
    print('$i: price: ${article.price}');
    if (article is ElectronicsArticle) {
      print('$i: recommendation: ${article.recommendation}');
    } else if (article is MusicArticle) {
      print('$i: band-name: ${article.band.name}');
      print('$i: band-year: ${article.band.year}');
    }
  }
}
```

#### Nested Maps
When nesting maps, you also register your creator function in the `objectCreators`, e.g. 
```dart
objectCreators['news-by-year'] = (map) => <int, String>{};
```
When dealing with maps with non-String keys, you need to transform these to Strings and back to their original 
form when deserializing. As for `enum`s you do this by registering a `transformer` function that receives the value. 
You registers the function under the field name with a `.key` appended to it:
```dart
    transformers['news-by-year.key'] =
        (value) => value is int ? value.toString() : int.parse(value);
```

Same as for lists, you can also register objectCreators and transformers for map values by appending a `.value` to the field's serialization name. 

Here is a complete example for serializing an object with an embedded map:

```dart
class MappedArticle extends SerializableObject {
  MappedArticle() {
    objectCreators['news-by-year'] = (map) => <int, String>{};
    transformers['news-by-year.key'] =
        (value) => value is int ? value.toString() : int.parse(value);
  }

  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  Map<int, String> get newsByYear => attributes['news-by-year'];
  set newsByYear(Map<int, String> value) => attributes['news-by-year'] = value;
}

void main() {
  final newsByYear = {
    2020: 'Corona, Corona, Corona...',
    2021: 'The end of a pandemia',
    2022: 'Climate change getting really serious'
  };
  final article = MappedArticle()
    ..name = 'My Article'
    ..newsByYear = newsByYear;
  final serializer = Serializer();
  final json = serializer.serialize(article);
  print('article with map: $json');

  final inputJson =
      '{"name": "My Article", "news-by-year": {"2020": "Corona, Corona, Corona...", "2021": "The end of a pandemic", "2022": "Climate change getting really serious"}}';
  final deserializedArticle = MappedArticle();
  serializer.deserialize(inputJson, deserializedArticle);
  print('article: ${article.name}');
  for (final key in article.newsByYear.keys) {
    print('$key: ${article.newsByYear[key]}');
  }
}
```

### On Demand Serialization
Using a dynamic map for storing and retrieving fields requires you to create boiler-plate code and makes accessing fields slower.
When you want to use normal fields, you can implement `OnDemandSerializable` instead:
```dart
class Article implements OnDemandSerializable {
  int price;
  String name;
  

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['price'] = price;
    attributes['name'] = name;
  }

  @override
  void read(Map<String, dynamic> attributes) {
    price = attributes['price'];
    name = attributes['name'];
  }
```

Use `Serializer.serializeOnDemand(OnDemandSerializable)` to create the JSON and `Serializer.deserializeOnDemand(String,OnDemandSerializable)`
to deserialize your classes.

In these calls you can optionally provide `transformers` and `objectCreators` to handle more complex scenarios like `enum`s, other nested `OnDemandSerializable`, `List` or `Map` fields. The registration is the same as for `Serializable`, however you have can only register these special cases at that point. This means that field names of special cases must be unique throughout your object's hierarchy.

Here's a complete example of a complex structure with `OnDemandSerializable`:
```dart
class OnDemandArticle implements OnDemandSerializable {
  String name;
  Map<int, String> newsByYear;

  String serialize() {
    final serializer = Serializer();
    final json = serializer.serializeOnDemand(
      this,
      transformers: {
        'news-by-year.key': (value) =>
            value is int ? value.toString() : int.parse(value),
      },
    );
    return json;
  }

  void deserialize(String json) {
    final serializer = Serializer();
    serializer.deserializeOnDemand(
      json,
      this,
      transformers: {
        'news-by-year.key': (value) =>
            value is int ? value.toString() : int.parse(value),
      },
      objectCreators: {
        'news-by-year': (map) => <int, String>{},
      },
    );
  }

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['name'] = name;
    attributes['news-by-year'] = newsByYear;
  }

  @override
  void read(Map<String, dynamic> attributes) {
    name = attributes['name'];
    newsByYear = attributes['news-by-year'];
  }
}

void main() {
  final newsByYear = {
    2020: 'Corona, Corona, Corona...',
    2021: 'The end of a pandemia',
    2022: 'Climate change getting really serious'
  };
  final article = OnDemandArticle()
    ..name = 'My Article'
    ..newsByYear = newsByYear;
  final json = article.serialize();
  print('on demand article: $json');

  final inputJson =
      '{"name": "My Article", "news-by-year": {"2020": "Corona, Corona, Corona...", "2021": "The end of a pandemic", "2022": "Climate change getting really serious"}}';
  final deserializedArticle = OnDemandArticle();
  deserializedArticle.deserialize(inputJson);
  print('deserialized article: ${article.name}');
  for (final key in article.newsByYear.keys) {
    print('$key: ${article.newsByYear[key]}');
  }
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Enough-Software/enough_serialization/issues

## Null-Safety

enough_convert is null-safe from v1.3.0 onward.

## License

Licensed under the commercial friendly [MIT License](LICENSE).