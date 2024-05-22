#encodeing=utf-8
import os
import json
import re
import subprocess

def run_clang_ast(file_path):
    result = subprocess.run(['clang', '-Xclang', '-ast-dump', '-fsyntax-only', file_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return result.stdout

def parse_ast(ast, file_path):
    functions = {}
    current_function = None

    # Regex to match function definitions and calls, ignoring any leading characters
    function_def_regex = re.compile(r'^\|.*FunctionDecl.* line:\d+:\d+ (\w+) \'([^\']+)\'')
    call_expr_regex = re.compile(r'^\|.*DeclRefExpr.* Function.*\'(\w+)\' \'([^\']+)\'')

    for line in ast.splitlines():
        func_match = function_def_regex.match(line)
        call_match = call_expr_regex.match(line)

        if func_match:
            current_function = func_match.group(1)
            functions[current_function] = {
                "definition": {
                    "name": current_function,
                    "signature": func_match.group(2),
                    "file": file_path
                },
                "calls": []
            }

        elif call_match and current_function:
            called_function = call_match.group(1)
            called_function_signature = call_match.group(2)
            functions[current_function]["calls"].append({
                "name": called_function,
                "signature": called_function_signature,
                "file": ""
            })
    print(ast,file_path,functions)
    return functions

def aggregate_functions(directory):
    all_functions = {}
    
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.c') or file.endswith('.h'):
                file_path = os.path.join(root, file)
                print(f"Parsing {file_path}")
                ast = run_clang_ast(file_path)
                functions = parse_ast(ast, file_path)
                all_functions.update(functions)
    
    return all_functions

def generate_call_graph(functions):
    call_graph = {}

    for func_name, func_data in functions.items():
        call_graph[func_name] = {
            "definition": {
                "name": func_name,
                "signature": func_data["definition"]["signature"],
                "file": func_data["definition"]["file"]
            },
            "calls": []
        }
        for called_func in set(call["name"] for call in func_data["calls"]):
            call_graph[func_name]["calls"].append({
                "name": called_func,
                "signature": next(call["signature"] for call in func_data["calls"] if call["name"] == called_func),
                "file": functions[called_func]["definition"]["file"] if called_func in functions else ""
            })

    return call_graph
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
def merge_json_files(data1, data2):
    # Load the JSON data from both files

    
    # Merge the two dictionaries
    merged_data = data1.copy()
    #print(merged_data)
    for key, value in data2.items():
        if key in merged_data:
            print(f"Warning: duplicate function name {key} found. Overwriting.")
        merged_data[key] = value
        #print(key,value)
    #print(merged_data)
    
    
    # Save the merged JSON data to the output file
    return merged_data
def update_calls_with_definition(json_data):
    for func_name, func_data in json_data.items():
        # Check and update the main function definition signature
        if not func_data['definition'].get('signature') or func_data['definition']['signature'] == "":
            func_data['definition']['signature'] = 'void (void)'

        # Check and update the signature for each call in the calls array
        for call in func_data['calls']:
            called_func_name = call['name']
            if called_func_name in json_data:
                call['signature'] = json_data[called_func_name]['definition']['signature']
                call['file'] = json_data[called_func_name]['definition']['file']
            
            # Ensure every call's signature is set to "void (void)" if it is empty or an empty string
            if not call.get('signature') or call['signature'] == "":
                call['signature'] = 'void (void)'

            # If the file attribute is empty, set it to "main/unknown.c"
            if not call.get('file') or call['file'] == "":
                call['file'] = "main/unknown.c"
    #print(json_data)
    return json_data

def add_unknown_functions(json_data):
    unknown_functions = {}

    for func_name, func_data in json_data.items():
        for call in func_data['calls']:
            called_func_name = call['name']
            if call['file'] == "main/unknown.c":
                if called_func_name not in json_data:
                    unknown_functions[called_func_name] = {
                        "definition": {
                            "name": called_func_name,
                            "signature": "void (void)",
                            "file": "main/unknown.c"
                        },
                        "calls": []
                    }

    # Add the collected unknown functions to the main json_data
    json_data.update(unknown_functions)
    
    return json_data

if __name__ == "__main__":
    directory = 'main'  # Replace with the path to your source code directory
    functions = aggregate_functions(directory)
    functions2=parse_directory(directory)

    call_graph = generate_call_graph(functions)
    print(call_graph)

    json_all=merge_json_files(call_graph,functions2)
    print(json_all)
    json_all=update_calls_with_definition(json_all)
    print(json_all)
    json_all=add_unknown_functions(json_all)
    print(json_all)
    # Write the call graph to a JSON file
    with open('call_graph.json', 'w') as json_file:
        json.dump(json_all, json_file, indent=4)

    print("Call graph has been written to call_graph.json")
