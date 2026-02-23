import json
import sys

def remove_texcoord2(path):
    with open(path, 'r') as f:
        gltf = json.load(f)

    removed = 0
    for mesh in gltf.get('meshes', []):
        for primitive in mesh.get('primitives', []):
            attrs = primitive.get('attributes', {})
            # TEXCOORD_0, TEXCOORD_1 은 유지, 2 이상 제거
            keys_to_remove = [k for k in attrs if k.startswith('TEXCOORD_') and int(k.split('_')[1]) >= 2]
            for k in keys_to_remove:
                del attrs[k]
                removed += 1

    with open(path, 'w') as f:
        json.dump(gltf, f)

    print(f"{path}: removed {removed} extra TEXCOORD attribute(s)")

for path in sys.argv[1:]:
    remove_texcoord2(path)
