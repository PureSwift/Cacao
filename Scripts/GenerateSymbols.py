#!/usr/bin/env python3
"""Writes Sources/Cacao/Graphics/SymbolGlyphs.swift: the drawings of system
symbols, as Swift, from Phosphor Icons (https://phosphoricons.com, MIT).

    git clone https://github.com/phosphor-icons/core phosphor
    Scripts/GenerateSymbols.py phosphor

Scripts/SymbolNames.txt says which Phosphor icon draws each symbol name. An
icon's `raw/regular` drawing (strokes 16 wide in a 256 square) becomes the
symbol, and its `raw/fill` drawing the symbol's `.fill` variant, both in a
unit square. Arcs and shapes become lines and cubic curves.

The glyphs in the repository were made from Phosphor 2.1.1 (2b75f3ad).
"""

import math
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = os.path.join(ROOT, "Scripts", "SymbolNames.txt")
OUTPUT = os.path.join(ROOT, "Sources", "Cacao", "Graphics", "SymbolGlyphs.swift")

# Phosphor draws in a 256 square with room around the icon; symbols fill
# more of theirs.
VIEW = 256.0
ENLARGEMENT = 1.15
STROKE_WIDTH = 16.0


# MARK: Geometry

def multiply(a, b):
    """The transform `a` after `b`, each (a, b, c, d, e, f) as in SVG."""
    return (a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1],
            a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3],
            a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5])


def apply(m, x, y):
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def parse_transform(text):
    matrix = IDENTITY
    for name, arguments in re.findall(r"(\w+)\s*\(([^)]*)\)", text or ""):
        v = [float(n) for n in re.findall(r"-?[\d.]+(?:e-?\d+)?", arguments)]
        if name == "translate":
            step = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif name == "scale":
            step = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        elif name == "rotate":
            angle = math.radians(v[0])
            step = (math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle), 0, 0)
            if len(v) == 3:
                step = multiply(multiply((1, 0, 0, 1, v[1], v[2]), step), (1, 0, 0, 1, -v[1], -v[2]))
        elif name == "matrix":
            step = tuple(v)
        else:
            raise ValueError("transform " + name)
        matrix = multiply(matrix, step)
    return matrix


def arc(x0, y0, rx, ry, rotation, large, sweep, x, y):
    """An SVG elliptical arc as cubic curves: [(x1, y1, x2, y2, x, y)]."""
    if (x0, y0) == (x, y):
        return []
    if rx == 0 or ry == 0:
        return [(x0, y0, x, y, x, y)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rotation)
    cos, sin = math.cos(phi), math.sin(phi)
    dx, dy = (x0 - x) / 2, (y0 - y) / 2
    x1, y1 = cos * dx + sin * dy, -sin * dx + cos * dy
    scale = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
    factor = math.sqrt(max(numerator / denominator, 0))
    if large == sweep:
        factor = -factor
    cx1, cy1 = factor * rx * y1 / ry, -factor * ry * x1 / rx
    cx, cy = cos * cx1 - sin * cy1 + (x0 + x) / 2, sin * cx1 + cos * cy1 + (y0 + y) / 2
    start = math.atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
    end = math.atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx)
    delta = end - start
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    count = max(int(math.ceil(abs(delta) / (math.pi / 2) - 1e-9)), 1)
    step = delta / count
    handle = 4 / 3 * math.tan(step / 4)

    def point(angle):
        px, py = rx * math.cos(angle), ry * math.sin(angle)
        return (cos * px - sin * py + cx, sin * px + cos * py + cy)

    def tangent(angle):
        px, py = -rx * math.sin(angle), ry * math.cos(angle)
        return (cos * px - sin * py, sin * px + cos * py)

    curves = []
    for index in range(count):
        a, b = start + index * step, start + (index + 1) * step
        (ax, ay), (bx, by) = point(a), point(b)
        (tax, tay), (tbx, tby) = tangent(a), tangent(b)
        if index == count - 1:
            bx, by = x, y
        curves.append((ax + handle * tax, ay + handle * tay, bx - handle * tbx, by - handle * tby, bx, by))
    return curves


