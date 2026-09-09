import 'package:flutter/foundation.dart';

final ValueNotifier<int> publicBookingRevision = ValueNotifier<int>(0);

void notifyPublicBookingChanged() {
  publicBookingRevision.value = publicBookingRevision.value + 1;
}
