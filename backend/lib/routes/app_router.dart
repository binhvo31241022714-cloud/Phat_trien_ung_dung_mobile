import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../controllers/user_controller.dart';
import '../core/api_response.dart';
import '../repositories/user_repository.dart';
import '../services/user_service.dart';

/// Khai báo toàn bộ route của API. Thêm module mới thì mount ở đây.
class AppRouter {
  final Router _router = Router();

  AppRouter() {
    final userController = UserController(UserService(UserRepository()));

    _router.get('/api/health', (Request _) => ApiResponse.ok({'status': 'up'}));
    _router.mount('/api/users', userController.router.call);
    _router.all('/<ignored|.*>',
        (Request _) => ApiResponse.error(404, 'Không tìm thấy endpoint'));
  }

  Handler get handler => _router.call;
}
