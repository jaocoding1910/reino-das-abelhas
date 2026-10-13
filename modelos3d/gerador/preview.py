"""Renderiza uma prévia de cada modelo (sombreamento simples) para conferência visual."""
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

from modelos import build

LIGHT = np.array([0.4, 0.8, -0.5])
LIGHT /= np.linalg.norm(LIGHT)


def render(ax, meshes, elev, azim):
    polys, colors = [], []
    allv = []
    for m in meshes:
        # Roblox: Y para cima, -Z frente. Matplotlib: Z para cima. Mapeia (x, y, z) -> (x, -z, y).
        v = m.v[:, [0, 2, 1]] * np.array([1, -1, 1])
        tri = v[m.f]
        n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        n /= np.linalg.norm(n, axis=1)[:, None] + 1e-9
        shade = np.clip(0.35 + 0.65 * np.abs(n @ LIGHT[[0, 2, 1]] * np.array([1])), 0, 1)
        base = np.array(m.color) / 255
        alpha = 0.45 if m.role.startswith("Asa") else 1.0
        for t, s in zip(tri, shade):
            polys.append(t)
            colors.append((*(base * s), alpha))
        allv.append(v)
    allv = np.vstack(allv)
    ax.add_collection3d(Poly3DCollection(polys, facecolors=colors, edgecolors="none"))
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    center, span = (lo + hi) / 2, (hi - lo).max() / 2
    for setter, c in zip((ax.set_xlim, ax.set_ylim, ax.set_zlim), center):
        setter(c - span, c + span)
    ax.view_init(elev=elev, azim=azim)
    ax.set_axis_off()


if __name__ == "__main__":
    models = build()
    names = sys.argv[1:] or list(models)
    fig = plt.figure(figsize=(4.2 * len(names), 4.6), facecolor="#1c1712")
    for i, name in enumerate(names):
        ax = fig.add_subplot(1, len(names), i + 1, projection="3d", facecolor="#1c1712")
        # Abelha vista de 3/4 pela frente; demais de lado.
        render(ax, models[name], 18, -60 if name == "Abelha" else -70)
        ax.set_title(name, color="#ffc440", fontsize=14)
    plt.subplots_adjust(left=0, right=1, top=0.92, bottom=0, wspace=0)
    plt.savefig("preview.png", dpi=90, facecolor=fig.get_facecolor())
    print("preview.png")
