{{flutter_js}}
{{flutter_build_config}}

// One program, two views: the example on one phone and Peek on the other,
// so a call made in the first shows up in the second. Each view is told
// which phone it is; `web_demo.dart` reads it back.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const engine = await engineInitializer.initializeEngine({
        multiViewEnabled: true,
      });
      const app = await engine.runApp();
      for (const host of document.querySelectorAll('[data-peek-view]')) {
        app.addView({
          hostElement: host,
          initialData: { role: host.dataset.peekView },
        });
      }
    } catch (error) {
      document.documentElement.classList.add('is-failed');
      throw error;
    }
  },
});
