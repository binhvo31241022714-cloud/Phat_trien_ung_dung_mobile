import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';

/// Content provider with no backend content, used by screens whose tests
/// exercise local/demo UI rather than the content handover flow.
class EmptyContentProvider extends ContentProvider {
  @override
  void bindUser(UserProvider users, CatalogProvider catalog) {}
}

EmptyContentProvider emptyContentProvider() {
  final provider = EmptyContentProvider();
  provider.signedIn = false;
  return provider;
}
