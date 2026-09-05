import 'package:flutter_test/flutter_test.dart';
import 'package:nekofit/services/weekly_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeeklyPlanService.clearCache', () {
    test('invalida solo los planes semanales de ese usuario', () async {
      SharedPreferences.setMockInitialValues({
        'weekly_plan_user1_2026-08-31': '{}',
        'weekly_plan_user1_2026-09-07': '{}',
        'weekly_plan_user2_2026-09-07': '{}',
        'shopping_list_user1': '{}',
      });

      await WeeklyPlanService.instance.clearCache('user1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('weekly_plan_user1_2026-08-31'), false);
      expect(prefs.containsKey('weekly_plan_user1_2026-09-07'), false);
      expect(prefs.containsKey('weekly_plan_user2_2026-09-07'), true);
      expect(prefs.containsKey('shopping_list_user1'), true);
    });
  });
}