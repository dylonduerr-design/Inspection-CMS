#!/usr/bin/env python3
"""
DOCX Report Generator using docxtpl
Generates inspection reports from a Word template with embedded photos.
"""

import argparse
import json
import sys
import os
from pathlib import Path
import warnings

# Filter docxcompose warnings
warnings.filterwarnings("ignore", category=UserWarning, module="docxcompose")

from docxtpl import DocxTemplate, InlineImage
from docx.shared import Inches
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# python-docx enforces a 255-char limit on core document properties (Subject,
# Description, etc.) via CT_CoreProperties._set_element_text().  If the DOCX
# template has a Jinja2 tag inside a Word metadata/property field, rendering
# with AI-generated text raises ValueError before the file is ever saved.
# Patch the method to truncate silently; body content is completely unaffected.
try:
    from docx.oxml.coreprops import CT_CoreProperties as _CT_CoreProperties

    def _patched_set_element_text(self, prop_name, value):
        if not isinstance(value, str):
            value = str(value)
        if len(value) > 255:
            logger.warning(
                "Core property '%s' truncated from %d to 255 chars.",
                prop_name, len(value)
            )
            value = value[:255]
        element = self._get_or_add(prop_name)
        element.text = value

    _CT_CoreProperties._set_element_text = _patched_set_element_text
except Exception as _patch_err:
    logger.debug("Could not patch CT_CoreProperties._set_element_text: %s", _patch_err)


