#!/usr/bin/env python3
"""Point wallust at notch-shell's theme template.

Two things need doing, both idempotent so re-running the installer is safe:

  * drop templates/notch-shell.json into ~/.config/wallust/templates/
  * register it in wallust.toml so `wallust run` writes the palette

The registration deliberately edits the existing [templates] table in place
rather than appending a new one. TOML forbids defining the same table twice,
so appending would turn a working config into a hard parse error for the user
the moment wallust next ran.
"""

import os
import shutil
import sys

HOME = os.path.expanduser("~")
WALLUST_DIR = os.path.join(HOME, ".config", "wallust")
TEMPLATE_DIR = os.path.join(WALLUST_DIR, "templates")
CONFIG = os.path.join(WALLUST_DIR, "wallust.toml")
OUT_DIR = os.path.join(HOME, ".config", "notch-shell")
OUT_FILE = os.path.join(OUT_DIR, "theme-wallust.json")

TEMPLATE_NAME = "notch-shell.json"
KEY = "notch_shell"


def repo_template() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(here), "templates", TEMPLATE_NAME)


def note(msg: str) -> None:
    print("  %s" % msg)


def copy_template() -> bool:
    # created here rather than in register(): this runs first, and the template
    # directory has to exist before the copy
    os.makedirs(TEMPLATE_DIR, exist_ok=True)
    src = repo_template()
    if not os.path.isfile(src):
        note("template missing from the package (%s), skipping" % src)
        return False
    dst = os.path.join(TEMPLATE_DIR, TEMPLATE_NAME)
    if os.path.isfile(dst):
        note("template already present, leaving it alone: %s" % dst)
        return True
    shutil.copyfile(src, dst)
    note("installed template: %s" % dst)
    return True


def entry_line() -> str:
    # an absolute path, written in single quotes so a Windows-style backslash
    # could never be read as a TOML escape
    return "%s = { template = '%s', target = '%s' }" % (KEY, TEMPLATE_NAME, OUT_FILE)


def register() -> bool:
    os.makedirs(TEMPLATE_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)

    if not os.path.isfile(CONFIG):
        with open(CONFIG, "w", encoding="utf-8") as fh:
            fh.write("# created by the notch-shell installer\n")
            fh.write("[templates]\n")
            fh.write(entry_line() + "\n")
        note("wrote a fresh wallust config: %s" % CONFIG)
        return True

    with open(CONFIG, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    # already registered?
    for line in lines:
        if line.strip().startswith(KEY + " ") or line.strip().startswith(KEY + "="):
            note("already registered in wallust.toml, leaving it alone")
            return True

    # find the [templates] table and insert as its first entry
    for i, line in enumerate(lines):
        if line.strip() == "[templates]":
            lines.insert(i + 1, entry_line())
            with open(CONFIG, "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines) + "\n")
            note("registered the template in the existing [templates] table")
            return True

    # no [templates] table at all: append one
    with open(CONFIG, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n\n[templates]\n" + entry_line() + "\n")
    note("appended a [templates] table to wallust.toml")
    return True


def main() -> int:
    # the installer runs as root; without this it would write the template into
    # /root/.config instead of the real user's
    if os.geteuid() == 0 and HOME == "/root":
        note("refusing to run as root with HOME=/root; re-run as your user")
        return 1
    if shutil.which("wallust") is None:
        note("wallust is not installed; skipping (the built-in sampler will be used)")
        return 0
    ok = copy_template() and register()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
