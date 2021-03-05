# RequestAPI

A wrapper of Dart http package.

## Getting started

```dart
import 'package:request_api/request_api.dart';

class ExampleApi {
  static void init() {
    // RequestAPI.init(authority, bearerToken);
    RequestAPI.init('example.com', 'Bearer Example');
  }

  static Future<Model> getModel(
    String arg, {
    http.Client client,
  }) async {
    var data = await Request.get('api/model/$arg', client: client);
    var parser = () => parseItem<Model>(
          data.body,
          Model.fromJson,
        );
    var result = await tryParse(parser);
    return result;
  }
}
```
