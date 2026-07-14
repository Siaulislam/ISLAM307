import 'tafsir_http_transport_base.dart';
import 'tafsir_http_transport_stub.dart'
    if (dart.library.io) 'tafsir_http_transport_io.dart'
    if (dart.library.html) 'tafsir_http_transport_web.dart' as platform;

TafsirHttpTransport createTafsirHttpTransport() =>
    platform.createPlatformTafsirHttpTransport();