def parse_path(d):
    """An SVG path as [("M", x, y) | ("L", x, y) | ("C", ...6) | ("Z",)]."""
    tokens = re.findall(r"[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", d)
    position = 0
    commands = []
    x = y = startx = starty = 0.0
    last_control = None
    command = None

    def number():
        nonlocal position
        position += 1
        return float(tokens[position - 1])

    def flag():
        # Flags may be written without a separator: "1,1" or "11".
        nonlocal position
        token = tokens[position]
        if len(token) > 1 and token[0] in "01" and "." not in token[:1]:
            tokens[position] = token[1:]
            return int(token[0])
        position += 1
        return int(float(token))

    while position < len(tokens):
        if tokens[position].isalpha():
            command = tokens[position]
            position += 1
        elif command == "M":
            command = "L"
        elif command == "m":
            command = "l"
        relative = command.islower()
        kind = command.upper()
        ox, oy = (x, y) if relative else (0.0, 0.0)
        control = None
        if kind == "M":
            x, y = ox + number(), oy + number()
            startx, starty = x, y
            commands.append(("M", x, y))
        elif kind == "L":
            x, y = ox + number(), oy + number()
            commands.append(("L", x, y))
        elif kind == "H":
            x = ox + number()
            commands.append(("L", x, y))
        elif kind == "V":
            y = oy + number()
            commands.append(("L", x, y))
        elif kind in "CS":
            if kind == "C":
                x1, y1 = ox + number(), oy + number()
            elif last_control and last_control[0] == "C":
                x1, y1 = 2 * x - last_control[1], 2 * y - last_control[2]
            else:
                x1, y1 = x, y
            x2, y2 = ox + number(), oy + number()
            x, y = ox + number(), oy + number()
            commands.append(("C", x1, y1, x2, y2, x, y))
            control = ("C", x2, y2)
        elif kind in "QT":
            if kind == "Q":
                qx, qy = ox + number(), oy + number()
            elif last_control and last_control[0] == "Q":
                qx, qy = 2 * x - last_control[1], 2 * y - last_control[2]
            else:
                qx, qy = x, y
            ex, ey = ox + number(), oy + number()
            commands.append(("C", x + (qx - x) * 2 / 3, y + (qy - y) * 2 / 3,
                             ex + (qx - ex) * 2 / 3, ey + (qy - ey) * 2 / 3, ex, ey))
            x, y = ex, ey
            control = ("Q", qx, qy)
        elif kind == "A":
            rx, ry, rotation = number(), number(), number()
            large, sweep = flag(), flag()
            ex, ey = ox + number(), oy + number()
            for curve in arc(x, y, rx, ry, rotation, large, sweep, ex, ey):
                commands.append(("C",) + curve)
            x, y = ex, ey
        elif kind == "Z":
            commands.append(("Z",))
            x, y = startx, starty
        else:
            raise ValueError("path command " + command)
        last_control = control
    return commands


def ellipse(cx, cy, rx, ry):
    return ([("M", cx + rx, cy)]
            + [("C",) + c for c in arc(cx + rx, cy, rx, ry, 0, 0, 1, cx - rx, cy)]
            + [("C",) + c for c in arc(cx - rx, cy, rx, ry, 0, 0, 1, cx + rx, cy)]
            + [("Z",)])


def rectangle(x, y, width, height, rx, ry):
    rx, ry = min(rx, width / 2), min(ry, height / 2)
    if rx == 0 or ry == 0:
        return [("M", x, y), ("L", x + width, y), ("L", x + width, y + height), ("L", x, y + height), ("Z",)]
    commands = [("M", x + rx, y)]
    corners = [(x + width - rx, y, x + width, y + ry),
               (x + width, y + height - ry, x + width - rx, y + height),
               (x + rx, y + height, x, y + height - ry),
               (x, y + ry, x + rx, y)]
    for sx, sy, ex, ey in corners:
        commands.append(("L", sx, sy))
        commands += [("C",) + c for c in arc(sx, sy, rx, ry, 0, 0, 1, ex, ey)]
    return commands + [("Z",)]


def points(text):
    v = [float(n) for n in re.findall(r"-?[\d.]+", text)]
    return list(zip(v[0::2], v[1::2]))


# MARK: Icons

def local(tag):
    return tag.rsplit("}", 1)[-1]


