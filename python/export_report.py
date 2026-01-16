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
from docx.shared import Mm
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


class ReportExporter:
    """Handles generation of DOCX reports from templates and JSON data."""
    
    PHOTO_SLOT_COUNT = 6
    DEFAULT_IMAGE_WIDTH = Mm(120)  # 120mm wide images
    
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
            # The most reliable test is to actually try loading it with python-docx
            from docx.image.image import Image as DocxImage
            DocxImage.from_file(photo_path)
            return True
        except Exception as e:
            logger.warning(f"Image incompatible with python-docx: {e}")
            return False
    
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
        for key, value in data.items():
            if key != 'photos' and key != 'placed_quantities' and key != 'qa_entries' \
               and key != 'equipment_entries' and key != 'crew_entries':
                context[key] = value or ""
        
        # Handle photo placeholders
        photos = data.get('photos', []) or []  # Handle None
        for i in range(1, self.PHOTO_SLOT_COUNT + 1):
            photo_key = f'photo_{i}'
            caption_key = f'caption_{i}'
            
            if i <= len(photos) and photos[i-1]:
                photo_data = photos[i-1]
                photo_path = photo_data.get('path')
                
                if photo_path and os.path.exists(photo_path) and self._is_valid_image(photo_path):
                    try:
                        logger.info(f"Adding photo {i}: {photo_path}")
                        context[photo_key] = InlineImage(
                            doc, 
                            photo_path, 
                            width=self.DEFAULT_IMAGE_WIDTH
                        )
                        context[caption_key] = photo_data.get('caption', '')
                    except Exception as e:
                        logger.warning(f"Skipping photo {i} - could not process ({type(e).__name__}): {photo_path}")
                        context[photo_key] = ""
                        context[caption_key] = ""
                else:
                    if photo_path:
                        logger.warning(f"Skipping photo {i} - invalid or unsupported image: {photo_path}")
                    context[photo_key] = ""
                    context[caption_key] = ""
            else:
                context[photo_key] = ""
                context[caption_key] = ""
        
        # Handle table data - Placed Quantities
        context['placed_quantities'] = data.get('placed_quantities', []) or []
        context['pqs'] = context['placed_quantities']  # Short alias for template
        
        # Handle table data - QA Entries
        context['qa_entries'] = data.get('qa_entries', []) or []
        context['qas'] = context['qa_entries']  # Short alias for template
        
        # Handle table data - Equipment
        context['equipment_entries'] = data.get('equipment_entries', []) or []
        context['eqs'] = context['equipment_entries']  # Short alias for template
        
        # Handle table data - Crew
        context['crew_entries'] = data.get('crew_entries', []) or []
        context['crs'] = context['crew_entries']  # Short alias for template
        
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
