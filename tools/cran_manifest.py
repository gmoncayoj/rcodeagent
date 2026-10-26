"""Bind completed CRAN-style checks to the exact local source archive."""
from pathlib import Path
import argparse
from datetime import date
import hashlib
import json
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence-root', default='.local/cran-final-0.1.0')
parser.add_argument('--verified-on', default=date.today().isoformat())
args = parser.parse_args()
evidence = ROOT / args.evidence_root


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def dcf(text):
    fields = {}
    key = None
    for line in text.splitlines():
        if line[:1].isspace() and key:
            fields[key] += " " + line.strip()
        elif ":" in line:
            key, value = line.split(":", 1)
            fields[key] = value.strip()
    return {key: value.strip() for key, value in fields.items()}


metadata = dcf((ROOT / "DESCRIPTION").read_text(encoding="utf-8"))
version = metadata["Version"]
archive = ROOT / "dist" / f"rcodeagent_{version}.tar.gz"
archive_hash = sha(archive)
source_hashes = []
with tarfile.open(archive) as bundle:
    members = bundle.getmembers()
    for member in members:
        path = Path(member.name)
        assert path.parts[0] == "rcodeagent" and ".." not in path.parts and not path.is_absolute()
        assert not member.issym() and not member.islnk()
        if not member.isfile():
            continue
        relative = path.relative_to("rcodeagent")
        data = bundle.extractfile(member).read()
        source = ROOT / relative
        assert source.is_file(), relative
        if relative.as_posix() == "DESCRIPTION":
            built = dcf(data.decode("utf-8"))
            assert built["Version"] == version and built["License"] == "GPL (>= 3)"
            assert built["Author"] == "Jos\u00e9 Gamarra-Moncayo [aut, cre]"
            assert all(built.get(key) == value for key, value in metadata.items()), 'DESCRIPTION mismatch'
        else:
            assert source.read_bytes() == data, relative
        source_hashes.append(f"{sha(source)}  {relative.as_posix()}")

assert all(max(path.read_bytes(), default=0) < 128 for path in (ROOT / "R").glob("*.R"))
assert "beta" not in (ROOT / "README.md").read_text(encoding="utf-8").lower()

configurations = [
    ("Windows R-release", ".local/validation/rcodeagent.Rcheck", None),
    ("Linux R-release", evidence / "linux-release/check/rcodeagent.Rcheck", evidence / "linux-release"),
    ("Linux R-devel", evidence / "linux-devel/check/rcodeagent.Rcheck", evidence / "linux-devel"),
]
checks = []
copies = []
for environment, directory, container_directory in configurations:
    directory = ROOT / directory
    log = directory / "00check.log"
    text = log.read_text(encoding="utf-8").replace("\u2018", "'").replace("\u2019", "'")
    assert "* DONE" in text and f"version '{version}'" in text, environment
    assert "* using option '--as-cran'" in text, environment
    assert re.search(r'checking PDF version of manual .* OK', text), environment
    assert re.search(r'checking HTML version of manual .* OK', text), environment
    status = re.search(r"^Status: (.+)$", text, re.M)
    assert status, environment
    counts = {"errors": 0, "warnings": 0, "notes": 0}
    for number, kind in re.findall(r"(\d+)\s+(ERRORS?|WARNINGS?|NOTES?)", status[1] if status else "", re.I):
        counts[{"ERROR": "errors", "WARNING": "warnings", "NOTE": "notes"}[kind.upper().rstrip("S")]] = int(number)
    assert counts["errors"] == counts["warnings"] == 0 and counts["notes"] in (0, 1), (environment, counts)
    assert not counts["notes"] or "New submission" in text, environment
    test_log = directory / "tests/testthat.Rout"
    tests = re.search(r"\[ FAIL (\d+) \| WARN (\d+) \| SKIP (\d+) \| PASS (\d+) \]", test_log.read_text(encoding="utf-8"))
    assert tests and tuple(map(int, tests.groups()[:3])) == (0, 0, 0), environment
    if container_directory:
        container = ROOT / container_directory
        assert sha(container / archive.name) == archive_hash
        assert (container / 'check-exit.txt').read_text().strip() == '0'
        names = ("archive-before.sha256", "archive-after.sha256")
        for name in names:
            assert (container / name).read_text().split()[0].upper() == archive_hash
    else:
        assert (evidence / 'windows-check-exit.txt').read_text().strip() == '0'
        assert archive_hash in (evidence / 'windows-release.log').read_text(encoding="utf-8").upper()
    public = ROOT / "docs/validation" / ("cran-" + environment.lower().replace(" ", "-") + ".log")
    public_tests = public.with_name(public.stem + "-tests.log")
    copies.extend(((log, public), (test_log, public_tests)))
    checks.append(dict(environment=environment, r_version=re.search(r"^\* using R (.+)$", text, re.M)[1],
                       command="R CMD check --as-cran", log=public.relative_to(ROOT).as_posix(),
                       log_sha256=sha(log), tests_passed=int(tests[4]),
                       tests_log=public_tests.relative_to(ROOT).as_posix(), tests_log_sha256=sha(test_log), **counts))

report = dict(package="rcodeagent", version=version, verified_on=args.verified_on, archive=archive.relative_to(ROOT).as_posix(),
              archive_sha256=archive_hash, archive_bytes=archive.stat().st_size,
              archive_files=len(source_hashes), source_files_equal=len(source_hashes)-1,
              r_sources_ascii=True, checks=checks,
              limitations=["No CRAN submission; prior remote CI checked a different archive", "Automated checks use synthetic service/editor fixtures; native IDE/provider lifecycle is separate"])
for source, destination in copies:
    destination.write_bytes(source.read_bytes())
(ROOT / "docs/validation/cran-checks.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
(ROOT / "docs/validation/source-files.sha256").write_text("\n".join(sorted(source_hashes)) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
