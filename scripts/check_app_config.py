#!/usr/bin/env python3
"""App configuration checks for the quality gate (stdlib only).

Prints `ok: <check>` per passing check, `error: ...` lines and exit 1 otherwise.
`--self-test` runs every check against a bad in-memory example and asserts it fails.
"""

import copy
import json
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
    """(d) No plist under App/ (Info.plist, Info-Debug.plist) contains TRUEPREDICATE. plists: {path: text}."""
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


SHARE_DIR = "App/mdviewShare"
SHARE_BUNDLE_ID = BUNDLE_PREFIX + ".share"
SHARE_POINT = "com.apple.share-services"
SHARE_PRINCIPAL = "$(PRODUCT_MODULE_NAME).ShareViewController"
SHARE_DATA_CLAUSE = ' OR ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.data"'
SHARE_BANNED = [
    (re.compile(r"UIApplication\.shared"), "UIApplication.shared is unavailable in an app extension"),
    (re.compile(r"URLSession"), "URLSession: the extension stays on-device"),
    (re.compile(r"extensionContext\s*[?!]?\s*\.open\b"), "extensionContext.open: a Share extension cannot open the app (K7)"),
]


def target_block(project_yml, name):
    """The lines under `  <name>:` in project.yml's targets, or None."""
    lines = project_yml.splitlines()
    for start, line in enumerate(lines):
        if re.match(rf"^  {re.escape(name)}:\s*$", line):
            block = []
            for body in lines[start + 1 :]:
                if body.strip() and not body.startswith("   ") and not body.lstrip().startswith("#"):
                    break
                block.append(body)
            return "\n".join(block)
    return None


def yml_setting(block, key):
    match = re.search(rf"""^\s*{re.escape(key)}\s*:\s*["']?([^"'\s#]+)["']?""", block or "", re.M)
    return match.group(1) if match else None


def activation_rule(plist):
    return plist.get("NSExtension", {}).get("NSExtensionAttributes", {}).get("NSExtensionActivationRule")


