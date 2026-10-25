"""Check final PDF text bounds, page counts and integrity; requires pdfplumber."""
from pathlib import Path
import hashlib
import json
import pdfplumber
from package_metadata import ROOT, VERSION

root = ROOT
results = []
for language in ("ES", "EN"):
    path = root / "docs/manual" / f"rcodeagent-{VERSION}-Manual-{language}.pdf"
    assert path.is_file(), path
    with pdfplumber.open(path) as document:
        outside = sum(1 for page in document.pages for word in page.extract_words()
            if word["x0"] < 45 or word["x1"] > page.width - 45 or word["top"] < 12 or word["bottom"] > page.height - 20)
        bad_chars = sum(page.extract_text().count("\ufffd") for page in document.pages)
        assert 9 <= len(document.pages) <= 12 and outside == 0 and bad_chars == 0, path
        assert all(f"rcodeagent {VERSION}" in page.extract_text() for page in document.pages)
        assert all(f"José Gamarra-Moncayo | {VERSION}" in page.extract_text() for page in document.pages)
        expected_title = f"rcodeagent {VERSION} - {'Manual de uso' if language == 'ES' else 'User manual'}"
        assert document.metadata.get("Title") == expected_title, path
        assert document.metadata.get("Author") == "José Gamarra-Moncayo", path
        results.append(dict(file=path.name, pages=len(document.pages), out_of_bounds=outside,
            replacement_chars=bad_chars, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
assert len(results) == 2
report = root / "docs/validation/manuals.json"
report.write_text(json.dumps(results, indent=2), encoding="utf-8")
print(json.dumps(results, indent=2))
