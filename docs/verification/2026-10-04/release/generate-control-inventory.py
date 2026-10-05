"""Source inventory only: this deliberately does not claim runtime verification."""
from pathlib import Path
import datetime
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
CONTROL_NAMES = (
    "Button", "NavigationLink", "Toggle", "TextField", "SecureField",
    "TextEditor", "Picker", "DatePicker", "ShareLink", "Link", "Menu",
    "PhotosPicker", "DisclosureGroup", "EvidenceTextEditor", "OptionalDateField",
    "SourceLink",
)
PRESENTATIONS = (
    "sheet", "fullScreenCover", "fileImporter", "confirmationDialog", "alert",
    "searchable", "onOpenURL",
)


def lexical_mask(text):
    """Keep offsets/braces outside strings and nested comments for Swift ranges."""
    result = list(text)
    index = 0
    while index < len(text):
        if text.startswith("//", index):
            end = text.find("\n", index)
            if end < 0:
                end = len(text)
        elif text.startswith("/*", index):
            depth, end = 1, index + 2
            while depth and end < len(text):
                if text.startswith("/*", end):
                    depth += 1
                    end += 2
                elif text.startswith("*/", end):
                    depth -= 1
                    end += 2
                else:
                    end += 1
        elif text[index] == '"':
            delimiter = '"""' if text.startswith('"""', index) else '"'
            end = index + len(delimiter)
            while end < len(text):
                if text[end] == "\\":
                    end += 2
                elif text.startswith(delimiter, end):
                    end += len(delimiter)
                    break
                else:
                    end += 1
        else:
            index += 1
            continue
        for position in range(index, min(end, len(text))):
            if result[position] != "\n":
                result[position] = " "
        index = end
    return "".join(result)


def closing_brace(mask, opening):
    depth = 1
    for position in range(opening + 1, len(mask)):
        depth += (mask[position] == "{") - (mask[position] == "}")
        if depth == 0:
            return position + 1
    raise ValueError("Unbalanced source structure")


def source_line(text, offset):
    return text.count("\n", 0, offset) + 1


def label_for(text, offset):
    window = text[offset:offset + 250]
    label = re.search(r'\b(?:Label|Text)\("((?:\\.|[^"\\])*)"', window)
    direct = re.match(r'\w+\s*\(\s*"((?:\\.|[^"\\])*)"', window)
    found = direct or label
    return found.group(1) if found else "Dynamic / supplied by parent"


records = []
files = sorted((ROOT / "CareInOne/Views").glob("*.swift"))
files += [ROOT / "CareInOne/App/CareInOneApp.swift"]
control_pattern = re.compile(r"\b(" + "|".join(CONTROL_NAMES) + r")\s*(?=\(|\{)")
presentation_pattern = re.compile(r"\.((?:" + "|".join(PRESENTATIONS) + r"))\s*\(")
view_pattern = re.compile(r"\bstruct\s+(\w+)(?:<[^\n]+?>)?\s*:\s*(View|ViewModifier|UIViewControllerRepresentable)\s*\{")
for path in files:
    text = path.read_text()
    mask = lexical_mask(text)
    views = []
    for view in view_pattern.finditer(mask):
        opening = mask.find("{", view.start())
        end = closing_brace(mask, opening)
        sites = []
        for control in control_pattern.finditer(mask, opening, end):
            # Declaration names are not control construction sites.
            if control.start() < opening + 1:
                continue
            offset = control.start()
            line = source_line(text, offset)
            line_start = text.rfind("\n", 0, offset) + 1
            line_end = text.find("\n", offset)
            if line_end < 0:
                line_end = len(text)
            sites.append({
                "type": control.group(1), "line": line,
                "label_hint": label_for(text, offset),
                "source_context": text[line_start:line_end].strip()[:500],
                "verification": "Source inventory only; map to feature ledger and final test evidence",
            })
        presentations = [{"type": match.group(1), "line": source_line(text, match.start())}
                         for match in presentation_pattern.finditer(mask, opening, end)]
        views.append({"view": view.group(1), "kind": view.group(2),
                      "line": source_line(text, view.start()), "controls": sites,
                      "presentations": presentations})
    records.append({"file": str(path.relative_to(ROOT)),
                    "sha256": hashlib.sha256(text.encode()).hexdigest(), "views": views})

inventory = {
    "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "method": "Lexical Swift view/control construction inventory, including reusable components and conditional branches. Dynamic ForEach instances and system-owned dialogs are not counted as unique runtime controls. A callsite is not a passing functional test.",
    "view_structures": sum(len(record["views"]) for record in records),
    "control_construction_sites": sum(len(view["controls"]) for record in records for view in record["views"]),
    "presentation_sites": sum(len(view["presentations"]) for record in records for view in record["views"]),
    "files": records,
}
(OUT / "control-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")

document = ["# Source screen and control inventory", "", "Generated from the inspected Swift source. This is a reachability and audit checklist, **not** proof that every conditional control has been exercised. Source hashes and individual line/control contexts are saved in [control-inventory.json](control-inventory.json). Dynamic care records produce repeated instances, and iOS supplies picker, share, permission and keyboard controls that need separate hands-on checks. See [FEATURE_VERIFICATION.md](FEATURE_VERIFICATION.md) for actual test evidence and limitations.", "", f"Inventory: {inventory['view_structures']} view/component structures, {inventory['control_construction_sites']} explicit control construction sites, {inventory['presentation_sites']} presentation/search/open-file sites. Reusable visual components are included so their source-owned controls do not disappear from the audit.", ""]
for record in records:
    document.extend(["## " + record["file"], ""])
    for view in record["views"]:
        document.extend(["### " + view["view"], ""])
        if not view["controls"] and not view["presentations"]:
            document.extend(["Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.", ""])
            continue
        document.extend(["| Source line | Control | Label hint / dynamic context |", "|---|---|---|"])
        for control in view["controls"]:
            label = control["label_hint"].replace("|", "\\|").replace("\n", " ")
            document.append(f"| {control['line']} | {control['type']} | {label} |")
        if view["presentations"]:
            document.extend(["", "Presentation/search entry points: " + ", ".join(f"`{item['type']}` at {item['line']}" for item in view["presentations"]) + "."])
        document.append("")
(OUT / "SCREEN_CONTROL_INVENTORY.md").write_text("\n".join(document) + "\n")
print(json.dumps({key: value for key, value in inventory.items() if key != "files"}, indent=2))
