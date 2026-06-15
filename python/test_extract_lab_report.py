#!/usr/bin/env python3
"""Dispatcher tests for lab report extraction."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

import extract_lab_report


class TestExtractLabReportDispatcher(unittest.TestCase):
    def test_p401_new_core_form_dispatches_to_asphalt_cores(self):
        payload, exit_code = extract_lab_report.run(
            _doc_path("P-401_05.20.2026_LOT-2SL1-3(PL)_AME_PASS_CORES.pdf"),
            "P-401",
        )

        self.assertEqual(exit_code, 0)
        self.assertEqual(payload["parser_used"], "ame_asphalt_cores")
        self.assertEqual(payload["result_kind"], "core_compaction")
        self.assertEqual(payload["row_count"], 6)

    def test_p401_hma_form_still_dispatches_to_hma_parser(self):
        payload, exit_code = extract_lab_report.run(
            _doc_path("P-401_04.15.2026_LOT-TS2(P)_AME_PASS_HMA.pdf"),
            "P-401",
        )

        self.assertEqual(exit_code, 0)
        self.assertEqual(payload["parser_used"], "ame_p401_hma")
        self.assertEqual(payload["result_kind"], "hma_air_voids")
        self.assertEqual(payload["row_count"], 3)


def _doc_path(filename):
    repo_root = os.path.dirname(os.path.dirname(__file__))
    return os.path.join(repo_root, "docs", filename)


if __name__ == "__main__":
    unittest.main()
