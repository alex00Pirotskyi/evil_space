import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/public_desk_models.dart';

class PublicDeskApi {
  Future<SiteStatus?> status() async => null;

  Future<void> book(DeskBookingProfile profile) async {
    throw const PublicDeskException(
      'Desk booking is available from the deployed web app.',
    );
  }

  DeskBookingProfile? savedProfile() => null;

  void saveProfile(DeskBookingProfile profile) {}

  void clearSavedProfile() {}
}
