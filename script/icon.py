# Draws public/icon.svg, the app icon: + − × ÷ two by two on the site's blue, from the Monoton font's own outlines,
# with the divide sign's dots drawn as rings to match its bar. Needs fontTools (pip install fonttools) and
# Monoton-Regular.ttf (Google Fonts, SIL Open Font License):
#
#   python script/icon.py Monoton-Regular.ttf public/icon.svg
#
# Then make the PNGs and favicon.ico from it with rsvg-convert and ImageMagick (512, 192, 180, 96, and 16/32/48),
# and bump ApplicationHelper::ICON_VERSION so browsers and phones fetch them again
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen

font_path, out = sys.argv[1], sys.argv[2]
font = TTFont(font_path)
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
NAVY, YELLOW, RED = "#24365c", "#fdfc52", "#e06a5e"
SIZE, CELL, PAD = 512, 200, 56  # the symbols sit in a 400 square, inside the middle 80% a maskable icon keeps
cells = [ ("+", YELLOW, 0, 0), ("−", RED, 1, 0), ("×", RED, 0, 1), ("÷", YELLOW, 1, 1) ]

def bounds(name):
    pen = BoundsPen(glyphs)
    glyphs[name].draw(pen)
    return pen.bounds

names = [ cmap[ord(ch)] for ch, *_ in cells ]
# Each fills the same square, so they look the same size whatever their shapes
FIT = CELL - 46

parts = [ f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}">', f'<rect width="{SIZE}" height="{SIZE}" fill="{NAVY}"/>' ]
def place(name, colour, cx, cy, scale):
    """A glyph, its middle at cx, cy, at scale (font units to the SVG's, which go down, not up)"""
    pen = SVGPathPen(glyphs)
    glyphs[name].draw(pen)
    x0, y0, x1, y1 = bounds(name)
    tx = cx - (x0 + x1) / 2 * scale
    ty = cy + (y0 + y1) / 2 * scale
    return f'<path fill="{colour}" transform="translate({tx:.2f} {ty:.2f}) scale({scale:.5f} {-scale:.5f})" d="{pen.getCommands()}"/>'

# The divide sign: Monoton's own bar of three stripes, with a dot above and below drawn to match it: a solid
# centre and a ring around it, each line as thick as a stripe, with a stripe's gap between, like Monoton's O
# Measured in stripes (w): the bar is 5 (three stripes, two gaps), each dot 5.2 across, 0.9 between dot and bar
DOT_CORE, RING, BAR, GAP_W = 0.6, 2.1, 5, 0.9

for (ch, colour, col, row), name in zip(cells, names):
    cx = PAD + CELL * col + CELL / 2
    cy = PAD + CELL * row + CELL / 2
    if ch == "÷":
        bar = cmap[ord("−")]
        x0, y0, x1, y1 = bounds(bar)
        dot = 2 * (RING + 0.5)
        w = FIT / (BAR + 2 * GAP_W + 2 * dot)
        parts.append(place(bar, colour, cx, cy, BAR * w / (y1 - y0)))
        for sign in (-1, 1):
            dy = cy + sign * (BAR / 2 + GAP_W + dot / 2) * w
            parts.append(f'<circle cx="{cx:.2f}" cy="{dy:.2f}" r="{DOT_CORE * w:.2f}" fill="{colour}"/>')
            parts.append(f'<circle cx="{cx:.2f}" cy="{dy:.2f}" r="{RING * w:.2f}" fill="none" stroke="{colour}" stroke-width="{w:.2f}"/>')
        continue
    x0, y0, x1, y1 = bounds(name)
    parts.append(place(name, colour, cx, cy, FIT / max(x1 - x0, y1 - y0)))
parts.append("</svg>")
open(out, "w").write("\n".join(parts))
