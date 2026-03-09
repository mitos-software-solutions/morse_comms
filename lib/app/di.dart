import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

// After adding @injectable annotations, run:
//   dart run build_runner build --delete-conflicting-outputs
// This generates di.config.dart which is imported below.
import 'di.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async => getIt.init();
