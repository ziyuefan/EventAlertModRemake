import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


os.environ["EAM_DOCS_OFFLINE"] = "1"
GOVERNANCE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONVERTER_PATH = GOVERNANCE_ROOT / "Tools" / "batch_convert_docs.py"
SPEC = importlib.util.spec_from_file_location("batch_convert_docs", CONVERTER_PATH)
CONVERTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONVERTER)


class BatchConvertDocsTests(unittest.TestCase):
    def setUp(self):
        self.previous_offline_mode = CONVERTER.OFFLINE_MODE
        CONVERTER.OFFLINE_MODE = True

    def tearDown(self):
        CONVERTER.OFFLINE_MODE = self.previous_offline_mode

    def test_external_github_markdown_link_is_unchanged(self):
        source = (
            '<a href="https://github.com/ziyuefan/EventAlertModRemake/'
            'blob/main/.AI/Docs/26_FLOW_VALIDATION_FRAMEWORK.md">Docs</a>'
        )
        self.assertEqual(CONVERTER.rewrite_local_markdown_links(source), source)

    def test_local_markdown_links_are_flattened_and_keep_fragment(self):
        source = (
            '<a href="Docs/26_FLOW_VALIDATION_FRAMEWORK.md#驗證">Docs</a>'
            '<a href="../README.md#命令列">README</a>'
        )
        converted = CONVERTER.rewrite_local_markdown_links(source)
        self.assertIn(
            'href="26_FLOW_VALIDATION_FRAMEWORK.md.html#驗證"',
            converted,
        )
        self.assertIn('href="README.md.html#命令列"', converted)

    def test_offline_translation_reports_unavailable(self):
        self.assertIsNone(CONVERTER.translate_via_google_api("需要翻譯"))

    def test_offline_conversion_does_not_duplicate_source_content(self):
        unique_line = "unique-validation-line-20260729"
        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "README.md"
            output_dir = Path(temp_dir) / "html"
            output_dir.mkdir()
            source_path.write_text(
                f"# 離線文件\n\n{unique_line}\n",
                encoding="utf-8",
            )

            self.assertTrue(
                CONVERTER.convert_to_html(
                    str(source_path),
                    str(output_dir),
                    force_convert=True,
                )
            )
            generated = (output_dir / "README.md.html").read_text(encoding="utf-8")

        self.assertEqual(generated.count(unique_line), 1)
        self.assertIn("English Version Offline", generated)


if __name__ == "__main__":
    unittest.main()