class ReportExporter:
    """Handles generation of DOCX reports from templates and JSON data."""
    
    PHOTO_SLOT_COUNT = 6
    DEFAULT_IMAGE_WIDTH = Inches(5.5)
    DEFAULT_IMAGE_HEIGHT = Inches(4.12)
    
    def __init__(self, template_path, output_path):
        """
        Initialize the exporter.
        
        Args:
            template_path: Path to the .docx template file
            output_path: Path where the generated report will be saved
        """
        self.template_path = Path(template_path)
        self.output_path = Path(output_path)
        
        if not self.template_path.exists():
            raise FileNotFoundError(f"Template not found: {self.template_path}")
    
    def generate(self, data_dict):
        """
        Generate a DOCX report from the template and data.
        
        Args:
            data_dict: Dictionary containing all report data and photo paths
        """
        logger.info(f"Loading template: {self.template_path}")
        doc = DocxTemplate(self.template_path)
        
        # Prepare the context with all data
        context = self._build_context(data_dict, doc)
        
        logger.info("Rendering template with data...")
        doc.render(context)
        
        logger.info(f"Saving report to: {self.output_path}")
        doc.save(str(self.output_path))
        logger.info("Report generated successfully!")
    
    def _is_valid_image(self, photo_path):
        """Check if image file is valid and supported by python-docx."""
        try:
            # Log file details
            file_size = os.path.getsize(photo_path)
            logger.info(f"Validating image: {photo_path}, size={file_size} bytes")

            # The most reliable test is to actually try loading it with python-docx
            from docx.image.image import Image as DocxImage
            DocxImage.from_file(photo_path)
            logger.info(f"Image validation PASSED: {photo_path}")
            return True
        except Exception as e:
            logger.error(f"Image validation FAILED for {photo_path}: {type(e).__name__}: {e}")
            return False
    
    def _pad_list_with_empty_dicts(self, items, min_length=10):
        """
        Pad a list with empty dictionaries to ensure safe index access.
        
        Args:
            items: List to pad (or None)
            min_length: Minimum length to pad to
            
        Returns:
            List padded with empty dicts
        """
        items = items or []
        if len(items) < min_length:
            items = list(items) + [{}] * (min_length - len(items))
        return items
    
    def _build_context(self, data, doc):
        """
        Build the context dictionary for template rendering.
        
        Args:
            data: Raw data dictionary from JSON
            doc: DocxTemplate object for creating InlineImage objects
            
        Returns:
            Dictionary with all variables for the template
        """
        context = {}
        
        # Copy all simple fields
        table_keys = {'photos', 'placed_quantities', 'qa_entries',
                      'equipment_entries', 'crew_entries', 'core_locations'}
        for key, value in data.items():
            if key not in table_keys:
                context[key] = value or ""
        
        # Handle photo placeholders
        photos = data.get('photos', []) or []  # Handle None
        logger.info(f"Processing {len(photos)} photos for export")

        for i in range(1, self.PHOTO_SLOT_COUNT + 1):
            photo_key = f'photo_{i}'
            caption_key = f'caption_{i}'

            if i <= len(photos) and photos[i-1]:
                photo_data = photos[i-1]
                photo_path = photo_data.get('path')

                logger.info(f"Photo {i}: path={photo_path}, exists={os.path.exists(photo_path) if photo_path else False}")

                if photo_path:
                    if not os.path.exists(photo_path):
                        logger.error(f"Photo {i} - FILE NOT FOUND: {photo_path}")
                        context[photo_key] = ""
                        context[caption_key] = ""
                    elif not self._is_valid_image(photo_path):
                        logger.error(f"Photo {i} - VALIDATION FAILED: {photo_path}")
                        context[photo_key] = ""
                        context[caption_key] = ""
                    else:
                        try:
                            logger.info(f"Creating InlineImage for photo {i}: {photo_path}")
                            context[photo_key] = InlineImage(
                                doc,
                                photo_path,
                                width=self.DEFAULT_IMAGE_WIDTH,
                                height=self.DEFAULT_IMAGE_HEIGHT
                            )
                            context[caption_key] = photo_data.get('caption', '')
                            logger.info(f"Photo {i} - SUCCESS: Added to document")
                        except Exception as e:
                            logger.error(f"Photo {i} - InlineImage creation FAILED ({type(e).__name__}): {e}")
                            logger.error(f"Photo path was: {photo_path}")
                            context[photo_key] = ""
                            context[caption_key] = ""
                else:
                    logger.info(f"Photo {i} - No path provided (empty slot)")
                    context[photo_key] = ""
                    context[caption_key] = ""
            else:
                logger.info(f"Photo {i} - Empty slot (no data)")
                context[photo_key] = ""
                context[caption_key] = ""
        
        # Handle table data - Placed Quantities
        # Pad lists with empty dicts to prevent index errors in templates
        context['placed_quantities'] = self._pad_list_with_empty_dicts(
            data.get('placed_quantities', [])
        )
        context['pqs'] = context['placed_quantities']  # Short alias for template
        
        # Handle table data - QA Entries
        context['qa_entries'] = self._pad_list_with_empty_dicts(
            data.get('qa_entries', [])
        )
        context['qas'] = context['qa_entries']  # Short alias for template
        
        # Handle table data - Equipment
        context['equipment_entries'] = self._pad_list_with_empty_dicts(
            data.get('equipment_entries', [])
        )
        context['eqs'] = context['equipment_entries']  # Short alias for template
        
        # Handle table data - Crew
        context['crew_entries'] = self._pad_list_with_empty_dicts(
            data.get('crew_entries', [])
        )
        context['crs'] = context['crew_entries']  # Short alias for template

        # Handle table data - Core Sample Locations
        raw_cores = data.get('core_locations', []) or []
        context['has_core_locations'] = len(raw_cores) > 0
        context['core_locations'] = self._pad_list_with_empty_dicts(raw_cores)
        context['cores'] = context['core_locations']  # Short alias for template

        # Core location lot-level metadata (from first core entry if available)
        if raw_cores:
            first = raw_cores[0]
            context['core_lot_number'] = first.get('lot_number', '')
            context['core_mix_type'] = first.get('mix_type', '')
            context['core_plant'] = first.get('plant', '')
            context['core_count'] = len(raw_cores)
            context['core_mat_count'] = sum(1 for c in raw_cores if c.get('core_type') == 'MAT')
            context['core_joint_count'] = sum(1 for c in raw_cores if c.get('core_type') == 'JOINT')

        return context


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Generate DOCX inspection reports from templates'
    )
    parser.add_argument(
        '--input', '-i',
        required=True,
        help='Path to JSON file with report data'
    )
    parser.add_argument(
        '--template', '-t',
        required=True,
        help='Path to DOCX template file'
    )
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Path for output DOCX file'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        # Load input data
        logger.info(f"Loading input data from: {args.input}")
        with open(args.input, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Create exporter and generate report
        exporter = ReportExporter(args.template, args.output)
        exporter.generate(data)
        
        print(args.output)  # Print output path for Rails to capture
        return 0
        
    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        return 1
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON: {e}")
        return 1
    except Exception as e:
        logger.error(f"Error generating report: {e}", exc_info=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
