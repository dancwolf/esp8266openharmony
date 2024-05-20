import os
import re
import subprocess
import json

def get_source_files(directory, extensions=('.c', '.s')):
    """Recursively get all source files in the directory"""
    source_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(extensions):
                source_files.append(os.path.join(root, file))
    return source_files

def generate_ast(file_path):
    """Generate AST using Clang"""
    try:
        result = subprocess.run(
            ['clang', '-Xclang', '-ast-dump', '-fsyntax-only', file_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        return result.stdout
    except Exception as e:
        print(f"Error generating AST for {file_path}: {e}")
        return ""

def extract_function_definitions(ast_output):
    """Extract function definitions from AST output"""
    pattern = r'FunctionDecl.*? (\w+) \''
    function_definitions = re.findall(pattern, ast_output)
    return function_definitions

def extract_function_calls(ast_output):
    """Extract function calls from AST output"""
    pattern = r'DeclRefExpr.*? Function \w+ \'(\w+)\''
    function_calls = re.findall(pattern, ast_output)
    return function_calls

def parse_ast(ast):
    """Parse the AST to extract function definitions and call relationships"""
    function_definitions = extract_function_definitions(ast)
    function_calls = extract_function_calls(ast)

    call_graph = {func: [] for func in function_definitions}
    for function in function_definitions:
        for callee in function_calls:
            if callee in ast:
                call_graph[function].append(callee)

    return call_graph

def merge_call_graphs(graphs):
    """Merge multiple call graphs"""
    merged_graph = {}
    for graph in graphs:
        for caller, callees in graph.items():
            if caller not in merged_graph:
                merged_graph[caller] = []
            merged_graph[caller].extend(callees)
    return merged_graph

def main(directory):
    source_files = get_source_files(directory)
    call_graphs = []

    for source_file in source_files:
        ast = generate_ast(source_file)
        if ast:
            call_graph = parse_ast(ast)
            call_graphs.append(call_graph)

    merged_call_graph = merge_call_graphs(call_graphs)
    return merged_call_graph

if __name__ == "__main__":
    directory = 'main'  # Replace with your source folder path
    call_graph = main(directory)
    
    # Save call graph to JSON file
    with open('call_graph.json', 'w') as f:
        json.dump(call_graph, f, indent=4)
    
    print(f"Call graph has been saved to call_graph.json")
