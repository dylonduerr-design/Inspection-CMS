#!/usr/bin/env python3
"""
Clean up Word template XML to remove orphaned image/drawing fragments.
Use this after editing a template to remove broken XML from deleted images.
"""

import zipfile
import re
import sys
from pathlib import Path
import shutil

def clean_template(template_path):
    """Remove orphaned drawing/image XML elements from template."""
    
    template_path = Path(template_path)
    backup_path = template_path.with_suffix('.docx.backup')
    
    # Create backup
    shutil.copy2(template_path, backup_path)
    print(f"✓ Created backup: {backup_path}")
    
    with zipfile.ZipFile(template_path, 'r') as zip_in:
        doc_xml = zip_in.read('word/document.xml').decode('utf-8')
        original_xml = doc_xml
        
        # Remove empty drawing elements (images that were deleted but left XML)
        # Look for drawings that don't have content or have malformed structure
        
        # Pattern 1: Empty inline drawings
        doc_xml = re.sub(
            r'<w:drawing>.*?</w:drawing>',
            lambda m: '' if '{{' not in m.group() and 'blip' not in m.group() else m.group(),
            doc_xml,
            flags=re.DOTALL
        )
        
        # Pattern 2: Orphaned picture elements
        doc_xml = re.sub(
            r'<pic:pic[^>]*>.*?</pic:pic>',
            lambda m: '' if '{{' not in m.group() else m.group(),
            doc_xml,
            flags=re.DOTALL
        )
        
        # Pattern 3: Empty runs with just drawing properties
        doc_xml = re.sub(
            r'<w:r>[\s]*<w:rPr>.*?</w:rPr>[\s]*</w:r>',
            '',
            doc_xml,
            flags=re.DOTALL
        )
        
        # Pattern 4: Fix excessive whitespace before photo/caption tags
        # This is critical for docxtpl to properly recognize and replace image placeholders
        def fix_tag_whitespace(match):
            """Remove excessive leading whitespace from jinja2 tags"""
            attrs = match.group(1)
            text = match.group(2)
            # If text contains {{ photo_X }} or {{ caption_X }}, remove excessive leading spaces
            if re.search(r'\{\{\s*(photo_\d|caption_\d)\s*\}\}', text):
                # Keep at most 1 leading space
                text = re.sub(r'^\s{2,}', ' ', text)
                # Also clean up spaces around the tag itself
                text = re.sub(r'\s{3,}(\{\{)', r' \1', text)
            return f'<w:t{attrs}>{text}</w:t>'
        
        doc_xml = re.sub(
            r'<w:t([^>]*)>([^<]+)</w:t>',
            fix_tag_whitespace,
            doc_xml
        )
        
        if doc_xml != original_xml:
            print(f"✓ Cleaned up XML (removed orphaned elements)")
            
            # Save cleaned template
            with zipfile.ZipFile(str(template_path) + '.tmp', 'w', zipfile.ZIP_DEFLATED) as zip_out:
                for item in zip_in.infolist():
                    if item.filename == 'word/document.xml':
                        zip_out.writestr(item, doc_xml.encode('utf-8'))
                    else:
                        zip_out.writestr(item, zip_in.read(item.filename))
            
            shutil.move(str(template_path) + '.tmp', template_path)
            print(f"✓ Template cleaned: {template_path}")
        else:
            print("✓ No cleanup needed - template looks good")
            backup_path.unlink()  # Remove backup if no changes
    
    return True

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python clean_template.py <template.docx>")
        sys.exit(1)
    
    template_path = sys.argv[1]
    if not Path(template_path).exists():
        print(f"Error: Template not found: {template_path}")
        sys.exit(1)
    
    clean_template(template_path)
    print("\nDone! You can now test the template.")
