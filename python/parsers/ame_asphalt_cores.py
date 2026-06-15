"""AME asphalt core compaction reports for P-401 and P-403.

Supports both AME layouts currently seen in the project:

* Legacy column-oriented core reports with ``Lot/Sublot`` and ``Core ID`` rows.
* New FAA CORE TEST RESULTS forms with Section 1 height readings and Section 2
  specific gravity / compaction rows.

One output row is emitted per core.
"""

import re

from . import ame_common

EXPECTED_FIELDS = [
    "sublot_number",
    "core_id",
    "core_type",
    "thickness_as_received_in",
    "thickness_trimmed_in",
    "gmb",
    "gmm",
    "compaction_pct",
    "absorption_pct",
    "astm_standard",
    "required_compaction_pct",
    "result",
]

NEW_FORM_SIGNATURE_RE = re.compile(r"FAA\s+CORE\s+TEST\s+RESULTS", re.IGNORECASE)

SUBLOT_LINE_RE = re.compile(r"^\s*Lot/Sublot:?\s+(.+)$", re.MULTILINE)
CORE_ID_LINE_RE = re.compile(r"^\s*(?P<kind>Mat|Joint)?\s*Core\s+ID\s+(?P<ids>.+)$", re.MULTILINE)
CORE_ID_TOKEN_RE = re.compile(r"\b[MJ]\d+\b", re.IGNORECASE)
SUBLOT_TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*\s*/\s*SL\d+")
THICK_AR_RE = re.compile(r"Average\s+Core\s+Thickness\s*\(as-received\)[^\n]*?\.\s*(.+)")
THICK_TR_RE = re.compile(r"Average\s+Core\s+Thickness\s*\(trimmed\)[^\n]*?\.\s*(.+)")
GMB_RE = re.compile(r"ASTM\s+(D\d+)\s*,\s*Bulk Specific Gravity\s+(.+)")
GMM_RE = re.compile(r"Theoretical\s+Max\.?\s+Specific\s+Gravity\s+(.+)")
COMPACTION_RE = re.compile(r"Compaction\*?,?\s*%\s+(.+)")
REQUIREMENTS_RE = re.compile(
    r"Project\s+Requirements?:\s*"
    r"(?:Surface\s+)?Mat\.?\s*[>\u2265]=?\s*(?P<mat>[\d.]+)\s*%"
    r"[^\n]*?"
    r"Joint\s*[>\u2265]=?\s*(?P<joint>[\d.]+)\s*%",
    re.IGNORECASE,
)

NEW_SECTION2_ROW_RE = re.compile(
    r"^\s*(?P<core_id>[MJ]\d+)\s+"
    r"(?P<thick_ar>[\d.]+)\s+"
    r"(?P<thick_tr>[\d.]+)\s+"
    r"(?P<dry_weight_g>[\d.,]+)\s+"
    r"(?P<submerged_weight_g>[\d.,]+)\s+"
    r"(?P<ssd_weight_g>[\d.,]+)\s+"
    r"(?P<volume_cm3>[\d.,]+)\s+"
    r"(?P<gmb>[\d.]+)\s+"
    r"(?P<bulk_density_pcf>[\d.]+)\s+"
    r"(?P<gmm>[\d.]+)\s+"
    r"(?P<absorption>[\d.]+)%\s+"
    r"(?P<compaction>[\d.]+)%",
    re.MULTILINE,
)

CORE_TYPE_PREFIX = {"M": "mat", "J": "joint"}


def parse(text: str) -> dict:
    header = ame_common.parse_header(text)
    if is_new_faa_core_form(text):
        return _parse_new_faa_core_form(text, header)
    return _parse_legacy_core_report(text, header)


def is_new_faa_core_form(text: str) -> bool:
    return NEW_FORM_SIGNATURE_RE.search(text) is not None


def _parse_new_faa_core_form(text: str, header: dict) -> dict:
    errors = []
    rows = []
    lot_number = header.get("lot_number")
    test_date = header.get("date_tested") or header.get("date_sampled") or header.get("report_date")

    for match in NEW_SECTION2_ROW_RE.finditer(text):
        core_id = match.group("core_id").upper()
        core_type = CORE_TYPE_PREFIX.get(core_id[:1])
        required = None
        compaction_val = ame_common.to_float(match.group("compaction"))

        rows.append({
            "sublot_number": _sublot_for_core(lot_number, core_id),
            "core_id": core_id,
            "core_type": core_type,
            "test_date": test_date,
            "thickness_as_received_in": ame_common.to_float(match.group("thick_ar")),
            "thickness_trimmed_in": ame_common.to_float(match.group("thick_tr")),
            "dry_weight_g": ame_common.to_float(match.group("dry_weight_g")),
            "submerged_weight_g": ame_common.to_float(match.group("submerged_weight_g")),
            "ssd_weight_g": ame_common.to_float(match.group("ssd_weight_g")),
            "volume_cm3": ame_common.to_float(match.group("volume_cm3")),
            "gmb": ame_common.to_float(match.group("gmb")),
            "bulk_density_pcf": ame_common.to_float(match.group("bulk_density_pcf")),
            "gmm": ame_common.to_float(match.group("gmm")),
            "absorption_pct": ame_common.to_float(match.group("absorption")),
            "compaction_pct": compaction_val,
            "astm_standard": "D2726",
            "required_compaction_pct": required,
            "result": _compute_result(compaction_val, required),
        })

    if not rows:
        errors.append("no_core_rows_found")
    if lot_number is None:
        errors.append("missing_lot_number")

    return {"header": header, "rows": rows, "errors": errors}


