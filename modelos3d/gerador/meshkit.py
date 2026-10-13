"""
meshkit — geração procedural de malhas e exportação GLB (glTF 2.0) sem dependências
além de numpy. Cada peça é uma malha com nome e cor; o jogo recolore pelo nome.
"""
import json
import math
import struct

import numpy as np


# ---------------------------------------------------------------- malha base
class Mesh:
    def __init__(self, name, vertices, faces, role, color):
        self.name = name
        self.v = np.asarray(vertices, dtype=np.float64)
        self.f = np.asarray(faces, dtype=np.int64)
        self.role = role
        self.color = color  # (r, g, b) 0-255

    def transformed(self, matrix):
        hom = np.c_[self.v, np.ones(len(self.v))]
        out = (matrix @ hom.T).T[:, :3]
        m = Mesh(self.name, out, self.f, self.role, self.color)
        # espelhamento inverte a orientação dos triângulos
        if np.linalg.det(matrix[:3, :3]) < 0:
            m.f = m.f[:, ::-1].copy()
        return m

    def normals(self):
        n = np.zeros_like(self.v)
        tri = self.v[self.f]
        fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        for i in range(3):
            np.add.at(n, self.f[:, i], fn)
        length = np.linalg.norm(n, axis=1)
        length[length == 0] = 1
        return n / length[:, None]


# ---------------------------------------------------------------- matrizes
def translate(x, y, z):
    m = np.eye(4)
    m[:3, 3] = [x, y, z]
    return m


def scale(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return np.diag([x, y, z, 1.0])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])


def chain(*ms):
    out = np.eye(4)
    for m in ms:
        out = out @ m
    return out


# ---------------------------------------------------------------- primitivas
def sphere(rings=14, segments=20):
    verts = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(segments):
            theta = 2 * math.pi * j / segments
            verts.append((math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta)))
    faces = []
    for i in range(rings):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            c = (i + 1) * segments + j
            d = (i + 1) * segments + (j + 1) % segments
            if i != 0:
                faces.append((a, b, c))
            if i != rings - 1:
                faces.append((b, d, c))
    return np.array(verts), np.array(faces)


