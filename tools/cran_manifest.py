"""Bind completed CRAN-style checks to the exact local source archive."""
from pathlib import Path
import hashlib
import json
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]


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
    return fields


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
        else:
            assert source.read_bytes() == data, relative
        source_hashes.append(f"{sha(source)}  {relative.as_posix()}")

assert all(max(path.read_bytes(), default=0) < 128 for path in (ROOT / "R").glob("*.R"))
assert "beta" not in (ROOT / "README.md").read_text(encoding="utf-8").lower()

configurations = [
    ("Windows R-release", ".local/validation/rcodeagent.Rcheck", None),
    ("Linux R-release", ".local/cran-prep/linux-release/rcodeagent.Rcheck", ".local/cran-prep/linux-release"),
    ("Linux R-devel", ".local/cran-prep/linux-devel/check/rcodeagent.Rcheck", ".local/cran-prep/linux-devel"),
]
checks = []
for environment, directory, container_directory in configurations:
    directory = ROOT / directory
    log = directory / "00check.log"
    text = log.read_text(encoding="utf-8").replace("\u2018", "'").replace("\u2019", "'")
    assert "* DONE" in text and f"version '{version}'" in text, environment
    status = re.search(r"^Status: (.+)$", text, re.M)
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
        names = ("candidate-sha256.txt", "candidate-sha256-after.txt") if environment.endswith("release") else ("check-input-sha256.txt", "check-final-sha256.txt")
        for name in names:
            assert (container / name).read_text().split()[0].upper() == archive_hash
    else:
        assert archive_hash in (ROOT / ".local/cran-prep/reproducible-release.log").read_text(encoding="utf-8").upper()
    public = ROOT / "docs/validation" / ("cran-" + environment.lower().replace(" ", "-") + ".log")
    public.write_bytes(log.read_bytes())
    public_tests = public.with_name(public.stem + "-tests.log")
    public_tests.write_bytes(test_log.read_bytes())
    checks.append(dict(environment=environment, r_version=re.search(r"^\* using R (.+)$", text, re.M)[1],
                       command="R CMD check --as-cran", log=public.relative_to(ROOT).as_posix(),
                       log_sha256=sha(public), tests_passed=int(tests[4]),
                       tests_log=public_tests.relative_to(ROOT).as_posix(), tests_log_sha256=sha(public_tests), **counts))

report = dict(package="rcodeagent", version=version, verified_on="2026-10-25", archive=archive.relative_to(ROOT).as_posix(),
              archive_sha256=archive_hash, archive_bytes=archive.stat().st_size,
              archive_files=len(source_hashes), source_files_equal=len(source_hashes)-1,
              r_sources_ascii=True, checks=checks,
              limitations=["No CRAN submission or remote CI run", "Automated checks use synthetic service/editor fixtures; native IDE/provider lifecycle is separate"])
(ROOT / "docs/validation/cran-checks.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
(ROOT / "docs/validation/source-files.sha256").write_text("\n".join(sorted(source_hashes)) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
