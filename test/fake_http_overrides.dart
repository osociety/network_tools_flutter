import 'package:fake_http_client/fake_http_client.dart';
import 'package:universal_io/io.dart';

class FakeResponseHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FakeHttpClient((request, client) {
      // The default response is an empty 200.
      return FakeHttpResponse(
          body:
              '00:00:0C,"Cisco Systems, Inc",false,MA-L,2015/11/17\r\n00:00:0D,FIBRONICS LTD.,false,MA-L,2015/11/17',
          statusCode: 200);
    });
  }
}
