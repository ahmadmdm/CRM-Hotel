class OneSignalBridge {
  const OneSignalBridge();

  bool get isSupported => false;

  Future<void> initialize({
    required String appId,
    required String serviceWorkerPath,
    required String serviceWorkerScope,
  }) async {}

  Future<void> login(String externalId) async {}

  Future<void> logout() async {}

  Future<bool> promptForPush() async => false;
}

const oneSignalBridge = OneSignalBridge();