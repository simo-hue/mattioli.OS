import re

with open('desktop/lib/core/desktop_private_db.dart', 'r') as f:
    content = f.read()

if "import 'dart:convert';" not in content:
    content = "import 'dart:convert';\n" + content
    with open('desktop/lib/core/desktop_private_db.dart', 'w') as f:
        f.write(content)
