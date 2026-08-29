import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/public_desk_models.dart';

class PublicDeskApi {
  Future<SiteStatus?> status() async => null;

  Future<DeskBookingState> book(DeskBookingProfile profile) async {
    throw const PublicDeskException(
      'Desk booking is available from the deployed web app.',
    );
  }

  Future<DeskBookingState?> bookingStatus(DeskBookingState booking) async =>
      booking;

  Future<void> deleteBooking(DeskBookingState booking) async {
    throw const PublicDeskException(
      'Desk booking is available from the deployed web app.',
    );
  }

  DeskBookingProfile? savedProfile() => null;

  void saveProfile(DeskBookingProfile profile) {}

  void clearSavedProfile() {}

  DeskBookingState? savedBooking() => null;

  void saveBooking(DeskBookingState booking) {}

  void clearSavedBooking() {}
}
