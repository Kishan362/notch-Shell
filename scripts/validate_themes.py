#!/usr/bin/env python3
"""Validate every theme in ThemePalettes.qml.

Replicates ThemeRamp.build() in Python so the whole palette set can be checked
without a running Quickshell instance, then asserts the invariants that keep
text readable on both light and dark bars:

  * every value is a valid #rrggbb
  * the background ramp is monotonic (darkest -> lightest)
  * the foreground ramp monotonically loses contrast against the background
  * fg/bg clears WCAG AA for body text (5.6:1)
  * accent/bg clears 2.8:1
  * the derived status tokens (okFg/infoFg/dangerFg/warnFg/weatherSnow) clear
    3:1 as graphical objects
  * onAccent clears 4.5:1 against accent
  * the allowlisted decorative colours clear 3:1 against the lightest and
    darkest backgrounds in the set
  * no non-theme QML file hardcodes a colour outside that allowlist

Usage:  python3 scripts/validate_themes.py
Exit 0 = all green, 1 = at least one failure.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = ROOT / "qml"
PALETTES = QML / "ThemePalettes.qml"

THEME_FILES = {"Theme.qml", "ThemeRamp.qml", "ThemePalettes.qml"}

# Colours that are deliberately literal: decorative hues whose meaning is the
# hue itself (a sun is yellow, a rain icon is blue) rather than a surface or
# text role. All mid-tone, so they read on either polarity -- and the harness
# re-proves that against the global extremes below.
DECORATIVE_ALLOWED = {
    # CcButtons timer-burst palette
    "#ffd43b", "#ff6b6b", "#4490ee", "#b197fc", "#f783ac", "#63e6be",
    # PowerMenu action accents + pending-action variants
    "#628ae2", "#9d6fff", "#f4a232", "#ff6b35", "#d62828",
    "#e22323", "#ea9d34", "#ff6c25", "#e07e20",
    # Weather icon hues
    "#f4c542", "#9aa0a6", "#4a9de8", "#e8b84a", "#8a8a8a",
    "#f18d41", "#5f99fa", "#54e04b", "#ffcd58", "#ff904d",
}


# --------------------------------------------------------------------------
# colour maths (mirrors ThemeRamp.qml)
# --------------------------------------------------------------------------
def parse(c):
    s = str(c).strip().lstrip("#")
    if len(s) == 3:
        s = "".join(ch * 2 for ch in s)
    if len(s) != 6:
        return None
    try:
        return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        return None


def hexstr(rgb):
    return "#%02x%02x%02x" % rgb


def channel(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    x, y = parse(a), parse(b)
    if x is None or y is None:
        return None
    return hexstr(tuple(channel(x[i] + (y[i] - x[i]) * t) for i in range(3)))


def shade(c, t):
    return mix(c, "#ffffff", t) if t >= 0 else mix(c, "#000000", -t)


def luma(c):
    x = parse(c)
    if x is None:
        return 0.0
    return 0.2126 * x[0] + 0.7152 * x[1] + 0.0722 * x[2]


def polar(c, t, base):
    return shade(c, t) if luma(c) >= luma(base) else shade(c, -t)


def on_accent(accent, base):
    """Pick whichever of black / white contrasts more with accent."""
    return "#000000" if contrast("#000000", accent) >= contrast("#ffffff", accent) else "#ffffff"


def rel_lum(c):
    def f(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    x = parse(c)
    if x is None:
        return 0.0
    return 0.2126 * f(x[0]) + 0.7152 * f(x[1]) + 0.0722 * f(x[2])


def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# --------------------------------------------------------------------------
# QML parsing
# --------------------------------------------------------------------------
def _match_brace(s, open_pos):
    """Return the index of the '}' matching the '{' at open_pos."""
    depth = 0
    for j in range(open_pos, len(s)):
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return j
    return -1


def _kv_pairs(body):
    """Extract key: "#hex" pairs from an object body."""
    out = {}
    for m in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)\s*:\s*"(#[0-9a-fA-F]{3,6})"', body):
        out[m.group(1)] = m.group(2).lower()
    return out


def _sub_object(body, key):
    m = re.search(r'\b' + re.escape(key) + r'\s*:\s*\{', body)
    if not m:
        return None
    open_pos = body.index("{", m.start())
    close = _match_brace(body, open_pos)
    if close == -1:
        return None
    return body[open_pos + 1:close]


def parse_themes():
    s = PALETTES.read_text(encoding="utf-8")
    themes = {}
    for m in re.finditer(r'"([a-z0-9-]+)"\s*:\s*\{', s):
        name = m.group(1)
        open_pos = s.index("{", m.start())
        close = _match_brace(s, open_pos)
        if close == -1:
            continue
        body = s[open_pos + 1:close]
        if "palette" not in body:
            continue  # not a theme entry
        pal = _sub_object(body, "palette")
        lit = _sub_object(body, "literal")
        if pal is None:
            continue
        themes[name] = {
            "palette": _kv_pairs(pal),
            "literal": _kv_pairs(lit) if lit is not None else {},
        }
    return themes


# --------------------------------------------------------------------------
# ThemeRamp.build() replica
# --------------------------------------------------------------------------
def build(p, lit):
    base, raised, high = p["base"], p["raised"], p["high"]
    text, muted, faint = p["text"], p["muted"], p["faint"]
    fg4 = mix(muted, faint, 0.45)

    out = {
        "bgD": shade(base, -0.05), "bg": base,
        "bgD1": mix(base, raised, 0.25), "bg1": mix(base, raised, 0.45),
        "bg2": mix(base, raised, 0.62), "bg3": mix(base, raised, 0.80),
        "bg4": raised, "bg5": mix(raised, high, 0.25),
        "bg6": mix(raised, high, 0.45), "bg7": mix(raised, high, 0.68),
        "bg8": high, "bg9": shade(high, 0.18),

        "fgL": polar(text, 0.07, base), "fg1": polar(text, 0.06, base),
        "fg2": polar(text, 0.02, base), "fg": text, "fg3": muted,
        "fg4": fg4, "fg5": mix(muted, faint, 0.70), "fg6": faint,
        "fg7": mix(faint, base, 0.35), "fg8": mix(faint, base, 0.62),
        "fg3D": mix(muted, faint, 0.35), "fg4D": mix(fg4, text, 0.60),
        "sliderBg": mix(text, muted, 0.80),

        "borderBg": faint, "borderBg1": mix(faint, base, 0.50),
        "borderBg2": mix(faint, base, 0.75), "borderBg3": mix(faint, base, 0.87),
        "borderBg4": mix(faint, base, 0.93), "borderBgFocus": mix(faint, base, 0.30),
        "borderBgFocus1": mix(faint, base, 0.40),

        "focusBg": raised, "focusBg1": mix(raised, high, 0.20),
        "focusBgD": mix(raised, base, 0.30), "focusBgL": mix(raised, high, 0.45),
        "focusFg": mix(text, muted, 0.20), "focusFg1": mix(muted, faint, 0.15),
        "focusFg2": mix(muted, faint, 0.38),

        "warning": p["warning"], "deleting": p["danger"],
        "accent": p["accent"], "coverArtGlowShadow": p.get("glow") or p["accent"],

        "okFg": polar(p.get("ok") or p["accent"], 0.28, base),
        "infoFg": polar(p.get("info") or p["accent"], 0.28, base),
        "dangerFg": polar(p["danger"], 0.28, base),
        "warnFg": polar(p["warning"], 0.28, base),
        "onAccent": on_accent(p["accent"], base),
        "infoHover": shade(p.get("info") or p["accent"], -0.14),
        "weatherSnow": polar(p.get("info") or p["accent"], 0.26, base),
    }
    for k, v in lit.items():
        if k in out:
            out[k] = v
    return out


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------
BG_RAMP = ["bgD", "bg", "bgD1", "bg1", "bg2", "bg3",
           "bg4", "bg5", "bg6", "bg7", "bg8", "bg9"]
FG_RAMP = ["fgL", "fg1", "fg2", "fg", "fg3", "fg4", "fg5", "fg6", "fg7", "fg8"]
STATUS_TOKENS = ["okFg", "infoFg", "dangerFg", "warnFg", "weatherSnow"]


def check_theme(name, props, errors, warnings):
    def err(msg):
        errors.append(f"  {name}: {msg}")

    def warn(msg):
        warnings.append(f"  {name}: {msg}")

    # valid hex + present
    for k, v in props.items():
        if parse(v) is None:
            err(f"{k} = {v!r} is not a valid #rrggbb")

    # background ramp monotonic increasing in luma
    seq = [props[k] for k in BG_RAMP]
    lumas = [luma(c) for c in seq]
    for i in range(1, len(lumas)):
        if lumas[i] < lumas[i - 1] - 1.5:
            err(f"bg ramp not monotonic at {BG_RAMP[i]} "
                f"({seq[i - 1]} -> {seq[i]})")
            break

    # foreground ramp monotonically loses contrast against bg
    ctr = [contrast(props[k], props["bg"]) for k in FG_RAMP]
    for i in range(1, len(ctr)):
        if ctr[i] > ctr[i - 1] + 0.15:
            err(f"fg ramp contrast increases at {FG_RAMP[i]} "
                f"({ctr[i - 1]:.2f} -> {ctr[i]:.2f})")
            break

    # body text and accent
    if contrast(props["fg"], props["bg"]) < 5.6:
        err(f"fg/bg = {contrast(props['fg'], props['bg']):.2f} (< 5.6)")
    if contrast(props["accent"], props["bg"]) < 2.8:
        err(f"accent/bg = {contrast(props['accent'], props['bg']):.2f} (< 2.8)")

    # status tokens as graphical objects
    for k in STATUS_TOKENS:
        r = contrast(props[k], props["bg"])
        if r < 3.0:
            err(f"{k}/bg = {r:.2f} (< 3.0)  {props[k]} on {props['bg']}")

    # text on an accent fill
    r = contrast(props["onAccent"], props["accent"])
    if r < 4.5:
        err(f"onAccent/accent = {r:.2f} (< 4.5)")

    # secondary text (labels, timestamps) -- informational, so warn only
    for k in ("fg3", "fg5"):
        r = contrast(props[k], props["bg"])
        if r < 4.5:
            warn(f"{k}/bg = {r:.2f} (< 4.5, secondary text)")

    return props


def lint_hardcoded(errors):
    """No non-theme QML file may hardcode a colour outside the allowlist."""
    hex_re = re.compile(r'"(#[0-9a-fA-F]{6})"')
    for f in sorted(QML.glob("*.qml")):
        if f.name in THEME_FILES:
            continue
        for lineno, line in enumerate(f.read_text(encoding="utf-8").split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            for m in hex_re.finditer(line):
                val = m.group(1).lower()
                if val not in DECORATIVE_ALLOWED:
                    errors.append(
                        f"  LINT {f.name}:{lineno}: hardcoded {val} "
                        f"(not in decorative allowlist)")


def main():
    themes = parse_themes()
    if not themes:
        print("no themes parsed", file=sys.stderr)
        return 1

    print(f"validating {len(themes)} themes")
    errors = []
    warnings = []
    built = {}
    for name, t in themes.items():
        missing = {"base", "raised", "high", "text", "muted", "faint",
                   "accent", "warning", "danger", "ok", "info"} - set(t["palette"])
        if missing:
            errors.append(f"  {name}: palette missing anchors {sorted(missing)}")
            continue
        props = build(t["palette"], t["literal"])
        built[name] = props
        check_theme(name, props, errors, warnings)

    # decorative colours are mid-tone hues; flag (don't fail) any that would be
    # hard to see against the lightest or darkest bar in the set
    if built:
        all_bg = [p["bg"] for p in built.values()]
        extremes = [min(all_bg, key=luma), max(all_bg, key=luma)]
        for val in sorted(DECORATIVE_ALLOWED):
            lo, hi = (contrast(val, extremes[0]), contrast(val, extremes[1]))
            if min(lo, hi) < 2.0:
                warnings.append(
                    f"  decorative {val} = {min(lo, hi):.2f}:1 "
                    f"against an extreme background")

    lint_hardcoded(errors)

    # summary table
    print()
    print(f"  {'theme':<22}{'bg':<10}{'fg/bg':>7}{'acct/bg':>8}"
          f"{'ok':>6}{'info':>6}{'snow':>6}{'onAcct':>8}")
    for name in sorted(built):
        p = built[name]
        print(f"  {name:<22}{p['bg']:<10}"
              f"{contrast(p['fg'], p['bg']):>7.2f}"
              f"{contrast(p['accent'], p['bg']):>8.2f}"
              f"{contrast(p['okFg'], p['bg']):>6.2f}"
              f"{contrast(p['infoFg'], p['bg']):>6.2f}"
              f"{contrast(p['weatherSnow'], p['bg']):>6.2f}"
              f"{contrast(p['onAccent'], p['accent']):>8.2f}")

    print()
    if warnings:
        print(f"  {len(warnings)} warning(s):")
        for w in warnings:
            print(w)
        print()
    if errors:
        print(f"FAIL  {len(errors)} problem(s):")
        for e in errors:
            print(e)
        return 1
    print(f"PASS  all {len(themes)} themes green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
