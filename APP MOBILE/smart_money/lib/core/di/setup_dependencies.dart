import 'package:get_it/get_it.dart';
import '../services/auth_service.dart';
import '../../modules/category/services/category_service.dart';
import '../../modules/transaction/services/transaction_service.dart';
import '../../modules/transaction/services/util_service.dart';

// Tất cả Service của app đăng ký tại đây 1 lần khi khởi động.
// Sau đó bất kỳ chỗ nào cũng gọi: getIt.get<TênService>()
final GetIt getIt = GetIt.instance;

void setupDependencies() {

  // Auth — dùng AuthService từ core/services/ theo blueprint
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Category — gọi API CRUD danh mục
  getIt.registerLazySingleton<CategoryService>(() => CategoryService());

  // Transaction — gọi API CRUD giao dịch
  getIt.registerLazySingleton<TransactionService>(() => TransactionService());

  // Util — gọi API utils (date-ranges, wallets, saving goals, total balance)
  getIt.registerLazySingleton<UtilService>(() => UtilService());

  // Wallet
  // getIt.registerLazySingleton<WalletService>(() => WalletService());

  // Budget
  // getIt.registerLazySingleton<BudgetService>(() => BudgetService());

  // Saving Goal
  // getIt.registerLazySingleton<SavingGoalService>(() => SavingGoalService());

  // Debt
  // getIt.registerLazySingleton<DebtService>(() => DebtService());

  // Event
  // getIt.registerLazySingleton<EventService>(() => EventService());
}