def _parse_legacy_core_report(text: str, header: dict) -> dict:
    errors = []
    req_mat, req_joint = _parse_requirements(text)

    groups = _split_core_groups(text)
    if not groups:
        errors.append("no_core_groups_found")

    rows = []
    for idx, group_text in enumerate(groups):
        group_rows, group_errors = _parse_group(group_text, idx, req_mat, req_joint)
        rows.extend(group_rows)
        errors.extend(group_errors)

    return {"header": header, "rows": rows, "errors": errors}


def _parse_requirements(text: str):
    m = REQUIREMENTS_RE.search(text)
    if not m:
        return None, None
    return ame_common.to_float(m.group("mat")), ame_common.to_float(m.group("joint"))


def _split_core_groups(text: str):
    matches = list(SUBLOT_LINE_RE.finditer(text))
    groups = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        groups.append(text[start:end])
    return groups


def _parse_group(group_text: str, group_index: int, req_mat, req_joint):
    errors = []
    tag = f"@group{group_index + 1}"

    sublots = _extract_sublot_tokens(group_text)
    group_core_type, core_ids = _extract_core_id_tokens(group_text)

    if not sublots or not core_ids:
        errors.append(f"missing_sublot_or_core_id_row{tag}")
        return [], errors

    n = min(len(sublots), len(core_ids))
    if len(sublots) != len(core_ids):
        errors.append(f"column_count_mismatch{tag}")

    thick_ar = _numeric_columns(THICK_AR_RE, group_text, n)
    thick_tr = _numeric_columns(THICK_TR_RE, group_text, n)
    compaction = _numeric_columns(COMPACTION_RE, group_text, n)

    gmb_m = GMB_RE.search(group_text)
    astm = gmb_m.group(1) if gmb_m else None
    gmb_vals = _split_floats(gmb_m.group(2), n) if gmb_m else [None] * n

    gmm_m = GMM_RE.search(group_text)
    gmm_vals = _split_floats(gmm_m.group(1), n) if gmm_m else [None] * n

    rows = []
    for i in range(n):
        core_id = core_ids[i].upper()
        core_type = group_core_type or CORE_TYPE_PREFIX.get(core_id[:1])
        if core_type is None:
            errors.append(f"unknown_core_type:{core_id}{tag}")

        required = req_mat if core_type == "mat" else req_joint if core_type == "joint" else None
        compaction_val = compaction[i] if i < len(compaction) else None

        if thick_ar[i] is None:
            errors.append(f"missing_thickness_as_received:{core_id}{tag}")
        if thick_tr[i] is None:
            errors.append(f"missing_thickness_trimmed:{core_id}{tag}")
        if gmb_vals[i] is None:
            errors.append(f"missing_gmb:{core_id}{tag}")
        if gmm_vals[i] is None:
            errors.append(f"missing_gmm:{core_id}{tag}")
        if compaction_val is None:
            errors.append(f"missing_compaction:{core_id}{tag}")

        rows.append({
            "sublot_number": sublots[i],
            "core_id": core_id,
            "core_type": core_type,
            "thickness_as_received_in": thick_ar[i],
            "thickness_trimmed_in": thick_tr[i],
            "gmb": gmb_vals[i],
            "gmm": gmm_vals[i],
            "compaction_pct": compaction_val,
            "astm_standard": astm,
            "required_compaction_pct": required,
            "result": _compute_result(compaction_val, required),
        })

    return rows, errors


def _extract_sublot_tokens(group_text: str):
    m = SUBLOT_LINE_RE.search(group_text)
    if not m:
        return []
    return [re.sub(r"\s+", "", tok) for tok in SUBLOT_TOKEN_RE.findall(m.group(1))]


def _extract_core_id_tokens(group_text: str):
    m = CORE_ID_LINE_RE.search(group_text)
    if not m:
        return None, []
    kind = m.group("kind")
    core_type = {"Mat": "mat", "Joint": "joint"}.get(kind.title()) if kind else None
    return core_type, CORE_ID_TOKEN_RE.findall(m.group("ids"))


def _numeric_columns(pattern: re.Pattern, text: str, n: int):
    m = pattern.search(text)
    if not m:
        return [None] * n
    return _split_floats(m.group(1), n)


def _split_floats(s: str, n: int):
    values = [ame_common.to_float(tok) for tok in s.split()]
    values = [v for v in values if v is not None]
    if len(values) < n:
        values = values + [None] * (n - len(values))
    return values[:n]


def _sublot_for_core(lot_number, core_id):
    m = re.search(r"(\d+)$", core_id or "")
    if not m:
        return None
    sublot = f"SL{int(m.group(1))}"
    return f"L{lot_number}/{sublot}" if lot_number else sublot


def _compute_result(compaction_pct, required_pct):
    if compaction_pct is None or required_pct is None:
        return None
    return "pass" if compaction_pct >= required_pct else "fail"