def check_share_extension(release_bytes, debug_bytes, project_yml, swift_files, privacy_present):
    """(h) The Share extension: point id, principal class, display name, the Release rule (SUBQUERY on
    public.text / public.file-url, no public.data, no TRUEPREDICATE), a Debug plist that differs only by
    adding public.data, its own privacy manifest, the target settings and embed in project.yml, and no
    UIApplication.shared / URLSession / extensionContext.open in its Swift. swift_files: {path: text}."""
    errors = []
    plists = {}
    for name, data in (("Info.plist", release_bytes), ("Info-Debug.plist", debug_bytes)):
        try:
            plists[name] = plistlib.loads(data)
        except Exception as exc:
            errors.append(f"{SHARE_DIR}/{name}: unreadable plist ({exc})")
    if len(plists) == 2:
        release, debug = plists["Info.plist"], plists["Info-Debug.plist"]
        extension = release.get("NSExtension", {})
        if extension.get("NSExtensionPointIdentifier") != SHARE_POINT:
            errors.append(f"{SHARE_DIR}/Info.plist: NSExtensionPointIdentifier must be {SHARE_POINT}")
        if extension.get("NSExtensionPrincipalClass") != SHARE_PRINCIPAL:
            errors.append(f"{SHARE_DIR}/Info.plist: NSExtensionPrincipalClass must be {SHARE_PRINCIPAL}")
        if release.get("CFBundleDisplayName") != "$(APP_DISPLAY_NAME)":
            errors.append(f"{SHARE_DIR}/Info.plist: CFBundleDisplayName must be $(APP_DISPLAY_NAME)")
        rule = activation_rule(release)
        debug_rule = activation_rule(debug)
        if not isinstance(rule, str):
            errors.append(f"{SHARE_DIR}/Info.plist: NSExtensionActivationRule must be a predicate string")
            rule = ""
        if not isinstance(debug_rule, str):
            errors.append(f"{SHARE_DIR}/Info-Debug.plist: NSExtensionActivationRule must be a predicate string")
            debug_rule = ""
        if "TRUEPREDICATE" in rule or "TRUEPREDICATE" in debug_rule:
            errors.append(f"{SHARE_DIR}: an activation rule contains TRUEPREDICATE")
        if not rule.startswith("SUBQUERY("):
            errors.append(f"{SHARE_DIR}/Info.plist: the activation rule must be a SUBQUERY")
        for uti in ('"public.text"', '"public.file-url"'):
            if uti not in rule:
                errors.append(f"{SHARE_DIR}/Info.plist: the activation rule must accept {uti}")
        if "public.data" in rule:
            errors.append(f"{SHARE_DIR}/Info.plist: the Release activation rule must not accept public.data")
        if SHARE_DATA_CLAUSE not in debug_rule or debug_rule.replace(SHARE_DATA_CLAUSE, "", 1) != rule:
            errors.append(f"{SHARE_DIR}/Info-Debug.plist: the Debug rule must be the Release rule plus{SHARE_DATA_CLAUSE}")
        stripped = []
        for plist in (release, debug):
            plist = copy.deepcopy(plist)
            plist.get("NSExtension", {}).get("NSExtensionAttributes", {}).pop("NSExtensionActivationRule", None)
            stripped.append(plist)
        if stripped[0] != stripped[1]:
            errors.append(f"{SHARE_DIR}: Info.plist and Info-Debug.plist differ outside NSExtensionActivationRule")
    if not privacy_present:
        errors.append(f"{SHARE_DIR}/PrivacyInfo.xcprivacy is missing")
    share = target_block(project_yml, "mdviewShare")
    app = target_block(project_yml, "mdview")
    if share is None:
        errors.append("project.yml: no mdviewShare target")
    else:
        expected = {
            "type": "app-extension",
            "PRODUCT_BUNDLE_IDENTIFIER": SHARE_BUNDLE_ID,
            "APPLICATION_EXTENSION_API_ONLY": "YES",
            "GENERATE_INFOPLIST_FILE": "NO",
        }
        for key, value in expected.items():
            if yml_setting(share, key) != value:
                errors.append(f"project.yml: mdviewShare {key} must be {value}")
        for config, path in (("Debug", "Info-Debug.plist"), ("Release", "Info.plist")):
            if not re.search(rf"^\s*{config}:\s*\n\s*INFOPLIST_FILE:\s*{re.escape(SHARE_DIR)}/{re.escape(path)}\s*$", share, re.M):
                errors.append(f"project.yml: mdviewShare {config} INFOPLIST_FILE must be {SHARE_DIR}/{path}")
        for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
            if yml_setting(share, key) is None or yml_setting(share, key) != yml_setting(app, key):
                errors.append(f"project.yml: mdviewShare {key} must match the mdview app's")
    if app is None or not re.search(r"^\s*- target: mdviewShare\s*$", app, re.M):
        errors.append("project.yml: the mdview app must embed mdviewShare (- target: mdviewShare)")
    for path, text in swift_files.items():
        for number, line in enumerate(text.splitlines(), 1):
            for pattern, why in SHARE_BANNED:
                if pattern.search(line):
                    errors.append(f"{path}:{number}: {why}")
    return errors


ICON_DIR = "App/mdview/Assets.xcassets/AppIcon.appiconset"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ICON_FILES = {"any": "AppIcon.png", "dark": "AppIcon-dark.png", "tinted": "AppIcon-tinted.png"}
ICON_APPEARANCES = {
    "any": None,
    "dark": [{"appearance": "luminosity", "value": "dark"}],
    "tinted": [{"appearance": "luminosity", "value": "tinted"}],
}


def png_info(data):
    """(width, height, has_alpha) from PNG bytes, or None when they are not a PNG."""
    if len(data) < 33 or not data.startswith(PNG_MAGIC) or data[12:16] != b"IHDR":
        return None
    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    has_alpha = data[25] in (4, 6) or b"tRNS" in data
    return width, height, has_alpha


