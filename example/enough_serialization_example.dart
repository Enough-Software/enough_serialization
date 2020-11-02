import 'package:enough_serialization/enough_serialization.dart';

void main() {
  simpleExample();
  print('');
  enumExample();
  print('');
  complexExample();
}

class SimpleArticle extends SerializableObject {
  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  int get price => attributes['price'];
  set price(int value) => attributes['price'] = value;

  double get popularity => attributes['popularity'];
  set popularity(double value) => attributes['popularity'] = value;
}

void simpleExample() {
  print('simple example');
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

void enumExample() {
  print('emum example');
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

void complexExample() {
  print('complex example');
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
