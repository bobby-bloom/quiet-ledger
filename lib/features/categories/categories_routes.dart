import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/categories/presentation/categories_screen.dart';
import 'package:personal_finance/features/categories/presentation/custom_fields_screen.dart';
import 'package:personal_finance/features/categories/presentation/tags_screen.dart';

/// Routes of the categories feature (categories, tags, custom fields).
final categoriesRoutes = <RouteBase>[
  GoRoute(
    path: '/more/categories',
    builder: (context, state) => const CategoriesScreen(),
  ),
  GoRoute(path: '/more/tags', builder: (context, state) => const TagsScreen()),
  GoRoute(
    path: '/more/custom-fields',
    builder: (context, state) => const CustomFieldsScreen(),
  ),
];
