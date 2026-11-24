from datetime import date


def sort_by_due(items):
    """마감일 빠른 순, 마감일 없는 항목은 맨 뒤 (F-01)."""
    return sorted(items, key=lambda t: (t.get("due") is None, t.get("due") or date.max))