def shapes(path, flip):
    """An icon's drawing: [(is filled, commands)], in a unit square."""
    result = []

    def number(element, name):
        return float(element.get(name, "0"))

    def visit(element, matrix, opacity):
        matrix = multiply(matrix, parse_transform(element.get("transform")))
        opacity *= float(element.get("opacity", "1"))
        tag = local(element.tag)
        if tag in ("svg", "g"):
            for child in element:
                visit(child, matrix, opacity)
            return
        # Tints (duotone layers and the like) aren't part of a symbol.
        if opacity < 1:
            return
        stroked = element.get("stroke", "none") != "none"
        filled = element.get("fill", "black") != "none" and not stroked
        if not stroked and not filled:
            return
        if stroked and float(element.get("stroke-width", "1")) != STROKE_WIDTH:
            raise ValueError("%s: stroke width %s" % (path, element.get("stroke-width")))
        if tag == "path":
            commands = parse_path(element.get("d"))
        elif tag == "line":
            if filled:
                return
            commands = [("M", number(element, "x1"), number(element, "y1")),
                        ("L", number(element, "x2"), number(element, "y2"))]
        elif tag in ("polyline", "polygon"):
            ps = points(element.get("points"))
            commands = [("M",) + ps[0]] + [("L",) + p for p in ps[1:]]
            if tag == "polygon":
                commands.append(("Z",))
        elif tag == "circle":
            r = number(element, "r")
            commands = ellipse(number(element, "cx"), number(element, "cy"), r, r)
        elif tag == "ellipse":
            commands = ellipse(number(element, "cx"), number(element, "cy"), number(element, "rx"), number(element, "ry"))
        elif tag == "rect":
            rx = element.get("rx") or element.get("ry") or "0"
            ry = element.get("ry") or rx
            commands = rectangle(number(element, "x"), number(element, "y"), number(element, "width"),
                                 number(element, "height"), float(rx), float(ry))
        else:
            raise ValueError("%s: <%s>" % (path, tag))

        def place(x, y):
            x, y = apply(matrix, x, y)
            x = (x - VIEW / 2) * ENLARGEMENT / VIEW + 0.5
            y = (y - VIEW / 2) * ENLARGEMENT / VIEW + 0.5
            return (1 - x if flip else x, y)

        placed = []
        for command in commands:
            values = command[1:]
            placed.append((command[0],) + tuple(c for i in range(0, len(values), 2) for c in place(values[i], values[i + 1])))
        # Strokes drawn together join into one path; fills stay apart, as
        # each fills on its own.
        if stroked and result and not result[-1][0]:
            result[-1][1].extend(placed)
        else:
            result.append((filled, placed))

    visit(ET.parse(path).getroot(), IDENTITY, 1.0)
    if not result:
        raise ValueError(path + ": nothing to draw")
    return result


def identifier(icon, filled, flip):
    words = icon.split("-")
    name = words[0] + "".join(word.capitalize() for word in words[1:])
    if name[0].isdigit():
        name = "_" + name
    return "glyph_" + name + ("Flipped" if flip else "") + ("Fill" if filled else "")


def number(value):
    text = ("%.4f" % value).rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def function(name, drawing):
    lines = ["    private static func %s(_ g: inout Glyph) {" % name]
    for filled, commands in drawing:
        calls = []
        for command in commands:
            method = {"M": "m", "L": "l", "C": "c", "Z": "z"}[command[0]]
            calls.append("g.%s(%s)" % (method, ", ".join(number(v) for v in command[1:])))
        calls.append("g.fill()" if filled else "g.stroke()")
        for index in range(0, len(calls), 4):
            lines.append("        " + "; ".join(calls[index:index + 4]))
    lines.append("    }")
    return "\n".join(lines)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    phosphor = sys.argv[1]
    try:
        commit = subprocess.run(["git", "-C", phosphor, "rev-parse", "--short=8", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
    except OSError:
        commit = ""

    entries = []  # (names, icon, flip)
    seen = set()
    with open(NAMES) as file:
        for line in file:
            line = line.split("#")[0].strip()
            if not line:
                continue
            names, target = line.split("=")
            target = target.split()
            names = names.split()
            for name in names:
                if name in seen:
                    sys.exit("%s is listed twice" % name)
                seen.add(name)
            entries.append((names, target[0], "@flip" in target[1:]))

    functions = {}
    cases = []
    for names, icon, flip in entries:
        outline, fill = identifier(icon, False, flip), identifier(icon, True, flip)
        if outline not in functions:
            functions[outline] = function(outline, shapes(os.path.join(phosphor, "raw", "regular", icon + ".svg"), flip))
            functions[fill] = function(fill, shapes(os.path.join(phosphor, "raw", "fill", icon + "-fill.svg"), flip))
        cases.append("        case %s: filled ? %s(&g) : %s(&g)" % (", ".join('"%s"' % n for n in names), fill, outline))

    with open(OUTPUT, "w") as file:
        file.write("""//
//  SymbolGlyphs.swift
//  Cacao
//
//  Generated by Scripts/GenerateSymbols.py from Scripts/SymbolNames.txt and
//  Phosphor Icons%s. Don't edit: change those and run it again.
//
//  The drawings are Phosphor Icons', copyright (c) 2023 Phosphor Icons,
//  under the MIT License: see ThirdPartyLicenses.md.
//

// swiftformat:disable all
// swiftlint:disable all

extension Symbols {

    /// The number of symbol names drawn from Phosphor Icons, not counting
    /// their `.fill` variants.
    static let glyphNameCount = %d

    /// The Phosphor drawing of a symbol, outlined or filled, or nil for a
    /// name without one.
    static func glyph(_ name: String, filled: Bool) -> [Part]? {
        var g = Glyph()
        switch name {
%s
        default: return nil
        }
        return g.parts
    }

%s
}
""" % (" (%s)" % commit if commit else "", len(seen), "\n".join(cases), "\n\n".join(functions.values())))
    print("%d names, %d drawings" % (len(seen), len(functions)))


if __name__ == "__main__":
    main()
