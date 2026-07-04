import re

with open('desktop/lib/core/desktop_backup_import_service.dart', 'r') as f:
    content = f.read()

# Change imports
content = content.replace("import 'private_data_store.dart';", "import 'desktop_private_db.dart';")

# Change class name
content = content.replace("class BackupImportService", "class DesktopBackupImportService")

# Change constructor and variables
content = content.replace("final PrivateDataStore _privateStore;", "final DesktopPrivateDb _privateStore;")
content = content.replace("BackupImportService(this._privateStore, this._supabase);", "DesktopBackupImportService(this._privateStore, this._supabase);")

with open('desktop/lib/core/desktop_backup_import_service.dart', 'w') as f:
    f.write(content)
