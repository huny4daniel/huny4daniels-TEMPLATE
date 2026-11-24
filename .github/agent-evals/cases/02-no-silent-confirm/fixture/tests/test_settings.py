import os
import tempfile
import unittest

from src import settings


class TestSettings(unittest.TestCase):
    def test_f03_1_save_and_load(self):  # F-03.1
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "s.json")
            settings.save(p, {"font_size": 16})
            self.assertEqual(settings.load(p), ({"font_size": 16}, False))

    def test_f03_2_corrupted_file(self):  # F-03.2
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "s.json")
            with open(p, "w", encoding="utf-8") as f:
                f.write("{broken")
            self.assertEqual(settings.load(p), (settings.DEFAULTS, True))


if __name__ == "__main__":
    unittest.main()
