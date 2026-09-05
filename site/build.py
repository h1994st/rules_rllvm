#!/usr/bin/env python3
"""Generate the site's index page from README.md.

The README is the single source of truth. Nothing generated here is committed,
so the published page cannot drift from the repository's front page.

Four things change on the way:

* The `# rules_rllvm` heading is repository chrome. The page has a designed
  header instead.
* The tagline and the paragraph under it move into front matter, so the layout
  can set them in the hero rather than repeating them in the body. Any further
  introduction stays in the body: dropping it would lose text that appears
  nowhere else on the page.
* Relative links work on github.com and 404 on the site, which has no
  `examples/` or `LICENSE` to serve.
* The version is read from the release-please manifest, so neither the header
  nor the `bazel_dep` line in the hero can claim a release that was never cut.
  That file is release-please's own record of what it last published, which
  makes it the thing a reader of the page is actually asking about. MODULE.bazel
  carries the same number, but it also carries every dependency, so reading it
  here would rebuild the site on version bumps that change nothing on the
  page.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = "h1994st/rules_rllvm"
BRANCH = "main"

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
MANIFEST = ROOT / ".release-please-manifest.json"
OUTPUT = Path(__file__).resolve().parent / "index.md"

# `[text](target)`, capturing the target. Bare enough to miss exotic markdown,
# which is why an unrewritten relative link fails the build rather than ships.
LINK = re.compile(r"(?<=\]\()([^)\s]+)(?=[)\s])")

ABSOLUTE = ("http://", "https://", "#", "mailto:", "//")


def rewrite(target: str) -> str:
    """Point a repository-relative link back at GitHub."""
    if target.startswith(ABSOLUTE):
        return target
    # A trailing slash means a directory, which GitHub serves under `tree`.
    kind = "tree" if target.endswith("/") else "blob"
    return f"https://github.com/{REPO}/{kind}/{BRANCH}/{target.lstrip('./')}"


def released_version() -> str:
    """Read the released version from the release-please manifest.

    The key is the package path, which is the repository root because
    `release-please-config.json` declares a single package at `.`.
    """
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise SystemExit(f"cannot read {MANIFEST.name}: {exc}")

    version = manifest.get(".")
    if not version:
        raise SystemExit(f"no '.' entry in {MANIFEST.name}")
    return version


def split_front(markdown: str) -> tuple[str, str, str, str]:
    """Peel the title, tagline and lead paragraph off the top of the README."""
    lines = markdown.splitlines()

    title = "rules_rllvm"
    if lines and lines[0].startswith("# "):
        title = lines[0][2:].strip()
        lines = lines[1:]

    # Everything above the first `##` is the introduction the hero replaces.
    body_start = next(
        (i for i, line in enumerate(lines) if line.startswith("## ")), len(lines)
    )
    intro, body = lines[:body_start], lines[body_start:]

    blocks = [b for b in "\n".join(intro).split("\n\n") if b.strip()]

    # The hero sets these two itself; anything after them is ordinary prose and
    # is put back at the top of the body rather than dropped.
    tagline = " ".join(blocks[0].split()) if blocks else ""
    lead = " ".join(blocks[1].split()) if len(blocks) > 1 else ""
    rest = "\n\n".join(block.strip() for block in blocks[2:])

    body = "\n".join(body).strip()
    if rest:
        body = f"{rest}\n\n{body}".strip()
    return title, tagline, lead, body


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> int:
    title, tagline, lead, body = split_front(README.read_text(encoding="utf-8"))
    if not tagline:
        print("README has no tagline paragraph under the title", file=sys.stderr)
        return 1

    body = LINK.sub(lambda match: rewrite(match.group(0)), body)
    leftover = [t for t in LINK.findall(body) if not t.startswith(ABSOLUTE)]
    if leftover:
        print(f"unrewritten relative links: {leftover}", file=sys.stderr)
        return 1

    front = "\n".join(
        [
            "---",
            "layout: default",
            f"title: {yaml_quote(title)}",
            f"tagline: {yaml_quote(tagline)}",
            f"lead: {yaml_quote(lead)}",
            f"version: {yaml_quote(released_version())}",
            "---",
            "",
        ]
    )

    OUTPUT.write_text(f"{front}\n{body}\n", encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)} from README.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
