import asyncio
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.models import NewsItem
from src.crawler import fetch_newsnow_latest


def test_model_required_fields():
    item = NewsItem(id="id1", title="t", url="https://example.com")
    assert item.id == "id1"
    assert item.title == "t"
    assert item.url == "https://example.com"


def test_empty_platform_returns_empty():
    items = asyncio.run(fetch_newsnow_latest(""))
    assert items == []


def test_fetch_platform_toutiao():
    try:
        items = asyncio.run(fetch_newsnow_latest("toutiao", "今日头条"))
    except Exception:
        pytest.skip("network")
    assert isinstance(items, list)
    assert all(isinstance(i, NewsItem) for i in items)
    if items:
        assert items[0].rank == 1
