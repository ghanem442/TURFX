import re

# Read the file
with open('lib/features/auth/presentation/pages/register_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the old regex with the new one
old_pattern = r"r'\^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*(),.?\":{}|<>]).{8,} $',"
new_pattern = r"r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?\":{}|<>\-_=+]).{8,}$',"

content = content.replace(old_pattern, new_pattern)

# Write the file back
with open('lib/features/auth/presentation/pages/register_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Regex updated successfully!")
