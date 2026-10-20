{{flutter_js}}
{{flutter_build_config}}

// One program, two views: an app on one phone and Peek on the other, so a
// call made in the first shows up in the second. Each view is told what to
// show; `web_demo.dart` reads it back.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const engine = await engineInitializer.initializeEngine({
        multiViewEnabled: true,
      });
      const app = await engine.runApp();
      const views = new Map();
      // A view learns what to show only when it is added, so showing
      // something else means replacing it.
      const show = (host) => {
        if (views.has(host)) app.removeView(views.get(host));
        views.set(
          host,
          app.addView({
            hostElement: host,
            initialData: { role: host.dataset.peekView },
          }),
        );
      };
      document.querySelectorAll('[data-peek-view]').forEach(show);
      document.addEventListener('peekdemo:switch', (event) =>
        show(event.detail.host),
      );
    } catch (error) {
      document.documentElement.classList.add('is-failed');
      throw error;
    }
  },
});
