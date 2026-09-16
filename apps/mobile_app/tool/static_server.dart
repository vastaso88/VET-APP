// Minimal static file server for the built `build/web` output, with SPA
// fallback to index.html (needed since the app uses path-based URL
// strategy). Zero external packages on purpose — this only needs to run
// reliably in this sandbox, and both `flutter run -d web-server`'s dev
// compiler (too many modules to load reliably here) and `npx serve`
// (blocked by a TLS certificate issue fetching from npm) turned out not
// to be options.
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8080;
  final root = Directory('build/web');

  if (!await root.exists()) {
    stderr.writeln('build/web not found — run `flutter build web` first.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  // ignore: avoid_print
  print('Serving ${root.absolute.path} at http://127.0.0.1:$port');

  await for (final request in server) {
    try {
      final decodedPath = Uri.decodeComponent(request.uri.path);
      var file = File('${root.path}$decodedPath');
      if (decodedPath == '/' || !await file.exists()) {
        file = File('${root.path}/index.html');
      }

      final bytes = await file.readAsBytes();
      request.response
        ..statusCode = 200
        ..headers.contentType = _contentTypeFor(file.path)
        ..headers.set('cache-control', 'no-store')
        ..add(bytes);
    } catch (_) {
      request.response.statusCode = 404;
    }
    await request.response.close();
  }
}

ContentType _contentTypeFor(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js') || path.endsWith('.mjs')) {
    return ContentType('application', 'javascript');
  }
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.css')) return ContentType('text', 'css');
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
    return ContentType('image', 'jpeg');
  }
  if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
  if (path.endsWith('.otf')) return ContentType('font', 'otf');
  if (path.endsWith('.ttf')) return ContentType('font', 'ttf');
  if (path.endsWith('.woff')) return ContentType('font', 'woff');
  if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
  if (path.endsWith('.ico')) return ContentType('image', 'x-icon');
  return ContentType.binary;
}