def check_app_icon(contents_text, pngs):
    """(i) The AppIcon set has any, dark and tinted 1024 universal entries and three 1024 PNGs;
    AppIcon.png has no alpha. contents_text: Contents.json text. pngs: {file name: bytes}."""
    errors = []
    try:
        images = json.loads(contents_text)["images"]
    except (ValueError, KeyError, TypeError):
        return [f"{ICON_DIR}/Contents.json: not valid JSON with an images list"]
    if not isinstance(images, list):
        return [f"{ICON_DIR}/Contents.json: images must be a list"]
    for kind, name in ICON_FILES.items():
        entries = [i for i in images if isinstance(i, dict) and i.get("filename") == name]
        if len(entries) != 1:
            errors.append(f"{ICON_DIR}/Contents.json: expected exactly one entry for {name}, found {len(entries)}")
        else:
            entry = entries[0]
            for key, want in (("idiom", "universal"), ("platform", "ios"), ("size", "1024x1024")):
                if entry.get(key) != want:
                    errors.append(f"{ICON_DIR}/Contents.json: {name} {key} must be {want}")
            if entry.get("appearances") != ICON_APPEARANCES[kind]:
                errors.append(f"{ICON_DIR}/Contents.json: {name} has the wrong appearances")
        info = png_info(pngs.get(name, b""))
        if info is None:
            errors.append(f"{ICON_DIR}/{name}: missing or not a PNG")
            continue
        if info[:2] != (1024, 1024):
            errors.append(f"{ICON_DIR}/{name}: must be 1024x1024, is {info[0]}x{info[1]}")
        if kind == "any" and info[2]:
            errors.append(f"{ICON_DIR}/{name}: must not have an alpha channel (App Store rejects it)")
    if len(images) != len(ICON_FILES):
        errors.append(f"{ICON_DIR}/Contents.json: expected {len(ICON_FILES)} images, found {len(images)}")
    return errors


ACCENT_PATH = "App/mdview/Assets.xcassets/AccentColor.colorset/Contents.json"
LIGHT_BACKGROUNDS = ["#FFFFFF", "#F2F2F7", "#E5E5EA"]
DARK_BACKGROUNDS = ["#000000", "#1C1C1E", "#2C2C2E"]
DARK_ELEVATED = "#3A3A3C"
ACCENT_VARIANTS = {
    (False, False): "any",
    (True, False): "dark",
    (False, True): "light high contrast",
    (True, True): "dark high contrast",
}


def accent_component(value):
    """A colorset component as 0...1: a float string ("0.290") or a 0xNN byte."""
    text = str(value).strip().lower()
    number = int(text, 16) / 255 if text.startswith("0x") else float(text)
    if not 0 <= number <= 1:
        raise ValueError(value)
    return number


