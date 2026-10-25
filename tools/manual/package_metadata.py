"""Read the current package version shared by manual build and verification."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
_description = (ROOT / "DESCRIPTION").read_text(encoding="utf-8")
_match = re.search(r"^Version:\s*([0-9]+(?:\.[0-9]+)+)\s*$", _description, re.MULTILINE)
if _match is None:
    raise ValueError("DESCRIPTION must provide a valid package version")
VERSION = _match.group(1)
