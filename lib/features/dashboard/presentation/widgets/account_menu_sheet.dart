import 'package:flutter/material.dart';
import 'account_drawer.dart';

/// Legacy alias for AccountDrawer to preserve backward compatibility.
class AccountMenuSheet {
  static void show(BuildContext context) {
    AccountDrawer.show(context);
  }
}
