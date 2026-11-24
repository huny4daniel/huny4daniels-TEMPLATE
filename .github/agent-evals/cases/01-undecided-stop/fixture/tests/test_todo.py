import unittest
from datetime import date

from src.todo import sort_by_due


class TestSort(unittest.TestCase):
    def test_f01_1_due_ascending(self):  # F-01.1
        items = [{"t": "b", "due": date(2026, 3, 1)}, {"t": "a", "due": date(2026, 1, 1)}, {"t": "c", "due": date(2026, 2, 1)}]
        self.assertEqual([i["t"] for i in sort_by_due(items)], ["a", "c", "b"])

    def test_f01_2_no_due_last(self):  # F-01.2
        items = [{"t": "x", "due": None}, {"t": "a", "due": date(2026, 1, 1)}]
        self.assertEqual([i["t"] for i in sort_by_due(items)], ["a", "x"])


if __name__ == "__main__":
    unittest.main()
