@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:aad_oauth/model/failure.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run with both web compilers:
///   flutter test --platform chrome test/web_oauth_test.dart
///   flutter test --platform chrome --wasm test/web_oauth_test.dart
void main() {
  late _FakeMsalBridge bridge;

  setUp(() {
    bridge = _FakeMsalBridge()..install();
  });

  AadOAuth createOAuth() => AadOAuth(
        Config(
          tenant: 'tenant-id',
          clientId: 'client-id',
          scope: 'openid profile email',
          redirectUri: 'https://app.example/login/',
          prompt: 'select_account',
          state: 'custom-state',
          webUseRedirect: true,
          navigatorKey: GlobalKey<NavigatorState>(),
        ),
      );

  test('initializes msalv2.js with the configuration', () {
    createOAuth();

    final config = bridge.config!;
    expect(config.getProperty<JSString>('tenant'.toJS).toDart, 'tenant-id');
    expect(config.getProperty<JSString>('clientId'.toJS).toDart, 'client-id');
    expect(
      config.getProperty<JSString>('redirectUri'.toJS).toDart,
      'https://app.example/login/',
    );
    expect(config.getProperty<JSString>('state'.toJS).toDart, 'custom-state');
    expect(config.getProperty<JSString>('customParameters'.toJS).toDart, '{}');
    expect(
      config.getProperty<JSString>('cacheLocation'.toJS).toDart,
      'localStorage',
    );
  });

  test('logs in and reads the tokens', () async {
    final oauth = createOAuth();

    final result = await oauth.login();

    expect(result.isRight(), isTrue);
    expect(bridge.loginUsedRedirect, isTrue);
    expect(await oauth.getIdToken(), 'id-token');
    expect(await oauth.getAccessToken(), 'access-token');
    expect(await oauth.hasCachedAccountInformation, isTrue);
  });

  test('returns a failure when msalv2.js reports an error', () async {
    bridge.loginError = 'user_cancelled';

    final result = await createOAuth().login();

    result.fold(
      (failure) {
        expect(failure, isA<AadOauthFailure>());
        expect(failure.message, contains('user_cancelled'));
      },
      (_) => fail('expected a failure'),
    );
  });

  test('logs out', () async {
    await createOAuth().logout(showWebPopup: false);

    expect(bridge.logoutShowedPopup, isFalse);
  });
}

/// Stands in for the `aadOauth` global that `assets/msalv2.js` defines.
class _FakeMsalBridge {
  JSObject? config;
  bool? loginUsedRedirect;
  bool? logoutShowedPopup;
  String? loginError;

  void install() {
    final aadOauth = JSObject()
      ..setProperty(
        'init'.toJS,
        ((JSObject received) {
          config = received;
        }).toJS,
      )
      ..setProperty(
        'login'.toJS,
        ((
          JSBoolean refreshIfAvailable,
          JSBoolean useRedirect,
          JSFunction onSuccess,
          JSFunction onError,
        ) {
          loginUsedRedirect = useRedirect.toDart;
          final error = loginError;
          if (error == null) {
            onSuccess.callAsFunction(null, 'access-token'.toJS);
          } else {
            onError.callAsFunction(null, error.toJS);
          }
        }).toJS,
      )
      ..setProperty(
        'getIdToken'.toJS,
        (() => Future<JSAny?>.value('id-token'.toJS).toJS).toJS,
      )
      ..setProperty(
        'getAccessToken'.toJS,
        (() => Future<JSAny?>.value('access-token'.toJS).toJS).toJS,
      )
      ..setProperty(
        'hasCachedAccountInformation'.toJS,
        (() => true.toJS).toJS,
      )
      ..setProperty(
        'logout'.toJS,
        ((JSFunction onSuccess, JSFunction onError, JSBoolean showPopup) {
          logoutShowedPopup = showPopup.toDart;
          onSuccess.callAsFunction();
        }).toJS,
      );

    globalContext.setProperty('aadOauth'.toJS, aadOauth);
  }
}
