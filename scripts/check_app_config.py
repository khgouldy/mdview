#!/usr/bin/env python3
"""App configuration checks for the quality gate (stdlib only).

Prints `ok: <check>` per passing check, `error: ...` lines and exit 1 otherwise.
`--self-test` runs every check against a bad in-memory example and asserts it fails.
"""

import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_PREFIX = "us.par72.mdview"
TEAM_RE = re.compile(r"""^\s*["']?DEVELOPMENT_TEAM["']?\s*[:=]\s*(.*?)\s*$""")
BUNDLE_RE = re.compile(r"""^\s*PRODUCT_BUNDLE_IDENTIFIER\s*:\s*["']?([^"'\s#]+)["']?""")


def check_no_team_id(files):
    """(a) No tracked file sets DEVELOPMENT_TEAM to a non-empty value. files: {path: text}."""
    errors = []
    for path, text in files.items():
        for number, line in enumerate(text.splitlines(), 1):
            match = TEAM_RE.match(line)
            if not match:
                continue
            value = match.group(1).split("#", 1)[0].strip().strip("\"'").strip()
            if value and value != "$(inherited)":
                errors.append(f"{path}:{number}: DEVELOPMENT_TEAM is set to a non-empty value")
    return errors


def check_bundle_ids(project_yml):
    """(b) Every PRODUCT_BUNDLE_IDENTIFIER is us.par72.mdview or a child of it."""
    errors = []
    for number, line in enumerate(project_yml.splitlines(), 1):
        match = BUNDLE_RE.match(line)
        if not match:
            continue
        value = match.group(1)
        if value != BUNDLE_PREFIX and not value.startswith(BUNDLE_PREFIX + "."):
            errors.append(f"project.yml:{number}: bundle id {value} is not under {BUNDLE_PREFIX}")
    return errors


def check_privacy_manifests(manifests):
    """(c) Privacy manifests say no tracking and no collected data. manifests: {path: bytes}."""
    errors = []
    for path, data in manifests.items():
        try:
            plist = plistlib.loads(data)
        except Exception as exc:
            errors.append(f"{path}: unreadable plist ({exc})")
            continue
        if plist.get("NSPrivacyTracking") is not False:
            errors.append(f"{path}: NSPrivacyTracking must be false")
        if plist.get("NSPrivacyTrackingDomains") != []:
            errors.append(f"{path}: NSPrivacyTrackingDomains must be empty")
        if plist.get("NSPrivacyCollectedDataTypes") != []:
            errors.append(f"{path}: NSPrivacyCollectedDataTypes must be empty")
    return errors


def check_no_truepredicate(plists):
    """(d) No Info.plist contains TRUEPREDICATE. plists: {path: text}."""
    return [f"{path}: contains TRUEPREDICATE" for path, text in plists.items() if "TRUEPREDICATE" in text]


CHECKS = [
    ("no DEVELOPMENT_TEAM in tracked files", "team"),
    ("bundle ids under " + BUNDLE_PREFIX, "bundle"),
    ("privacy manifests: no tracking, no collected data", "privacy"),
    ("no TRUEPREDICATE in Info.plist", "predicate"),
]


def tracked_files():
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout
    return [p for p in out.split("\0") if p]


def read_text(path):
    try:
        return (ROOT / path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def run():
    tracked = tracked_files()
    team_files = {}
    for path in tracked:
        text = read_text(path)
        if text is not None:
            team_files[path] = text
    app = [p for p in tracked if p.startswith("App/")]
    manifests = {p: (ROOT / p).read_bytes() for p in app if p.endswith("PrivacyInfo.xcprivacy")}
    info_plists = {p: team_files.get(p, "") for p in app if p.endswith("Info.plist")}
    results = {
        "team": check_no_team_id(team_files),
        "bundle": check_bundle_ids(team_files.get("project.yml", "")),
        "privacy": check_privacy_manifests(manifests),
        "predicate": check_no_truepredicate(info_plists),
    }
    failed = False
    for label, key in CHECKS:
        if results[key]:
            failed = True
            for message in results[key]:
                print(f"error: {message}")
        else:
            print(f"ok: {label}")
    return 1 if failed else 0


def self_test():
    good_privacy = plistlib.dumps(
        {"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": []}
    )
    cases = [
        ("team", check_no_team_id, {"a.yml": "DEVELOPMENT_TEAM: ABCDE12345"}, {"a.yml": "DEVELOPMENT_TEAM: \"\""}),
        ("team xcconfig", check_no_team_id, {"a.xcconfig": "DEVELOPMENT_TEAM = ABCDE12345"}, {"a.xcconfig": "DEVELOPMENT_TEAM ="}),
        ("bundle", check_bundle_ids, "PRODUCT_BUNDLE_IDENTIFIER: com.example.app", "PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview.uitests"),
        ("bundle prefix", check_bundle_ids, "PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdviewer", "PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview"),
        (
            "tracking",
            check_privacy_manifests,
            {"p": plistlib.dumps({"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": []})},
            {"p": good_privacy},
        ),
        (
            "tracking domains",
            check_privacy_manifests,
            {"p": plistlib.dumps({"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": ["x.com"], "NSPrivacyCollectedDataTypes": []})},
            {"p": good_privacy},
        ),
        (
            "collected data",
            check_privacy_manifests,
            {"p": plistlib.dumps({"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [{}]})},
            {"p": good_privacy},
        ),
        ("missing keys", check_privacy_manifests, {"p": plistlib.dumps({})}, {"p": good_privacy}),
        ("truepredicate", check_no_truepredicate, {"Info.plist": "<string>TRUEPREDICATE</string>"}, {"Info.plist": "<dict/>"}),
    ]
    for name, check, bad, good in cases:
        assert check(bad), f"self-test: {name} did not fail on its bad example"
        assert not check(good), f"self-test: {name} failed on its good example: {check(good)}"
        print(f"ok: self-test {name}")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    return run()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
