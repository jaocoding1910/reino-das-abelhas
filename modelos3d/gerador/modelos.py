"""
Gera o pacote de modelos 3D do Reino das Abelhas (PacoteAbelhas.glb).
Frente dos modelos = -Z (padrão do Roblox). Altura = +Y.
Cada peça se chama "<Papel>_<n>"; o jogo recolore pelo Papel (Config.Art.Palette).
"""
import math
import sys

import numpy as np

from meshkit import (chain, ellipsoid, export_glb, icosphere, lathe, make, petal, rot_x, rot_y, rot_z, scale,
                     sphere, translate, tube)

YELLOW = (255, 196, 40)
FUZZ = (255, 214, 110)
BLACK = (35, 28, 24)
WHITE = (250, 250, 250)
PINK = (255, 140, 160)
WING = (220, 240, 255)


# ------------------------------------------------------------------ Abelha
def abelha():
    parts = []
    # Abdômen listrado: perfil girado em volta do eixo Z (de z=0 a z=3.4).
    def radius(z):
        t = z / 3.0
        return 1.6 * math.sin(math.pi * min(1, 0.15 + t * 0.85)) ** 0.6 + 0.08

    bands = [(0.0, 0.6, "Corpo"), (0.6, 1.05, "Listra"), (1.05, 1.65, "Corpo"), (1.65, 2.1, "Listra"), (2.1, 3.0, "Corpo")]
    for start, end, role in bands:
        steps = 6
        profile = [(radius(start + (end - start) * i / steps), start + (end - start) * i / steps) for i in range(steps + 1)]
        if end >= 3.0:
            profile[-1] = (0.25, 3.0)
        color = YELLOW if role == "Corpo" else BLACK
        parts.append(make(role, lathe(profile, 28, axis="z"), role, color, translate(0, 0.1, 0.2)))

    # Tórax peludo e cabeça.
    parts.append(make("Pelo", ellipsoid(1.25, 1.2, 1.15), "Pelo", FUZZ, translate(0, 0.25, -0.75)))
    parts.append(make("Cabeca", ellipsoid(1.25, 1.15, 1.1), "Cabeca", BLACK, translate(0, 0.5, -2.1)))

    # Olhos grandes e fofos.
    for side in (-1, 1):
        parts.append(make("Olho", ellipsoid(0.42, 0.5, 0.3), "OlhoBranco", WHITE, translate(side * 0.5, 0.7, -3.0)))
        parts.append(make("Pupila", ellipsoid(0.24, 0.3, 0.15), "Pupila", BLACK, translate(side * 0.5, 0.65, -3.24)))
        parts.append(make("Brilho", ellipsoid(0.08, 0.08, 0.05), "Brilho", WHITE, translate(side * 0.42, 0.82, -3.36)))
        parts.append(make("Bochecha", ellipsoid(0.22, 0.14, 0.1), "Bochecha", PINK, translate(side * 0.85, 0.2, -2.9)))
        # Antena curva com bolinha.
        path = [(side * 0.3, 1.3, -2.3), (side * 0.45, 1.9, -2.6), (side * 0.7, 2.3, -2.9), (side * 0.95, 2.45, -3.0)]
        parts.append(make("Antena", tube(path, [0.07, 0.065, 0.06, 0.055], 8), "Antena", BLACK))
        parts.append(make("PontaAntena", ellipsoid(0.17, 0.17, 0.17, 8, 10), "Antena", BLACK, translate(side * 0.98, 2.47, -3.02)))
        # Asas (grande e pequena), achatadas e inclinadas para trás.
        parts.append(make("Asa", ellipsoid(2.1, 0.05, 1.0), "Asa" + ("E" if side < 0 else "D"), WING,
                          chain(translate(side * 1.8, 1.6, -0.2), rot_y(side * 0.35), rot_z(side * 0.35))))
        parts.append(make("AsaPequena", ellipsoid(1.4, 0.05, 0.65), "Asa" + ("E" if side < 0 else "D"), WING,
                          chain(translate(side * 1.3, 1.25, 0.7), rot_y(side * 0.7), rot_z(side * 0.25))))
        # Três patinhas de cada lado.
        for i, z in enumerate((-1.2, -0.6, 0.0)):
            leg = [(side * 0.7, -0.6, z), (side * 1.2, -1.0, z - 0.1), (side * 1.25, -1.5, z + 0.1)]
            parts.append(make("Pata", tube(leg, [0.09, 0.08, 0.06], 6), "Pata", BLACK))

    # Ferrão.
    parts.append(make("Ferrao", lathe([(0.22, 0), (0.12, 0.35), (0.02, 0.7)], 12, axis="z"), "Ferrao", BLACK,
                      translate(0, 0.1, 3.15)))
    return parts


