// Native-browser JPEG downscale for web, where [compute] has no background
// isolate and the pure-Dart decode/resize/encode in [ImageProcessor] runs
// on the UI thread — freezing the page for seconds on a large photo.
// On other platforms [resizeJpegInBrowser] always returns null.
export 'browser_resize_stub.dart' if (dart.library.js_interop) 'browser_resize_web.dart';
