
Serialize to and deserialize from JSON in runtime. 
This pure Dart library does not depend on build time generation.

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_serialization: ^1.0.1
```
The latest version or `enough_serialization` is [![enough_serialization version](https://img.shields.io/pub/v/enough_serialization.svg)](https://pub.dartlang.org/packages/enough_serialization).


## Usage

The easiest way is 
 * extend `SerializableObject`
 * define a `get` and `set` field for each supported attribute and retrieve value from / store values to the `attributes` map.
 * if you have non-generic `List`s field, define a function that creates such a new list for the corresponding attribute name in the `listCreators` field.
 * if you have nested objects, define a function that creates new object instances for the corresponding attribute name in the `objectCreators` field.
 * if you want to store other values such as an `enum`, register a transformation function in the `transformer` field.

### Simple Example
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

### Enum Example
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

### Lists and Nested Objects
If you have a non-generic list, you define a corresponding function in the `listCreators` field:
```dart
listCreators['articles'] = () => <Article>[];
```
When you have nested objects, register a creation function in the `objectCreators` field. This function 
receives a `Map<String,dynamic>` parameter with the values of the nested child object. If needed, you can evaluate 
these values to determine which kind of object you need to create:
```dart
// simple:
objectCreators['band'] = (map) => Band();
// complex:
objectCreators['articles'] = (map) {
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
    listCreators['articles'] = () => <Article>[];
    objectCreators['articles'] = (map) {
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

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Enough-Software/enough_serialization/issues

## License

Licensed under the [MIT License](LICENSE).