def lathe(profile, segments=24, axis="y"):
    """Gira um perfil [(raio, altura), ...] em volta do eixo. Fecha topo e base."""
    verts = []
    for r, h in profile:
        for j in range(segments):
            t = 2 * math.pi * j / segments
            x, z = r * math.cos(t), r * math.sin(t)
            verts.append((x, h, z) if axis == "y" else (x, z, h))
    faces = []
    n = len(profile)
    for i in range(n - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            c = (i + 1) * segments + j
            d = (i + 1) * segments + (j + 1) % segments
            faces += [(a, c, b), (b, c, d)]
    # tampas
    bottom = len(verts)
    verts.append((0, profile[0][1], 0) if axis == "y" else (0, 0, profile[0][1]))
    top = len(verts)
    verts.append((0, profile[-1][1], 0) if axis == "y" else (0, 0, profile[-1][1]))
    last = (n - 1) * segments
    for j in range(segments):
        faces.append((bottom, j, (j + 1) % segments))
        faces.append((top, last + (j + 1) % segments, last + j))
    v, f = np.array(verts, dtype=float), np.array(faces)
    if axis == "z":
        f = f[:, ::-1].copy()
    return v, f


def tube(points, radii, segments=10):
    """Tubo ao longo de uma curva (lista de pontos 3D) com raio variável."""
    pts = np.asarray(points, dtype=float)
    verts = []
    up = np.array([0.0, 0.0, 1.0])
    for i, p in enumerate(pts):
        tangent = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        tangent /= np.linalg.norm(tangent)
        ref = up if abs(np.dot(tangent, up)) < 0.9 else np.array([1.0, 0, 0])
        side = np.cross(tangent, ref)
        side /= np.linalg.norm(side)
        other = np.cross(tangent, side)
        r = radii[i]
        for j in range(segments):
            t = 2 * math.pi * j / segments
            verts.append(p + r * (math.cos(t) * side + math.sin(t) * other))
    faces = []
    for i in range(len(pts) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            c = (i + 1) * segments + j
            d = (i + 1) * segments + (j + 1) % segments
            faces += [(a, b, c), (b, d, c)]
    start, end = len(verts), len(verts) + 1
    verts.append(pts[0])
    verts.append(pts[-1])
    last = (len(pts) - 1) * segments
    for j in range(segments):
        faces.append((start, (j + 1) % segments, j))
        faces.append((end, last + j, last + (j + 1) % segments))
    return np.array(verts), np.array(faces)


def petal(length=1.0, width=0.4, thickness=0.05, curl=0.3, pointy=False, steps=10, across=6):
    """Pétala curva deitada ao longo de +X, curvando para cima (+Y) na ponta."""
    verts = []
    for side in (1, -1):
        for i in range(steps + 1):
            u = i / steps
            half = width * math.sin(math.pi * u) ** (0.9 if not pointy else 1.4)
            if pointy:
                half *= 1 - 0.25 * u
            lift = curl * u * u
            for k in range(across + 1):
                w = (k / across - 0.5) * 2 * half
                cup = 0.15 * width * (1 - (2 * k / across - 1) ** 2)  # concavidade
                verts.append((u * length, lift + cup + side * thickness / 2, w))
    faces = []
    row = across + 1
    layer = (steps + 1) * row
    for i in range(steps):
        for k in range(across):
            a = i * row + k
            b, c, d = a + 1, a + row, a + row + 1
            faces += [(a, c, b), (b, c, d)]
            faces += [(layer + a, layer + b, layer + c), (layer + b, layer + d, layer + c)]
    # bordas
    for i in range(steps):
        for k in (0, across):
            a, c = i * row + k, (i + 1) * row + k
            faces += [(a, layer + a, c), (c, layer + a, layer + c)] if k == 0 else [(a, c, layer + a), (c, layer + c, layer + a)]
    return np.array(verts, dtype=float), np.array(faces)


def ellipsoid(rx, ry, rz, rings=14, segments=20):
    v, f = sphere(rings, segments)
    return v * np.array([rx, ry, rz]), f


def icosphere(subdiv=2):
    t = (1 + 5 ** 0.5) / 2
    verts = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
             (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
             (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
             (8, 6, 7), (9, 8, 1)]
    verts = [np.array(v) / np.linalg.norm(v) for v in verts]
    for _ in range(subdiv):
        cache, new_faces = {}, []

        def mid(a, b):
            key = tuple(sorted((a, b)))
            if key not in cache:
                m = (verts[a] + verts[b]) / 2
                verts.append(m / np.linalg.norm(m))
                cache[key] = len(verts) - 1
            return cache[key]

        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            new_faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = new_faces
    return np.array(verts), np.array(faces)


def make(name, vf, role, color, matrix=None):
    m = Mesh(name, vf[0], vf[1], role, color)
    return m.transformed(matrix) if matrix is not None else m


# ---------------------------------------------------------------- exportação GLB
def export_glb(path, models):
    """models: {nomeDoModelo: [Mesh, ...]} -> um GLB com hierarquia Pacote/Modelo/Peça."""
    gltf = {
        "asset": {"version": "2.0", "generator": "Reino das Abelhas meshkit"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "PacoteAbelhas", "children": []}],
        "meshes": [],
        "materials": [],
        "accessors": [],
        "bufferViews": [],
        "buffers": [],
    }
    blob = bytearray()

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        offset = len(blob)
        blob.extend(data)
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
        return len(gltf["bufferViews"]) - 1

    for model_name, meshes in models.items():
        model_index = len(gltf["nodes"])
        gltf["nodes"].append({"name": model_name, "children": []})
        gltf["nodes"][0]["children"].append(model_index)
        used = {}
        for mesh in meshes:
            pos = mesh.v.astype(np.float32)
            nor = mesh.normals().astype(np.float32)
            idx = mesh.f.astype(np.uint32).ravel()
            pv = add_view(pos.tobytes(), 34962)
            nv = add_view(nor.tobytes(), 34962)
            iv = add_view(idx.tobytes(), 34963)
            acc = gltf["accessors"]
            acc.append({"bufferView": pv, "componentType": 5126, "count": len(pos), "type": "VEC3",
                        "min": pos.min(axis=0).tolist(), "max": pos.max(axis=0).tolist()})
            acc.append({"bufferView": nv, "componentType": 5126, "count": len(nor), "type": "VEC3"})
            acc.append({"bufferView": iv, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
            r, g, b = mesh.color
            gltf["materials"].append({
                "name": mesh.role,
                "pbrMetallicRoughness": {"baseColorFactor": [r / 255, g / 255, b / 255, 1.0],
                                         "metallicFactor": 0.0, "roughnessFactor": 0.75},
            })
            gltf["meshes"].append({"name": mesh.name, "primitives": [{
                "attributes": {"POSITION": len(acc) - 3, "NORMAL": len(acc) - 2},
                "indices": len(acc) - 1, "material": len(gltf["materials"]) - 1}]})
            # nome único por modelo: "Papel_N" (o jogo usa o que vem antes do "_")
            used[mesh.role] = used.get(mesh.role, 0) + 1
            node_name = f"{mesh.role}_{used[mesh.role]}"
            gltf["nodes"].append({"name": node_name, "mesh": len(gltf["meshes"]) - 1})
            gltf["nodes"][model_index]["children"].append(len(gltf["nodes"]) - 1)

    while len(blob) % 4:
        blob.append(0)
    gltf["buffers"].append({"byteLength": len(blob)})
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode()
    while len(json_bytes) % 4:
        json_bytes += b" "
    total = 12 + 8 + len(json_bytes) + 8 + len(blob)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, total))
        fh.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        fh.write(json_bytes)
        fh.write(struct.pack("<II", len(blob), 0x004E4942))
        fh.write(bytes(blob))
    return total
