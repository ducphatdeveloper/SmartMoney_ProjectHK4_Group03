import 'package:get_it/get_it.dart';
import '../services/auth_service.dart';

// Tất cả Service của app đăng ký tại đây 1 lần khi khởi động.
// Sau đó bất kỳ chỗ nào cũng gọi: getIt.get<TênService>()
final GetIt getIt = GetIt.instance;

void setupDependencies() {

  // Auth — dùng AuthService từ core/services/ theo blueprint
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Wallet
  // getIt.registerLazySingleton<WalletService>(() => WalletService());

  // Transaction
  // getIt.registerLazySingleton<TransactionService>(() => TransactionService());

  // Category
  // getIt.registerLazySingleton<CategoryService>(() => CategoryService());

  // Budget
  // getIt.registerLazySingleton<BudgetService>(() => BudgetService());

  // Saving Goal
  // getIt.registerLazySingleton<SavingGoalService>(() => SavingGoalService());

  // Debt
  // getIt.registerLazySingleton<DebtService>(() => DebtService());

  // Event
  // getIt.registerLazySingleton<EventService>(() => EventService());
}
