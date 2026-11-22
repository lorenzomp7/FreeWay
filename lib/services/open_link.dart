import 'open_link_stub.dart'
    if (dart.library.js_interop) 'open_link_web.dart'
    as impl;

/// Apre [url] in una nuova scheda del browser. Fuori dal web non fa nulla.
void openLink(String url) => impl.openLink(url);
