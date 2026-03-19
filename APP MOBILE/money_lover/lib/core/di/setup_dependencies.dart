import 'package:get_it/get_it.dart';
import '../../modules/category/services/category_service.dart';

final GetIt getIt = GetIt.instance;

void setupDependencies() {
  // Đăng ký CategoryService
  // Sử dụng registerLazySingleton để chỉ tạo instance khi nó được yêu cầu lần đầu
  getIt.registerLazySingleton<CategoryService>(() => CategoryService());

  // Đăng ký các Service khác của bạn tại đây
  // getIt.registerLazySingleton<WalletService>(() => WalletService());
  // getIt.registerLazySingleton<AuthService>(() => AuthService());
}
