#!/usr/bin/env python3
"""App configuration checks for the quality gate (stdlib only).

Prints `ok: <check>` per passing check, `error: ...` lines and exit 1 otherwise.
`--self-test` runs every check against a bad in-memory example and asserts it fails.
"""

import copy
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


DISPLAY_NAME_RE = re.compile(r"""^\s*APP_DISPLAY_NAME\s*:\s*["']?([^"'#\n]+?)["']?\s*(?:#.*)?$""", re.M)
APP_NAME_HEADING_RE = re.compile(r"^##\s+App name\s*\n+\s*\*\*(.+?)\*\*", re.M)


def check_display_name(project_yml, info_plist, listing):
    """(e) One display name: Info.plist reads $(APP_DISPLAY_NAME), project.yml defines it,
    and listing.md's App name starts with it."""
    errors = []
    if not re.search(r"<key>CFBundleDisplayName</key>\s*<string>\$\(APP_DISPLAY_NAME\)</string>", info_plist):
        errors.append("App/mdview/Info.plist: CFBundleDisplayName must be $(APP_DISPLAY_NAME)")
    match = DISPLAY_NAME_RE.search(project_yml)
    if not match:
        errors.append("project.yml: APP_DISPLAY_NAME is not defined")
        return errors
    name = match.group(1).strip()
    heading = APP_NAME_HEADING_RE.search(listing)
    if not heading:
        errors.append("docs/app-store/listing.md: no bold App name under the App name heading")
    elif not heading.group(1).startswith(name):
        errors.append(
            f"docs/app-store/listing.md: App name {heading.group(1)!r} does not start with APP_DISPLAY_NAME {name!r}"
        )
    return errors


SWIFT_TYPES_PATH = "Packages/MDCore/Sources/MDCore/MarkdownFileTypes.swift"
EXT_BLOCK_RE = re.compile(r"// BEGIN markdownExtensions\n(.*?)// END markdownExtensions", re.S)
EXPECTED_MIME = ["text/markdown", "text/x-markdown"]
EXPECTED_DOC_TYPES = {"net.daringfireball.markdown": "Default", "public.plain-text": "Alternate", "public.text": "Alternate"}


def check_markdown_types(plist_bytes, swift_text):
    """(f) Info.plist declares exactly the Swift extension list, both MIME types, three document
    types with the expected ranks, and the two Boolean keys; the UTI is imported, never exported."""
    errors = []
    block = EXT_BLOCK_RE.search(swift_text)
    if not block:
        return [f"{SWIFT_TYPES_PATH}: BEGIN/END markdownExtensions markers not found"]
    swift_exts = re.findall(r'"([^"]+)"', block.group(1))
    try:
        plist = plistlib.loads(plist_bytes)
    except Exception as exc:
        return [f"App/mdview/Info.plist: unreadable plist ({exc})"]
    if plist.get("UTExportedTypeDeclarations"):
        errors.append("App/mdview/Info.plist: must not export net.daringfireball.markdown")
    imported = [t for t in plist.get("UTImportedTypeDeclarations", []) if t.get("UTTypeIdentifier") == "net.daringfireball.markdown"]
    if not imported:
        errors.append("App/mdview/Info.plist: net.daringfireball.markdown is not imported")
    else:
        tags = imported[0].get("UTTypeTagSpecification", {})
        if sorted(tags.get("public.filename-extension", [])) != sorted(swift_exts):
            errors.append(f"App/mdview/Info.plist: extensions {tags.get('public.filename-extension')} differ from MarkdownFileTypes.swift {swift_exts}")
        if tags.get("public.mime-type") != EXPECTED_MIME:
            errors.append(f"App/mdview/Info.plist: public.mime-type must be {EXPECTED_MIME}")
    ranks = {}
    for doc in plist.get("CFBundleDocumentTypes", []):
        for uti in doc.get("LSItemContentTypes", []):
            ranks[uti] = doc.get("LSHandlerRank")
    if ranks != EXPECTED_DOC_TYPES:
        errors.append(f"App/mdview/Info.plist: document type ranks {ranks} must be {EXPECTED_DOC_TYPES}")
    for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"):
        if plist.get(key) is not True:
            errors.append(f"App/mdview/Info.plist: {key} must be true")
    return errors


def check_shared_extension_safe(files):
    """(g) Nothing under App/Shared uses UIApplication.shared; an app extension cannot call it.
    files: {path: text}."""
    errors = []
    for path, text in files.items():
        if not path.startswith("App/Shared/"):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if "UIApplication.shared" in line:
                errors.append(f"{path}:{number}: UIApplication.shared is not extension-safe")
    return errors


