import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/categories/domain/default_categories.dart';

/// Seeds the default categories (no-op if categories already exist).
Future<void> seedCategories(
  SyncWriter writer,
  AppDatabase db,
  DefaultCategorySet set,
) => seedDefaultCategories(writer, db, set);
