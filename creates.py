import os
import re
import json

def parse_asm_file(filepath):
    functions = {}
    current_function = None
    calls = []

    with open(filepath, 'r') as file:
        lines = file.readlines()

    for line in lines:
        # Match function definitions
        match_def = re.match(r'\s*\.type\s+(\w+),\s*@function', line)
        if match_def:
            # Save the previous function and its calls
            if current_function:
                functions[current_function] = {
                    "definition": {"name": current_function,
                    "signature": "",
                    "file": filepath},
                    "calls": calls
                }
            current_function = match_def.group(1)
            calls = []
            continue

        # Match function calls
        match_call = re.match(r'\s*call[048]\s+(\w+)', line)
        if match_call and current_function:
            called_function = match_call.group(1)
            calls.append({
                "name": called_function,
                "file": "",  # To be filled in later
                "signature":""
            })

    # Save the last function
    if current_function:
        functions[current_function] = {
            "definition": {"name": current_function,
            "signature": "",
            "file": filepath},
            "calls": calls
        }

    return functions

def parse_directory(directory):
    all_functions = {}

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.S'):
                filepath = os.path.join(root, file)
                functions = parse_asm_file(filepath)
                all_functions.update(functions)

    # Fill in file and signature for called functions if defined
    for func in all_functions.values():
        for call in func["calls"]:
            if call["name"] in all_functions:
                call["file"] = all_functions[call["name"]]['definition']["file"]
                call["signature"] = all_functions[call["name"]]['definition']["signature"]

    return all_functions

def main():
    directory = "main"  # Change to the directory containing your .S files
    all_functions = parse_directory(directory)

    with open('call_graph.json', 'w') as outfile:
        json.dump(all_functions, outfile, indent=4)

if __name__ == "__main__":
    main()
