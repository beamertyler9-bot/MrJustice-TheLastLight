#!/usr/bin/env python3
# Generates a tileable reptile-scale detail texture (grey, for multiplying with vertex colour)
# and a matching OpenGL normal map.
import numpy as np
from PIL import Image
N = 512
rows, cols = 16, 16          # scale grid (tileable: divides N)
sy, sx = N / rows, N / cols
yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
height = np.full((N, N), -1.0)
rng = np.random.default_rng(7)
jit = rng.uniform(-0.08, 0.08, size=(rows, cols, 2))
for r in range(rows):
    for c in range(cols):
        cy = (r + 0.5) * sy + jit[r, c, 0] * sy
        cx = (c + 0.5 + (0.5 if r % 2 else 0.0)) * sx + jit[r, c, 1] * sx
        # wrap-aware offsets
        dy = (yy - cy + N / 2) % N - N / 2
        dx = (xx - cx + N / 2) % N - N / 2
        # roof-tile scale: rounded at the bottom (+y), tucked under the next row at the top
        u = dx / (sx * 0.62); v = dy / (sy * 0.78)
        d = np.sqrt(u * u + np.where(v > 0, v * v, (v * 0.6) ** 2))
        h = np.clip(1.0 - d, 0, None) ** 0.6 + 0.35 * np.clip(v, -1, 1) * (d < 1)
        h = np.where(d < 1, h, -1.0)
        height = np.maximum(height, h)
height = np.clip(height, 0, None)
height = height / height.max()
# grey detail: light on the scale crowns, dark in the seams, slight per-scale variation
grey = 0.62 + 0.38 * height ** 0.7
grey -= 0.25 * (height < 0.08)
grey = np.clip(grey, 0, 1)
Image.fromarray((grey * 255).astype(np.uint8), "L").save("/home/claude/mrjustice-thelastlight/assets/cast/scale_detail_gray.png")
# normal map (OpenGL, +Y up) from the height field
s = 3.0
gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * s
gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * s
nz = np.ones_like(height)
n = np.stack([-gx, gy, nz], -1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
img = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
Image.fromarray(img, "RGB").save("/home/claude/mrjustice-thelastlight/assets/cast/scale_normal.png")
print("ok", height.mean())
