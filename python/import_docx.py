#!/usr/bin/env python3
"""DOCX Importer (best-effort, strict-template)

Parses a .docx that closely matches the inspection template layout and extracts:
- contract number / project title
- commentary (best-effort)
- QA table entries (CODE/TEST/LOCATION/RESULT/REMARKS)
- first N photos in document order (1..N)

Outputs a single JSON object to stdout.
"""

import argparse
import json
import os
import re
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

W_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
A_NS = 'http://schemas.openxmlformats.org/drawingml/2006/main'
REL_NS = 'http://schemas.openxmlformats.org/package/2006/relationships'

NS = {
    'w': W_NS,
    'r': R_NS,
    'a': A_NS,
    'rel': REL_NS,
}


def _norm(s: str) -> str:
    return re.sub(r'\s+', ' ', (s or '').strip())


def _cell_text(tc: ET.Element) -> str:
    parts = []
    for t in tc.findall('.//w:t', NS):
        if t.text:
            parts.append(t.text)
    return _norm(''.join(parts))


def _row_cells(tr: ET.Element):
    return [_cell_text(tc) for tc in tr.findall('./w:tc', NS)]


def _all_tables(root: ET.Element):
    return root.findall('.//w:tbl', NS)


def _find_kv_in_tables(root: ET.Element, key_label: str):
    """Find value in a 2-col-ish table where one cell contains key_label."""
    key_label_n = _norm(key_label).lower()
    for tbl in _all_tables(root):
        for tr in tbl.findall('./w:tr', NS):
            cells = _row_cells(tr)
            for idx, cell in enumerate(cells):
                if _norm(cell).lower() == key_label_n and idx + 1 < len(cells):
                    return cells[idx + 1]
                if key_label_n in _norm(cell).lower() and idx + 1 < len(cells):
                    return cells[idx + 1]
    return None


def _find_table_by_header(root: ET.Element, header_cells_expected):
    expected = [_norm(h).lower() for h in header_cells_expected]
    for tbl in _all_tables(root):
        rows = tbl.findall('./w:tr', NS)
        for tr in rows[:3]:
            cells = [_norm(c).lower() for c in _row_cells(tr) if _norm(c)]
            if not cells:
                continue
            if cells == expected:
                return tbl
    return None


def _extract_qa_entries(root: ET.Element):
    qa_header = ['CODE', 'TEST', 'LOCATION', 'RESULT', 'REMARKS']
    tbl = _find_table_by_header(root, qa_header)
    if tbl is None:
        return []

    rows = tbl.findall('./w:tr', NS)

    header_row_idx = None
    for i, tr in enumerate(rows):
        cells = [_norm(c).lower() for c in _row_cells(tr) if _norm(c)]
        if cells == [_norm(h).lower() for h in qa_header]:
            header_row_idx = i
            break

    if header_row_idx is None:
        return []

    entries = []
    for tr in rows[header_row_idx + 1:]:
        cells = _row_cells(tr)
        cells = (cells + [''] * 5)[:5]
        if all(not _norm(c) for c in cells):
            continue

        normalized_upper = [_norm(c).upper() for c in cells]

        # Skip if the QA header repeats
        if normalized_upper == qa_header:
            continue

        # The template uses a single big Word table for multiple sections.
        # Once we hit the next section's header, stop parsing QA rows.
        placed_header = ['CODE', 'DESC', 'QTY', 'NOTES', '']
        crew_header = ['CONTRACTOR', 'SUPER', 'FOREMAN', 'SURVEY', 'OPERATOR']
        equipment_header = ['CONTRACTOR', 'EQUIPMENT', 'QTY', 'HOURS', 'REMARKS']

        if normalized_upper == placed_header:
            break
        if normalized_upper == crew_header:
            break
        if normalized_upper == equipment_header:
            break
        if normalized_upper[0].startswith('ADDITIONAL INFORMATION'):
            break

        entry = {
            'code': cells[0],
            'test': cells[1],
            'location': cells[2],
            'result': cells[3],
            'remarks': cells[4],
        }
        # Skip pure-placeholder rows (very empty)
        if sum(1 for v in entry.values() if _norm(v)) == 0:
            continue
        entries.append(entry)

    return entries


def _load_relationships(z: zipfile.ZipFile):
    rels_path = 'word/_rels/document.xml.rels'
    rels = {}
    try:
        xml = z.read(rels_path)
    except KeyError:
        return rels

    root = ET.fromstring(xml)
    for rel in root.findall('./rel:Relationship', NS):
        rid = rel.attrib.get('Id')
        target = rel.attrib.get('Target')
        if rid and target:
            rels[rid] = target
    return rels


def _iter_blip_rids(document_root: ET.Element):
    """Yield r:embed rIds for images in approximate document order."""
    # We walk all elements and find a:blip nodes.
    for el in document_root.iter():
        if el.tag.endswith('}blip'):
            rid = el.attrib.get(f'{{{R_NS}}}embed')
            if rid:
                yield rid


def _guess_content_type(filename: str) -> str:
    ext = Path(filename).suffix.lower()
    if ext in ('.jpg', '.jpeg'):
        return 'image/jpeg'
    if ext == '.png':
        return 'image/png'
    if ext == '.gif':
        return 'image/gif'
    if ext == '.bmp':
        return 'image/bmp'
    return 'application/octet-stream'


