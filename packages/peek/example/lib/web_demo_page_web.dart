import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

/// The role the page gave view [viewId] when it added it:
/// `app.addView({hostElement, initialData: {role: 'peek'}})`.
String? pageRoleOf(int viewId) => switch (ui_web.views
    .getInitialData(viewId)
    .dartify()) {
  {'role': final String role} => role,
  _ => null,
};

/// The theme the page has picked for the phones, `light` or `dark`, from
/// `window.peekDemoTheme`.
String? pageTheme() =>
    globalContext.getProperty<JSString?>('peekDemoTheme'.toJS)?.toDart;

/// Calls [listener] whenever the page picks another theme: the page calls
/// `window.peekDemoOnTheme(theme)`.
void onPageTheme(void Function(String theme) listener) =>
    globalContext.setProperty(
      'peekDemoOnTheme'.toJS,
      ((JSString theme) => listener(theme.toDart)).toJS,
    );
