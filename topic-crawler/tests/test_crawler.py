import asyncio
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.models import TopicItem
from src.crawler_bili import fetch_hot_topics


def test_model_required_fields():
    item = TopicItem(id="BV123", platform="bilibili", keyword="k", title="t")
    assert item.id == "BV123"
    assert item.platform == "bilibili"
    assert item.keyword == "k"
    assert item.title == "t"


def test_empty_keyword_returns_empty():
    items = asyncio.run(fetch_hot_topics("", 10))
    assert items == []


def test_fetch_limit_one():
    try:
        items = asyncio.run(fetch_hot_topics("AI", 1))
    except Exception:
        pytest.skip("network")
    assert isinstance(items, list)
    assert len(items) <= 1
    if items:
        assert isinstance(items[0], TopicItem)
