import os

base_dir = "/Users/mac03/.gemini/antigravity/scratch/EditOrLynx"

replacements = [
    ("Edit.or.lynk", "Edit.or.lynx"),
    ("edit.or.lynk", "edit.or.lynx"),
    ("com.editorlynk.app", "com.editor.lynx"),
    ("com.editorlynk", "com.editor.lynx"),
    ("Edit-or-lynk", "Edit-or-lynx"),
]

for root, dirs, files in os.walk(base_dir):
    for f in files:
        if f.endswith((".swift", ".json", ".js", ".html", ".css", ".md", ".sh", ".plist")):
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
            modified = False
            for old, new in replacements:
                if old in content:
                    content = content.replace(old, new)
                    modified = True
            if modified:
                with open(path, "w", encoding="utf-8") as file:
                    file.write(content)
                print(f"Updated: {path}")

print("Replacement complete.")
