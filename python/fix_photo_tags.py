#!/usr/bin/env python3
"""
Fix photo tags in Word template XML.
Removes excessive whitespace and cleans up photo placeholder tags.
"""

import sys
import re
import zipfile
import shutil
from pathlib import Path


def fix_photo_tags(template_path, output_path):
    """
    Fix photo tags in the Word template by removing excessive leading whitespace.
    
    Args:
        template_path: Path to the input .docx template
        output_path: Path for the fixed .docx template
    """
    # Extract the template
    temp_dir = Path("/tmp/template_fix")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir(parents=True)
    
    print(f"Extracting template from: {template_path}")
    with zipfile.ZipFile(template_path, 'r') as zip_ref:
        zip_ref.extractall(temp_dir)
    
    # Read the document.xml
    doc_xml_path = temp_dir / "word" / "document.xml"
    with open(doc_xml_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Original photo tag examples:")
    # Show original photo tags
    for match in re.finditer(r'<w:t[^>]*>([^<]*\{\{[^}]*photo_\d[^}]*\}\}[^<]*)</w:t>', content):
        print(f"  {repr(match.group(1)[:80])}")
    
    # Fix the photo tags by removing excessive leading whitespace
    # Pattern: captures text runs with lots of spaces before photo tags
    def fix_whitespace(match):
        text_content = match.group(1)
        # Remove excessive leading whitespace (more than 2 spaces) before photo tags
        fixed = re.sub(r'\s{3,}(\{\{\s*photo_\d\s*\}\})', r' \1', text_content)
        return f'<w:t{match.group(0)[4:match.group(0).index(">")]}>{fixed}</w:t>'
    
    # Apply the fix
    content = re.sub(
        r'<w:t([^>]*)>([^<]*\{\{\s*photo_\d\s*\}\}[^<]*)</w:t>',
        lambda m: f'<w:t{m.group(1)}>{re.sub(r"\\s{{3,}}(\\{{\\{{\\s*photo_\\d\\s*\\}}\\}})", r" \\1", m.group(2))}</w:t>',
        content
    )
    
    print("\nFixed photo tag examples:")
    # Show fixed photo tags
    for match in re.finditer(r'<w:t[^>]*>([^<]*\{\{[^}]*photo_\d[^}]*\}\}[^<]*)</w:t>', content):
        print(f"  {repr(match.group(1)[:80])}")
    
    # Write the fixed content back
    with open(doc_xml_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Repackage as .docx
    print(f"\nCreating fixed template: {output_path}")
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as docx:
        for file_path in temp_dir.rglob('*'):
            if file_path.is_file():
                arcname = file_path.relative_to(temp_dir)
                docx.write(file_path, arcname)
    
    # Cleanup
    shutil.rmtree(temp_dir)
    print("Done!")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python fix_photo_tags.py <input_template.docx> <output_template.docx>")
        sys.exit(1)
    
    fix_photo_tags(sys.argv[1], sys.argv[2])
