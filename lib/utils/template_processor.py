import sys
import json
import re

def main():
    print(f"Arguments: {sys.argv}")
    if len(sys.argv) != 4:
        print(json.dumps({
            "success": False,
            "message": f"Expected 3 arguments, got {len(sys.argv) - 1}. Usage: {sys.argv[0]} <template_path> <output_path> <replacements_json>"
        }))
        sys.exit(1)

    template_path = sys.argv[1]
    output_path = sys.argv[2]
    replacements_json = sys.argv[3]

    try:
        replacements = json.loads(replacements_json)
        with open(template_path, 'r') as f:
            content = f.read()
        for key, value in replacements.items():
            content = content.replace(f"{{{{{key}}}}}", value)
        with open(output_path, 'w') as f:
            f.write(content)
        print(json.dumps({"success": True, "message": "Template processed successfully"}))
    except Exception as e:
        print(json.dumps({"success": False, "message": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()