def _extract_photos(z: zipfile.ZipFile, document_root: ET.Element, extract_dir: Path, max_photos: int):
    rels = _load_relationships(z)
    photos = []
    seen_targets = set()

    for rid in _iter_blip_rids(document_root):
        target = rels.get(rid)
        if not target:
            continue
        # Targets are typically like "media/image1.jpeg"
        target_norm = target.lstrip('/').replace('\\', '/')
        if not target_norm.startswith('media/'):
            continue
        if target_norm in seen_targets:
            continue

        media_path = f'word/{target_norm}'
        try:
            blob = z.read(media_path)
        except KeyError:
            continue

        seen_targets.add(target_norm)
        ext = Path(target_norm).suffix
        out_name = f'photo_{len(photos) + 1}{ext}'
        out_path = extract_dir / out_name
        out_path.write_bytes(blob)

        photos.append({
            'index': len(photos) + 1,
            'filename': out_name,
            'content_type': _guess_content_type(out_name),
            'path': str(out_path),
            'caption': ''
        })

        if len(photos) >= max_photos:
            break

    return photos


def _extract_photo_captions(root: ET.Element):
    """Best-effort: parse captions from the 'Construction Progress Photos' table."""
    captions = {}
    for tbl in _all_tables(root):
        # Quick scan: does any cell contain the photos header?
        tbl_text = ' '.join(_cell_text(tc) for tc in tbl.findall('.//w:tc', NS))
        if 'construction progress photos' not in _norm(tbl_text).lower():
            continue

        rows = tbl.findall('./w:tr', NS)
        for tr in rows:
            row_text = ' '.join(_row_cells(tr))
            m = re.search(r'Photo\s+No\.?\s*(\d+)\s*:\s*(.*)', row_text, flags=re.IGNORECASE)
            if m:
                idx = int(m.group(1))
                cap = _norm(m.group(2))
                # Remove any stray 'Photo No. X:' echoes
                captions[idx] = cap
        break

    return captions


def _extract_commentary_best_effort(root: ET.Element):
    """Best-effort: find the text after the 'DESCRIPTION OF WORK PERFORMED:' anchor."""
    anchor = 'DESCRIPTION OF WORK PERFORMED:'
    stop_anchors = [
        'Specify any Additional Activities Performed:',
        'Safety & Security Compliance:',
        'Construction Progress Photos'
    ]

    # Flatten cell texts and paragraph texts in order (rough but stable for template-locked docs)
    blocks = []
    for el in root.findall('.//w:body/*', NS):
        if el.tag.endswith('}p'):
            txt = _norm(''.join(t.text or '' for t in el.findall('.//w:t', NS)))
            if txt:
                blocks.append(txt)
        elif el.tag.endswith('}tbl'):
            # represent tables as joined row strings
            for tr in el.findall('./w:tr', NS):
                row = ' | '.join([_norm(c) for c in _row_cells(tr) if _norm(c)])
                if row:
                    blocks.append(row)

    joined = '\n'.join(blocks)
    if anchor.lower() not in joined.lower():
        return ''

    start_idx = joined.lower().find(anchor.lower())
    after = joined[start_idx + len(anchor):]

    # Cut off at first stop anchor
    cut = len(after)
    for s in stop_anchors:
        pos = after.lower().find(s.lower())
        if pos != -1:
            cut = min(cut, pos)

    commentary = _norm(after[:cut])
    return commentary


def parse_docx(input_path: Path, extract_dir: Path, max_photos: int):
    errors = []

    if not input_path.exists():
        raise FileNotFoundError(str(input_path))

    with zipfile.ZipFile(input_path, 'r') as z:
        try:
            document_xml = z.read('word/document.xml')
        except KeyError:
            raise RuntimeError('Invalid DOCX: missing word/document.xml')

        root = ET.fromstring(document_xml)

        # Template fingerprint
        text_blob = _norm(' '.join([t.text or '' for t in root.findall('.//w:t', NS)]))
        required = [
            'Contract No.',
            'DESCRIPTION OF WORK PERFORMED:',
            'Construction Progress Photos'
        ]
        hits = 0
        for r in required:
            if r.lower() in text_blob.lower():
                hits += 1
            else:
                errors.append(f"Missing expected anchor: {r}")

        confidence = hits / len(required)
        valid_template = confidence >= 0.67

        contract_number = _find_kv_in_tables(root, 'Contract No.:')
        project_title = _find_kv_in_tables(root, 'Contract Title:')

        qa_entries = _extract_qa_entries(root)
        if not qa_entries:
            errors.append('QA table not found or empty')

        photos = _extract_photos(z, root, extract_dir, max_photos=max_photos)
        captions = _extract_photo_captions(root)
        for p in photos:
            idx = p.get('index')
            if idx in captions and captions[idx]:
                p['caption'] = captions[idx]

        commentary = _extract_commentary_best_effort(root)

        return {
            'valid_template': bool(valid_template),
            'confidence': float(confidence),
            'errors': errors,
            'extracted': {
                'contract_number': contract_number or '',
                'project_title': project_title or '',
                'commentary': commentary or '',
                'qa_entries': qa_entries,
                'photos': photos,
            }
        }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', required=True)
    ap.add_argument('--extract-dir', required=True)
    ap.add_argument('--max-photos', type=int, default=6)
    args = ap.parse_args()

    input_path = Path(args.input)
    extract_dir = Path(args.extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)

    result = parse_docx(input_path, extract_dir, max_photos=args.max_photos)
    sys.stdout.write(json.dumps(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
