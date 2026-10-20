/// The role the page gave view [viewId] when it added it; only a web page
/// adds views, so there is none here.
String? pageRoleOf(int viewId) => null;

/// The theme the page has picked for the phones; only a web page picks one.
String? pageTheme() => null;

/// Calls [listener] whenever the page picks another theme; there is no
/// page here to pick one.
void onPageTheme(void Function(String theme) listener) {}
