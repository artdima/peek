import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

/// The role the page gave view [viewId] when it added it:
/// `app.addView({hostElement, initialData: {role: 'peek'}})`.
String? pageRoleOf(int viewId) => switch (ui_web.views
    .getInitialData(viewId)
    .dartify()) {
  {'role': final String role} => role,
  _ => null,
};