# ------------------------------------------------------------------ Flor (margarida)
def flor():
    parts = []
    stem = [(0, 0, 0), (0.15, 3, 0.1), (0.05, 6, 0.3), (-0.1, 9, 0.2), (0, 10, 0)]
    parts.append(make("Caule", tube(stem, [0.32, 0.3, 0.28, 0.26, 0.26], 10), "Caule", (90, 150, 60)))
    for i, (h, ang) in enumerate([(3.5, 0.3), (6.0, 2.6)]):
        leaf = petal(2.6, 0.75, 0.06, 0.6, pointy=True)
        parts.append(make("Folha", leaf, "Folha", (80, 160, 70),
                          chain(translate(0.1, h, 0.2), rot_y(ang), rot_z(0.35))))
    top = translate(0, 10, 0)
    for i in range(14):
        a = 2 * math.pi * i / 14
        parts.append(make("Petala", petal(2.4, 0.55, 0.08, 0.5), "Petala", (250, 250, 245),
                          chain(top, rot_y(a), translate(0.5, 0, 0), rot_z(0.08))))
    for i in range(10):
        a = 2 * math.pi * (i + 0.5) / 10
        parts.append(make("PetalaInterna", petal(1.4, 0.4, 0.08, 0.6), "PetalaInterna", (255, 240, 200),
                          chain(top, rot_y(a), translate(0.4, 0.15, 0), rot_z(0.2))))
    dome = lathe([(0.95, 0), (0.95, 0.2), (0.8, 0.45), (0.5, 0.62), (0.0, 0.68)], 20)
    parts.append(make("Miolo", dome, "Miolo", (255, 185, 40), translate(0, 10.05, 0)))
    return parts


# ------------------------------------------------------------------ Girassol
def girassol():
    parts = []
    stem = [(0, 0, 0), (0.1, 4, 0), (0.0, 8, -0.3), (0, 11, -0.9), (0, 12, -1.3)]
    parts.append(make("Caule", tube(stem, [0.5, 0.45, 0.42, 0.4, 0.4], 10), "Caule", (80, 140, 55)))
    for h, ang in [(3, 0.5), (5, 2.9), (7.5, 4.6)]:
        parts.append(make("Folha", petal(3.6, 1.2, 0.07, 0.9, pointy=True), "Folha", (70, 150, 60),
                          chain(translate(0, h, 0), rot_y(ang), rot_z(0.3))))
    # Cabeça inclinada olhando para a frente (-Z).
    head = chain(translate(0, 12.4, -1.5), rot_x(-1.2))
    for layer, (count, length, offset) in enumerate([(22, 3.2, 1.6), (22, 2.6, 1.4)]):
        for i in range(count):
            a = 2 * math.pi * (i + layer * 0.5) / count
            parts.append(make("Petala", petal(length, 0.55, 0.08, 0.35, pointy=True), "Petala", (255, 200, 30),
                              chain(head, rot_y(a), translate(offset, -0.05 * layer, 0), rot_z(0.15 + 0.1 * layer))))
    disc = lathe([(1.9, 0), (1.9, 0.25), (1.6, 0.5), (0.9, 0.7), (0.0, 0.75)], 28)
    parts.append(make("Miolo", disc, "Miolo", (110, 70, 30), head))
    ring = lathe([(2.0, -0.05), (2.0, 0.2), (1.85, 0.3)], 28)
    parts.append(make("MioloBorda", ring, "MioloBorda", (150, 100, 40), head))
    return parts


