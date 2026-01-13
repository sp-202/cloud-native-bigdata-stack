import yaml
import sys

def no_duplicates_constructor(loader, node, deep=False):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        value = loader.construct_object(value_node, deep=deep)
        if key in mapping:
            print(f"ERROR: Duplicate key found: {key}")
            print(f"  Line: {key_node.start_mark.line + 1}")
            raise yaml.ConstructorError("while constructing a mapping", node.start_mark,
                                        f"found duplicate key {key}", key_node.start_mark)
        mapping[key] = value
    return loader.construct_mapping(node, deep)

yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, no_duplicates_constructor, Loader=yaml.SafeLoader)

filename = sys.argv[1]
try:
    with open(filename, 'r') as f:
        list(yaml.safe_load_all(f))
    print(f"OK: {filename}")
except Exception as e:
    print(f"FAIL: {filename} - {e}")
    sys.exit(1)
