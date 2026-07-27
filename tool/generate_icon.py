#!/usr/bin/env python3
"""Regenerate the app icon source images from the La Crypta isotype.

The lacrypta.ar favicon (`/img/schema-logo.png`) is only 112x112 — far too
small for an app icon, which needs 1024x1024 for iOS. So rather than upscaling
it, this rasterises the same vector the favicon was made from
(`assets/logos/lacrypta-iso.svg`) and reproduces the favicon's composition
exactly, measured from the original:

    background  #101010
    mark        white, centred, 64.3% of canvas height  (72/112)

The two cubic segments of the arch are flattened, then the whole thing is drawn
at 4x and downsampled, which antialiases without needing an SVG delegate.

    python3 tool/generate_icon.py && dart run flutter_launcher_icons
"""

from PIL import Image, ImageDraw

VIEWBOX_W, VIEWBOX_H = 82.04, 94.42
BACKGROUND = (16, 16, 16, 255)   # #101010, sampled from the live favicon
MARK = (255, 255, 255, 255)
SIZE = 1024
SUPERSAMPLE = 4

# Share of canvas height the mark occupies.
FULL_SCALE = 72 / 112       # matches the favicon
# Android adaptive icons stack two reductions: the launcher only ever shows the
# inner 72dp of a 108dp canvas (66.7%), and flutter_launcher_icons additionally
# insets the foreground drawable by 16%. So the mark lands at
# scale * 0.84 * (1/0.667) of the visible area — 0.62 puts it at ~64% of the
# safe zone, which reads correctly next to other launcher icons. At the 0.46
# that matches the favicon's own ratio it looks lost inside the circle.
ADAPTIVE_SCALE = 0.62


def cubic(p0, c0, c1, p1, steps=240):
    """Flatten one cubic bezier into points (endpoint excluded)."""
    out = []
    for i in range(steps):
        t = i / steps
        u = 1 - t
        out.append((
            u*u*u*p0[0] + 3*u*u*t*c0[0] + 3*u*t*t*c1[0] + t*t*t*p1[0],
            u*u*u*p0[1] + 3*u*u*t*c0[1] + 3*u*t*t*c1[1] + t*t*t*p1[1],
        ))
    return out


def isotype_points():
    """The isotype outline: a flat-based arch with three ledger slots cut from
    its right edge. Transcribed from assets/logos/lacrypta-iso.svg."""
    pts = [
        (20.06, 85.85), (20.06, 76.32), (82, 76.32), (82, 69.44),
        (33.73, 69.44), (33.73, 59.91), (82, 59.91), (82, 53),
        (45.58, 53), (45.58, 43.5), (82, 43.5), (82, 43.37),
    ]
    # The dome. The second curve is the SVG's `S` shorthand expanded: its first
    # control point is the reflection of the previous curve's second control
    # about the join at (41, 0) -> (18.32, 0).
    pts += cubic((82, 43.37), (82, 20.72), (63.68, 0), (41, 0))
    pts += cubic((41, 0), (18.32, 0), (0, 20.72), (0, 43.37))
    pts += [(0, 43.37), (0, 94.42), (82, 94.42), (82, 85.85)]
    return pts


def render(path, scale, background):
    s = SIZE * SUPERSAMPLE
    img = Image.new('RGBA', (s, s), background)
    draw = ImageDraw.Draw(img)

    mark_h = s * scale
    mark_w = mark_h * VIEWBOX_W / VIEWBOX_H
    k = mark_h / VIEWBOX_H
    ox = (s - mark_w) / 2
    oy = (s - mark_h) / 2

    draw.polygon([(ox + x * k, oy + y * k) for x, y in isotype_points()], fill=MARK)
    img.resize((SIZE, SIZE), Image.LANCZOS).save(path)
    print(f'wrote {path}')


if __name__ == '__main__':
    render('assets/icon/icon.png', FULL_SCALE, BACKGROUND)
    render('assets/icon/icon_foreground.png', ADAPTIVE_SCALE, (0, 0, 0, 0))
