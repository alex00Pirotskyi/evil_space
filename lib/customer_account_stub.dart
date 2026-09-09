import 'customer_account_models.dart';

class CustomerAccountApi {
  Future<CustomerAccountSnapshot> snapshot() {
    throw const CustomerAccountException('Customer accounts are available on web.');
  }

  Future<PhoneChallenge> startPhone(String name, String phone) {
    throw const CustomerAccountException('Phone registration is available on web.');
  }

  Future<CustomerAccountSnapshot> verifyPhone(
    String challenge,
    String code,
  ) {
    throw const CustomerAccountException('Phone registration is available on web.');
  }

  Future<TelegramSignup> startTelegram() {
    throw const CustomerAccountException('Telegram registration is available on web.');
  }

  Future<CustomerAccountSnapshot?> telegramStatus(String token) async => null;

  Future<void> beginGoogleSignIn(String clientId) {
    throw const CustomerAccountException('Google registration is available on web.');
  }

  Future<CustomerAccountSnapshot> signInGoogle(String idToken) {
    throw const CustomerAccountException('Google registration is available on web.');
  }

  Future<void> logout() async {}
}