def relative_luminance(rgb):
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast_ratio(a, b):
    hi, lo = sorted((relative_luminance(a), relative_luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def hex_rgb(text):
    return tuple(int(text[i : i + 2], 16) / 255 for i in (1, 3, 5))


def check_accent_contrast(contents_text, report=None):
    """(j) AccentColor has any, dark, light high-contrast and dark high-contrast variants. Light
    variants reach 4.5:1 on white and light greys; dark variants reach 4.5:1 on black and dark greys
    up to #2C2C2E and 3:1 on #3A3A3C (WCAG 2.x). report(line) receives each ratio."""
    where = "AccentColor.colorset/Contents.json"
    try:
        colors = json.loads(contents_text)["colors"]
        variants = {}
        for entry in colors:
            appearances = {a["appearance"]: a["value"] for a in entry.get("appearances", [])}
            key = (appearances.get("luminosity") == "dark", appearances.get("contrast") == "high")
            comps = entry["color"]["components"]
            variants[key] = tuple(accent_component(comps[c]) for c in ("red", "green", "blue"))
    except (ValueError, KeyError, TypeError, AttributeError):
        return [f"{where}: not a valid colorset with sRGB components"]
    errors = []
    for key, label in ACCENT_VARIANTS.items():
        if key not in variants:
            errors.append(f"{where}: missing the {label} variant")
            continue
        dark = key[0]
        for background in DARK_BACKGROUNDS + [DARK_ELEVATED] if dark else LIGHT_BACKGROUNDS:
            ratio = contrast_ratio(variants[key], hex_rgb(background))
            need = 3.0 if background == DARK_ELEVATED else 4.5
            if report:
                report(f"  accent {label} on {background}: {ratio:.2f} (need {need})")
            if ratio < need:
                errors.append(f"{where}: {label} accent is {ratio:.2f}:1 on {background}, needs {need}")
    return errors


CHECKS = [
    ("no DEVELOPMENT_TEAM in tracked files", "team"),
    ("bundle ids under " + BUNDLE_PREFIX, "bundle"),
    ("privacy manifests: no tracking, no collected data", "privacy"),
    ("no TRUEPREDICATE in App plists", "predicate"),
    ("display name: Info.plist, project.yml and listing.md agree", "display"),
    ("markdown types: Info.plist matches MarkdownFileTypes.swift", "types"),
    ("App/Shared is extension-safe: no UIApplication.shared", "shared"),
    ("share extension: point id, activation rules, bundle id, privacy manifest, safe APIs", "share"),
    ("app icon: any, dark and tinted 1024 PNGs, no alpha in AppIcon.png", "icon"),
    ("accent color: dark and high-contrast variants meet WCAG contrast", "accent"),
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


def read_bytes(path):
    try:
        return (ROOT / path).read_bytes()
    except OSError:
        return b""


def run():
    tracked = tracked_files()
    team_files = {}
    for path in tracked:
        text = read_text(path)
        if text is not None:
            team_files[path] = text
    app = [p for p in tracked if p.startswith("App/")]
    manifests = {p: (ROOT / p).read_bytes() for p in app if p.endswith("PrivacyInfo.xcprivacy")}
    info_plists = {p: team_files.get(p, "") for p in app if p.endswith(".plist")}
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
        "share": check_share_extension(
            read_bytes(f"{SHARE_DIR}/Info.plist"),
            read_bytes(f"{SHARE_DIR}/Info-Debug.plist"),
            team_files.get("project.yml", ""),
            {
                str(path.relative_to(ROOT)): path.read_text(encoding="utf-8")
                for path in sorted((ROOT / SHARE_DIR).rglob("*.swift"))
            },
            (ROOT / SHARE_DIR / "PrivacyInfo.xcprivacy").is_file(),
        ),
        "accent": check_accent_contrast(read_text(ACCENT_PATH) or "", print),
        "icon": check_app_icon(
            read_text(f"{ICON_DIR}/Contents.json") or "",
            {name: read_bytes(f"{ICON_DIR}/{name}") for name in ICON_FILES.values()},
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
        ("truepredicate debug", check_no_truepredicate, {"Info-Debug.plist": "TRUEPREDICATE"}, {"Info-Debug.plist": "<dict/>"}),
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
    share_rule = (
        'SUBQUERY(extensionItems, $item, SUBQUERY($item.attachments, $a, ANY $a.registeredTypeIdentifiers '
        'UTI-CONFORMS-TO "public.text" OR ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.file-url")'
        ".@count == 1).@count == 1"
    )
    share_release = {
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "NSExtension": {
            "NSExtensionAttributes": {"NSExtensionActivationRule": share_rule},
            "NSExtensionPointIdentifier": SHARE_POINT,
            "NSExtensionPrincipalClass": SHARE_PRINCIPAL,
        },
    }
    share_yml = (
        "targets:\n"
        "  mdview:\n    type: application\n    dependencies:\n      - target: mdviewShare\n"
        "    settings:\n      base:\n        MARKETING_VERSION: \"0.1.0\"\n        CURRENT_PROJECT_VERSION: \"1\"\n"
        "  mdviewShare:\n    type: app-extension\n    settings:\n      base:\n"
        "        PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview.share\n        GENERATE_INFOPLIST_FILE: NO\n"
        "        APPLICATION_EXTENSION_API_ONLY: YES\n        MARKETING_VERSION: \"0.1.0\"\n"
        "        CURRENT_PROJECT_VERSION: \"1\"\n      configs:\n"
        "        Debug:\n          INFOPLIST_FILE: App/mdviewShare/Info-Debug.plist\n"
        "        Release:\n          INFOPLIST_FILE: App/mdviewShare/Info.plist\n"
        "  mdviewUITests:\n    type: bundle.ui-testing\n"
    )
    share_swift = {"App/mdviewShare/A.swift": "extensionContext?.completeRequest(returningItems: [])"}

    def share_args(release=None, debug=None, yml=share_yml, swift=None, privacy=True):
        release = copy.deepcopy(share_release) if release is None else release
        if debug is None:
            debug = copy.deepcopy(release)
            attributes = debug.get("NSExtension", {}).get("NSExtensionAttributes", {})
            if isinstance(attributes.get("NSExtensionActivationRule"), str):
                attributes["NSExtensionActivationRule"] = attributes["NSExtensionActivationRule"].replace(
                    '"public.file-url")', '"public.file-url"' + SHARE_DATA_CLAUSE + ")"
                )
        return plistlib.dumps(release), plistlib.dumps(debug), yml, share_swift if swift is None else swift, privacy

    def share_release_with(mutate):
        plist = copy.deepcopy(share_release)
        mutate(plist)
        return plist

    def set_rule(rule):
        return share_release_with(lambda p: p["NSExtension"]["NSExtensionAttributes"].update({"NSExtensionActivationRule": rule}))

    debug_extra_key = share_release_with(lambda p: p.update({"Extra": True}))
    debug_extra_key["NSExtension"]["NSExtensionAttributes"]["NSExtensionActivationRule"] = share_rule.replace(
        '"public.file-url")', '"public.file-url"' + SHARE_DATA_CLAUSE + ")"
    )
    assert not check_share_extension(*share_args()), f"self-test: share failed on its good example: {check_share_extension(*share_args())}"
    print("ok: self-test share good")
    for name, args in [
        ("share point id", share_args(share_release_with(lambda p: p["NSExtension"].update({"NSExtensionPointIdentifier": "com.apple.ui-services"})))),
        ("share principal", share_args(share_release_with(lambda p: p["NSExtension"].update({"NSExtensionPrincipalClass": "ShareViewController"})))),
        ("share display name", share_args(share_release_with(lambda p: p.update({"CFBundleDisplayName": "mdview"})))),
        ("share release data", share_args(set_rule(share_rule.replace('"public.file-url")', '"public.file-url"' + SHARE_DATA_CLAUSE + ")")))),
        ("share truepredicate", share_args(set_rule("TRUEPREDICATE"))),
        ("share no subquery", share_args(set_rule('ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.text" OR "public.file-url"'))),
        ("share missing file-url", share_args(set_rule(share_rule.replace("public.file-url", "public.url")))),
        ("share dictionary rule", share_args(set_rule({"NSExtensionActivationSupportsText": True}))),
        ("share debug same rule", share_args(debug=copy.deepcopy(share_release))),
        ("share debug other key", share_args(debug=debug_extra_key)),
        ("share privacy", share_args(privacy=False)),
        ("share bundle id", share_args(yml=share_yml.replace("us.par72.mdview.share", "us.par72.mdview"))),
        ("share api only", share_args(yml=share_yml.replace("APPLICATION_EXTENSION_API_ONLY: YES", "APPLICATION_EXTENSION_API_ONLY: NO"))),
        ("share debug plist path", share_args(yml=share_yml.replace("Info-Debug.plist", "Info.plist"))),
        ("share version", share_args(yml=share_yml.replace('CURRENT_PROJECT_VERSION: "1"\n      configs', 'CURRENT_PROJECT_VERSION: "2"\n      configs'))),
        ("share embed", share_args(yml=share_yml.replace("      - target: mdviewShare\n", ""))),
        ("share no target", share_args(yml="targets:\n  mdview:\n    dependencies:\n      - target: mdviewShare\n")),
        ("share UIApplication", share_args(swift={"App/mdviewShare/A.swift": "UIApplication.shared.open(url)"})),
        ("share URLSession", share_args(swift={"App/mdviewShare/A.swift": "let s = URLSession.shared"})),
        ("share open app", share_args(swift={"App/mdviewShare/A.swift": "extensionContext?.open(url)"})),
        ("share open app forced", share_args(swift={"App/mdviewShare/A.swift": "extensionContext!.open(url)"})),
        ("share unreadable plist", (b"not a plist",) + share_args()[1:]),
    ]:
        assert check_share_extension(*args), f"self-test: {name} did not fail on its bad example"
        print(f"ok: self-test {name}")
    def icon_png(size=1024, color_type=2, extra=b""):
        header = size.to_bytes(4, "big") * 2 + bytes([8, color_type, 0, 0, 0])
        return PNG_MAGIC + b"\x00\x00\x00\x0dIHDR" + header + b"\x00\x00\x00\x00" + extra

    def icon_contents(mutate=None):
        images = []
        for kind, name in ICON_FILES.items():
            entry = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
            if ICON_APPEARANCES[kind]:
                entry["appearances"] = copy.deepcopy(ICON_APPEARANCES[kind])
            images.append(entry)
        if mutate:
            mutate(images)
        return json.dumps({"images": images})

    good_icons = {name: icon_png(color_type=6 if kind != "any" else 2) for kind, name in ICON_FILES.items()}
    assert not check_app_icon(icon_contents(), good_icons), "self-test: icon failed on its good example"
    print("ok: self-test icon good")
    for name, args in [
        ("icon alpha", (icon_contents(), {**good_icons, "AppIcon.png": icon_png(color_type=6)})),
        ("icon tRNS", (icon_contents(), {**good_icons, "AppIcon.png": icon_png(extra=b"tRNS")})),
        ("icon size", (icon_contents(), {**good_icons, "AppIcon-dark.png": icon_png(512, 6)})),
        ("icon missing file", (icon_contents(), {k: v for k, v in good_icons.items() if k != "AppIcon-tinted.png"})),
        ("icon not png", (icon_contents(), {**good_icons, "AppIcon.png": b"nope"})),
        ("icon no dark appearance", (icon_contents(lambda i: i[1].pop("appearances")), good_icons)),
        ("icon wrong tinted value", (icon_contents(lambda i: i[2]["appearances"][0].update({"value": "dark"})), good_icons)),
        ("icon any has appearance", (icon_contents(lambda i: i[0].update({"appearances": ICON_APPEARANCES["dark"]})), good_icons)),
        ("icon wrong size key", (icon_contents(lambda i: i[0].update({"size": "512x512"})), good_icons)),
        ("icon extra image", (icon_contents(lambda i: i.append({"idiom": "universal"})), good_icons)),
        ("icon bad json", ("{", good_icons)),
    ]:
        assert check_app_icon(*args), f"self-test: {name} did not fail on its bad example"
        print(f"ok: self-test {name}")
    def accent_contents(drop=(), swap=None):
        def entry(dark, high, rgb):
            appearances = []
            if dark:
                appearances.append({"appearance": "luminosity", "value": "dark"})
            if high:
                appearances.append({"appearance": "contrast", "value": "high"})
            comps = dict(zip(("red", "green", "blue"), rgb))
            item = {"color": {"color-space": "srgb", "components": {**comps, "alpha": "1.000"}}, "idiom": "universal"}
            if appearances:
                item["appearances"] = appearances
            return item

        values = {
            (False, False): ("0.180", "0.420", "0.290"),
            (True, False): ("0x5B", "0xBF", "0x8A"),
            (False, True): ("0x1F", "0x4A", "0x33"),
            (True, True): ("0x7A", "0xD3", "0xA3"),
        }
        values.update(swap or {})
        return json.dumps({"colors": [entry(*k, v) for k, v in values.items() if k not in drop]})

    assert not check_accent_contrast(accent_contents()), "self-test: accent failed on its good example"
    print("ok: self-test accent good")
    for name, text in [
        ("accent only #2E6B4A", accent_contents(drop=[(True, False), (False, True), (True, True)])),
        ("accent no dark", accent_contents(drop=[(True, False)])),
        ("accent no dark high contrast", accent_contents(drop=[(True, True)])),
        ("accent dark reuses light green", accent_contents(swap={(True, False): ("0.180", "0.420", "0.290")})),
        ("accent weak on #3A3A3C", accent_contents(swap={(True, False): ("0x2E", "0x8B", "0x5C")})),
        ("accent bad json", "{"),
    ]:
        assert check_accent_contrast(text), f"self-test: {name} did not fail on its bad example"
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