# ------------------------------------------------------------------ Cogumelo
def cogumelo():
    parts = []
    stem = lathe([(0.9, 0), (1.05, 0.4), (0.8, 1.5), (0.7, 3.0), (0.75, 4.2)], 20)
    parts.append(make("Pe", stem, "Pe", (240, 230, 210)))
    cap = lathe([(0.6, 3.9), (3.0, 4.0), (3.2, 4.3), (2.8, 5.2), (1.8, 6.0), (0.0, 6.3)], 28)
    parts.append(make("Chapeu", cap, "Chapeu", (200, 60, 70)))
    rng = np.random.default_rng(7)
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(1.0, 2.5)
        h = 6.3 - 0.33 * r * r * 0.55
        tilt = math.atan2(r, 3)
        parts.append(make("Pinta", ellipsoid(0.38, 0.1, 0.38, 6, 10), "Pinta", (250, 250, 240),
                          chain(translate(math.cos(a) * r, h + 0.05, math.sin(a) * r), rot_y(-a), rot_z(-tilt))))
    return parts


# ------------------------------------------------------------------ Árvore
def arvore():
    parts = []
    trunk = lathe([(3.2, 0), (2.4, 1.0), (1.8, 3), (1.5, 8), (1.3, 14), (1.1, 18)], 18)
    parts.append(make("Tronco", trunk, "Tronco", (105, 75, 50)))
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        root = [(math.cos(a) * 1.2, 1.5, math.sin(a) * 1.2), (math.cos(a) * 2.6, 0.6, math.sin(a) * 2.6),
                (math.cos(a) * 3.8, 0.0, math.sin(a) * 3.8)]
        parts.append(make("Raiz", tube(root, [0.7, 0.5, 0.25], 8), "Tronco", (95, 68, 45)))
    rng = np.random.default_rng(3)
    blobs = [(0, 20, 0, 6.5), (4, 18.5, 1, 5), (-3.8, 18.8, -1.5, 5.2), (1, 18, -4, 4.8), (-1.5, 18.2, 3.8, 4.6),
             (0.5, 24.5, 0.5, 4.5), (3, 22, -2.5, 4), (-3, 22.5, 2, 4)]
    for i, (x, y, z, r) in enumerate(blobs):
        v, f = icosphere(2)
        v = v * (1 + rng.uniform(-0.06, 0.06, size=(len(v), 1)))
        role = "Copa" if i % 2 == 0 else "CopaClara"
        color = (65, 135, 60) if role == "Copa" else (95, 165, 70)
        parts.append(make(role, (v, f), role, color, chain(translate(x, y, z), scale(r, r * 0.85, r))))
    return parts


# ------------------------------------------------------------------ Cristal
def cristal():
    parts = []
    shards = [(0, 0, 0, 4.5, 0.9, 0, 0), (1.1, 0, 0.4, 3.0, 0.65, 0.35, 0.3), (-1.0, 0, -0.3, 3.4, 0.7, -0.3, -0.2),
              (0.2, 0, -1.1, 2.4, 0.55, 0.1, -0.4), (-0.4, 0, 1.0, 2.0, 0.5, -0.2, 0.35)]
    for x, y, z, h, r, tx, tz in shards:
        body = lathe([(r, 0), (r, h * 0.75), (0.0, h)], 6)
        parts.append(make("Cristal", body, "Cristal", (160, 90, 255), chain(translate(x, y - 0.3, z), rot_x(tx), rot_z(tz))))
    return parts


MODELS = {
    "Abelha": abelha,
    "Flor": flor,
    "Girassol": girassol,
    "Cogumelo": cogumelo,
    "Arvore": arvore,
    "Cristal": cristal,
}


def build():
    return {name: fn() for name, fn in MODELS.items()}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "PacoteAbelhas.glb"
    models = build()
    size = export_glb(out, models)
    for name, meshes in models.items():
        tris = sum(len(m.f) for m in meshes)
        print(f"{name:10s} {len(meshes):3d} peças  {tris:6d} triângulos")
    print(f"GLB: {out} ({size / 1024:.0f} KB)")
