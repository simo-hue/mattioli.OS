import os
import sys

def replace_in_files(directory, old_str, new_str):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".txt"):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                if old_str in content:
                    new_content = content.replace(old_str, new_str)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {filepath}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python replace_branding.py <directory>")
        sys.exit(1)
    
    target_dir = sys.argv[1]
    replace_in_files(target_dir, "Mattioli.OS", "Evolve")
    print("Done!")
