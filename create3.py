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

if __name__ == "__main__":
    directory = 'main'  # Replace with the path to your source code directory
    functions = aggregate_functions(directory)
    call_graph = generate_call_graph(functions)

    # Write the call graph to a JSON file
    with open('call_graph.json', 'w') as json_file:
        json.dump(call_graph, json_file, indent=4)

    print("Call graph has been written to call_graph.json")
