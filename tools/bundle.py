"""Build and verify the public or private portable kit. Requires Python 3.11+."""
import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
from zipfile import BadZipFile, ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.2.1"
CORE = {"README.md", "MIGRATION.md", "PACKAGING.md", "skills/personal-workstyle/SKILL.md",
        "skills/personal-workstyle/agents/openai.yaml", "snapshots/windows.json",
        "tools/Export-PublicConfig.ps1", "tools/bundle.py"}
PROFILE = "skills/personal-workstyle/references/profile.md"
NATIVE = {"clion": "private/clion.zip", "pycharm": "private/pycharm.zip",
          "idea": "private/idea.zip", "vscode": "private/vscode.code-profile"}
MANIFEST = "MANIFEST.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def external(path):
    path = path.resolve(strict=True)
    if path.is_relative_to(ROOT):
        raise ValueError("Keep private input files outside the public source tree.")
    return path.read_bytes()


def verify(path):
    with ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate paths.")
        manifest = json.loads(archive.read(MANIFEST))
        members = set(names) - {MANIFEST}
        if manifest["format"] != 1 or manifest["version"] != VERSION:
            raise ValueError("Unsupported format or version.")
        if not CORE <= members or members != set(manifest["files"]):
            raise ValueError("Missing files or unlisted members.")
        extra = members - CORE
        if not extra <= ({PROFILE} | set(NATIVE.values())):
            raise ValueError("Unexpected file in bundle.")
        if manifest["edition"] != ("private" if extra else "public"):
            raise ValueError("Edition and contents disagree.")
        for name in members:
            if digest(archive.read(name)) != manifest["files"][name]:
                raise ValueError(f"Checksum mismatch: {name}")
    return manifest


def build(args):
    output = args.output.resolve()
    private = bool(args.profile or args.settings)
    if output.suffix.lower() != ".zip" or (private and output.is_relative_to(ROOT)):
        raise ValueError("Choose a ZIP destination. Keep private output outside the repository.")
    inputs = {name: (ROOT / name).read_bytes() for name in CORE}
    sources = set()
    if args.profile:
        inputs[PROFILE] = external(args.profile)
        inputs[PROFILE].decode("utf-8-sig")
        sources.add(args.profile.resolve())
    for spec in args.settings:
        tool, sep, value = spec.partition("=")
        if not sep or tool not in NATIVE or NATIVE[tool] in inputs:
            raise ValueError("Provide one TOOL=FILE per supported IDE.")
        source = Path(value)
        if source.suffix.lower() != Path(NATIVE[tool]).suffix:
            raise ValueError(f"Unexpected settings file type for {tool}.")
        inputs[NATIVE[tool]] = external(source)
        sources.add(source.resolve())
    if output in sources:
        raise ValueError("Output must differ from input files.")
    manifest = {"format": 1, "version": VERSION, "edition": "private" if private else "public",
                "files": {name: digest(data) for name, data in inputs.items()}}
    inputs[MANIFEST] = (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as tmp:
        temp = Path(tmp.name)
    try:
        with ZipFile(temp, "w") as archive:
            for name, data in sorted(inputs.items()):
                member = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                member.create_system = 3
                member.external_attr = 0o100644 << 16
                archive.writestr(member, data, compress_type=ZIP_DEFLATED)
        verify(temp)
        os.replace(temp, output)
    finally:
        temp.unlink(missing_ok=True)
    print(f"{digest(output.read_bytes())}  {output.name}")


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    subs = cli.add_subparsers(dest="action", required=True)
    builder = subs.add_parser("build")
    builder.add_argument("--output", required=True, type=Path)
    builder.add_argument("--profile", type=Path, help="Private UTF-8 Markdown profile")
    builder.add_argument("--settings", action="append", default=[], metavar="TOOL=FILE")
    checker = subs.add_parser("verify")
    checker.add_argument("archive", type=Path)
    args = cli.parse_args()
    if args.action == "build":
        build(args)
    else:
        m = verify(args.archive)
        print(f"OK {m['edition']} {m['version']}: {len(m['files'])} payload files")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, BadZipFile) as error:
        raise SystemExit(str(error))
