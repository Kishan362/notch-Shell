#!/usr/bin/python3
"""
set_config.py: set one key in the user's config.jsonc.

Unlike config_update.py, which round-trips the whole file through json and so
drops comments, this edits the single value in place. Formatting and any
hand-written comments are left alone. Config.qml watches the file, so the
shell picks the change up live.

    set_config.py <key> <value> [<key> <value> ...]

Several pairs may be given at once; they are applied in order and written in a
single atomic replace, so a multi-key change can never land half-applied.

The new value is coerced to the type the key already has (number, bool or
string), so "pillScale 1.25" stays a number rather than becoming a string.
Unknown keys are written as strings.
"""
import json
import os
import re
import sys
import tempfile

CONFIG = os.path.expanduser("~/.config/notch-shell/config.jsonc")

def find_key_re(key: str) -> re.Pattern:
    return re.compile(
        r'("%s"\s*:\s*)("(?:[^"\\]|\\.)*"|true|false|-?\d+(?:\.\d+)?)'
        % re.escape(key),
        re.IGNORECASE,
    )


def coerce(value: str, current: str | None) -> str:
    """Render `value` as JSON, matching the type already in the file."""
    if current is not None:
        if current in ("true", "false"):
            low = value.strip().lower()
            if low in ("true", "false"):
                return low
        elif re.fullmatch(r"-?\d+", current):
            if re.fullmatch(r"-?\d+", value.strip()):
                return value.strip()
        elif re.fullmatch(r"-?\d+\.\d+", current):
            try:
                float(value)
                return value.strip()
            except ValueError:
                pass
        elif current.startswith('"'):
            return json.dumps(value)
    # unknown key: infer a sane type, default to string
    low = value.strip().lower()
    if low in ("true", "false"):
        return low
    if re.fullmatch(r"-?\d+(\.\d+)?", value.strip()):
        return value.strip()
    return json.dumps(value)


def apply_one(text: str, key: str, value: str) -> str:
    rx = find_key_re(key)
    m = rx.search(text)
    if m:
        return rx.sub(lambda mm: mm.group(1) + coerce(value, m.group(2)), text, count=1)
    idx = text.find("{")
    if idx == -1:
        raise ValueError("config does not look like a JSON object")
    return text[: idx + 1] + f"\n  {json.dumps(key)}: {coerce(value, None)}," + text[idx + 1 :]


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2 or len(args) % 2 != 0:
        print("usage: set_config.py <key> <value> [<key> <value> ...]", file=sys.stderr)
        return 2

    pairs = list(zip(args[0::2], args[1::2]))
    for key, _ in pairs:
        if not re.fullmatch(r"[A-Za-z0-9_]+", key):
            print(f"invalid key: {key!r}", file=sys.stderr)
            return 2
    for _, value in pairs:
        if "\n" in value or "\r" in value:
            print("values must be single-line", file=sys.stderr)
            return 2

    if not os.path.isfile(CONFIG):
        print(f"config not found: {CONFIG}", file=sys.stderr)
        return 1

    with open(CONFIG, "r", encoding="utf-8") as f:
        text = f.read()

    try:
        new = text
        for key, value in pairs:
            new = apply_one(new, key, value)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1

    if new == text:
        print("already set: " + ", ".join(f"{k}={v!r}" for k, v in pairs))
        return 0

    # write via a temp file in the same dir, then rename, so a crash mid-write
    # cannot leave a truncated config behind
    directory = os.path.dirname(CONFIG)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".config.jsonc.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new)
        os.chmod(tmp, os.stat(CONFIG).st_mode & 0o7777)
        os.replace(tmp, CONFIG)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise

    print("set: " + ", ".join(f"{k}={v!r}" for k, v in pairs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