CHECKS = [
    ("no DEVELOPMENT_TEAM in tracked files", "team"),
    ("bundle ids under " + BUNDLE_PREFIX, "bundle"),
    ("privacy manifests: no tracking, no collected data", "privacy"),
    ("no TRUEPREDICATE in Info.plist", "predicate"),
    ("display name: Info.plist, project.yml and listing.md agree", "display"),
    ("markdown types: Info.plist matches MarkdownFileTypes.swift", "types"),
    ("App/Shared is extension-safe: no UIApplication.shared", "shared"),
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
        "display": check_display_name(
            team_files.get("project.yml", ""),
            team_files.get("App/mdview/Info.plist", ""),
            team_files.get("docs/app-store/listing.md", ""),
        ),
        "types": check_markdown_types(
            (ROOT / "App/mdview/Info.plist").read_bytes(), read_text(SWIFT_TYPES_PATH) or ""
        ),
        "shared": check_shared_extension_safe(
            {p: text for p in tracked if p.startswith("App/Shared/") and (text := read_text(p)) is not None}
        ),
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
        (
            "shared UIApplication",
            check_shared_extension_safe,
            {"App/Shared/A.swift": "UIApplication.shared.open(u)"},
            {"App/Shared/A.swift": "let x = 1", "App/mdview/B.swift": "UIApplication.shared"},
        ),
        ("truepredicate", check_no_truepredicate, {"Info.plist": "<string>TRUEPREDICATE</string>"}, {"Info.plist": "<dict/>"}),
    ]
    plist_ok = "<key>CFBundleDisplayName</key>\n\t<string>$(APP_DISPLAY_NAME)</string>"
    plist_bad = "<key>CFBundleDisplayName</key>\n\t<string>mdview</string>"
    yml = "settings:\n  base:\n    APP_DISPLAY_NAME: MdV\n"
    listing = "## App name\n\n**MdV: Markdown Viewer** (20/30)\n"
    swift_ok = '// BEGIN markdownExtensions\nlet x = ["md", "mdx"]\n// END markdownExtensions\n'
    plist_good = {
        "UIFileSharingEnabled": True,
        "LSSupportsOpeningDocumentsInPlace": True,
        "CFBundleDocumentTypes": [
            {"LSItemContentTypes": [u], "LSHandlerRank": r} for u, r in EXPECTED_DOC_TYPES.items()
        ],
        "UTImportedTypeDeclarations": [
            {
                "UTTypeIdentifier": "net.daringfireball.markdown",
                "UTTypeTagSpecification": {"public.filename-extension": ["md", "mdx"], "public.mime-type": EXPECTED_MIME},
            }
        ],
    }
    for name, mutate in [
        ("types extension", lambda p: p["UTImportedTypeDeclarations"][0]["UTTypeTagSpecification"].update({"public.filename-extension": ["md"]})),
        ("types mime", lambda p: p["UTImportedTypeDeclarations"][0]["UTTypeTagSpecification"].update({"public.mime-type": ["text/markdown"]})),
        ("types rank", lambda p: p["CFBundleDocumentTypes"][0].update({"LSHandlerRank": "Owner"})),
        ("types missing doc type", lambda p: p["CFBundleDocumentTypes"].pop()),
        ("types file sharing", lambda p: p.update({"UIFileSharingEnabled": False})),
        ("types in place", lambda p: p.pop("LSSupportsOpeningDocumentsInPlace")),
        ("types exported", lambda p: p.update({"UTExportedTypeDeclarations": [{}]})),
    ]:
        bad = copy.deepcopy(plist_good)
        mutate(bad)
        assert check_markdown_types(plistlib.dumps(bad), swift_ok), f"self-test: {name} did not fail on its bad example"
        print(f"ok: self-test {name}")
    assert not check_markdown_types(plistlib.dumps(plist_good), swift_ok), "self-test: types failed on its good example"
    assert check_markdown_types(plistlib.dumps(plist_good), "no markers"), "self-test: types markers did not fail"
    print("ok: self-test types good")
    for name, bad, good in [
        ("display plist", (yml, plist_bad, listing), (yml, plist_ok, listing)),
        ("display undefined", ("settings:\n", plist_ok, listing), (yml, plist_ok, listing)),
        ("display listing", (yml, plist_ok, "## App name\n\n**mdview** (6/30)\n"), (yml, plist_ok, listing)),
    ]:
        assert check_display_name(*bad), f"self-test: {name} did not fail on its bad example"
        assert not check_display_name(*good), f"self-test: {name} failed on its good example"
        print(f"ok: self-test {name}")
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
