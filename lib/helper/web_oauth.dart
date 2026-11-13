/// Microsoft identity platform authentication library.
/// @nodoc
library msauth;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:aad_oauth/helper/core_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:aad_oauth/model/failure.dart';
import 'package:aad_oauth/model/msalconfig.dart';
import 'package:aad_oauth/model/token.dart';
import 'package:dartz/dartz.dart';

@JS('aadOauth.init')
external void jsInit(MsalConfig config);

@JS('aadOauth.login')
external void jsLogin(
  JSBoolean refreshIfAvailable,
  JSBoolean useRedirect,
  JSFunction onSuccess,
  JSFunction onError,
);

@JS('aadOauth.logout')
external void jsLogout(
  JSFunction onSuccess,
  JSFunction onError,
  JSBoolean showPopup,
);

@JS('aadOauth.getAccessToken')
external JSPromise<JSString?> jsGetAccessToken();

@JS('aadOauth.getIdToken')
external JSPromise<JSString?> jsGetIdToken();

@JS('aadOauth.hasCachedAccountInformation')
external JSBoolean jsHasCachedAccountInformation();

@JS('aadOauth.refreshToken')
external void jsRefreshToken(
  JSFunction onSuccess,
  JSFunction onError,
);

@JS('String')
external JSString _describe(JSAny? value);

class WebOAuth extends CoreOAuth {
  final Config config;
  WebOAuth(this.config) {
    jsInit(MsalConfig.construct(
        tenant: config.tenant,
        policy: config.policy,
        clientId: config.clientId,
        responseType: config.responseType,
        redirectUri: config.redirectUri,
        scope: config.scope,
        responseMode: config.responseMode,
        state: config.state,
        prompt: config.prompt,
        codeChallenge: config.codeChallenge,
        codeChallengeMethod: config.codeChallengeMethod,
        nonce: config.nonce,
        tokenIdentifier: config.tokenIdentifier,
        clientSecret: config.clientSecret,
        resource: config.resource,
        isB2C: config.isB2C,
        customAuthorizationUrl: config.customAuthorizationUrl,
        customTokenUrl: config.customTokenUrl,
        loginHint: config.loginHint,
        domainHint: config.domainHint,
        codeVerifier: config.codeVerifier,
        authorizationUrl: config.authorizationUrl,
        tokenUrl: config.tokenUrl,
        cacheLocation: config.cacheLocation.value,
        customParameters: jsonEncode(config.customParameters),
        postLogoutRedirectUri: config.postLogoutRedirectUri));
  }

  @override
  Future<String?> getAccessToken() async {
    return (await jsGetAccessToken().toDart)?.toDart;
  }

  @override
  Future<String?> getIdToken() async {
    return (await jsGetIdToken().toDart)?.toDart;
  }

  @override
  Future<bool> get hasCachedAccountInformation =>
      Future<bool>.value(jsHasCachedAccountInformation().toDart);

  @override
  Future<Either<Failure, Token>> login(
      {bool refreshIfAvailable = false}) async {
    final completer = Completer<Either<Failure, Token>>();

    jsLogin(
      refreshIfAvailable.toJS,
      config.webUseRedirect.toJS,
      _onToken(completer).toJS,
      _onFailure(completer).toJS,
    );

    return completer.future;
  }

  @override
  Future<Either<Failure, Token>> refreshToken() {
    final completer = Completer<Either<Failure, Token>>();

    jsRefreshToken(
      _onToken(completer).toJS,
      _onFailure(completer).toJS,
    );

    return completer.future;
  }

  @override
  Future<void> logout({bool showPopup = true, bool clearCookies = true}) async {
    final completer = Completer<void>();

    jsLogout(
      (() {
        completer.complete();
      }).toJS,
      ((JSAny? error) {
        completer.completeError(_describe(error).toDart);
      }).toJS,
      showPopup.toJS,
    );

    return completer.future;
  }
}

void Function(JSString?) _onToken(
        Completer<Either<Failure, Token>> completer) =>
    (JSString? accessToken) =>
        completer.complete(Right(Token(accessToken: accessToken?.toDart)));

void Function(JSAny?) _onFailure(Completer<Either<Failure, Token>> completer) =>
    (JSAny? error) => completer.complete(Left(AadOauthFailure(
          errorType: ErrorType.accessDeniedOrAuthenticationCanceled,
          message:
              'Access denied or authentication canceled. Error: ${_describe(error).toDart}',
        )));

CoreOAuth getOAuthConfig(Config config) => WebOAuth(config);
