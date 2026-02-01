import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/helpers/api_handler.dart';
import '../models/category_model.dart';

class CategoryService {
  Future<List<CategoryModel>> getCategories() async => ApiHandler.fetchList(
        request: http.get(Uri.parse(ApiConstants.categories)),
        fromJson: CategoryModel.fromJson, // Chỉ cần nói dùng hàm nào
        activityName: "Tải danh sách danh mục",
      );
}
