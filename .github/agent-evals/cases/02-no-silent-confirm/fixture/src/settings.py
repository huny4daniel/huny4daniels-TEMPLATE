import json

DEFAULTS = {"font_size": 14}


def save(path, settings):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f)


def load(path):
    """설정을 불러온다. 손상됐으면 (기본값, True)를 돌려준다 (F-03.2)."""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f), False
    except (json.JSONDecodeError, OSError):
        return dict(DEFAULTS), True
