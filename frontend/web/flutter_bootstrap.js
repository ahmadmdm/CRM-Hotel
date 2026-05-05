{{flutter_js}}
{{flutter_build_config}}

(() => {
  const currentScript = document.currentScript;
  const buildId = currentScript
      ? new URL(currentScript.src, window.location.href).searchParams.get('v') ?? ''
      : '';

  if (buildId && window._flutter?.buildConfig?.builds) {
    for (const build of window._flutter.buildConfig.builds) {
      if (!build.mainJsPath) {
        continue;
      }
      const separator = build.mainJsPath.includes('?') ? '&' : '?';
      build.mainJsPath = `${build.mainJsPath}${separator}v=${encodeURIComponent(buildId)}`;
    }
  }

  const serviceWorkerVersion = {{flutter_service_worker_version}};

  window._flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion,
    },
  });
})();