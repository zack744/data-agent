import asyncio
from typing import List, Optional
from datetime import datetime, timezone
import httpx
import bilibili_api as b
from .models import TopicItem, HotTopic


def _parse_int(value: Optional[str]) -> Optional[int]:
    if value is None:
        return None
    s = str(value).strip()
    try:
        return int(float(s))
    except Exception:
        if s.endswith("万"):
            try:
                return int(float(s[:-1]) * 10000)
            except Exception:
                return None
        return None


def _to_datetime(ts: Optional[int]) -> Optional[datetime]:
    if ts is None:
        return None
    try:
        return datetime.fromtimestamp(int(ts), tz=timezone.utc)
    except Exception:
        return None


async def fetch_hot_topics(keyword: str, limit: int = 20) -> List[TopicItem]:
    if not keyword or limit <= 0:
        return []
    data = await b.search.search_by_type(
        keyword=keyword,
        search_type=b.search.SearchObjectType.VIDEO,
        page=1,
        page_size=max(1, limit),
    )
    results = data.get("result", [])
    items: List[TopicItem] = []
    for raw in results[:limit]:
        bvid = raw.get("bvid") or str(raw.get("aid")) if raw.get("aid") is not None else None
        title = raw.get("title") or ""
        author = raw.get("author") or raw.get("up_name")
        pubdate = raw.get("pubdate")
        views = _parse_int(raw.get("play"))
        likes = _parse_int(raw.get("like"))
        comments = _parse_int(raw.get("video_review") or raw.get("review"))
        like_rate = None
        if likes is not None and views is not None and views > 0:
            like_rate = round(likes / views, 6)
        item = TopicItem(
            id=bvid or "",
            platform="bilibili",
            keyword=keyword,
            title=title,
            author=author,
            publish_time=_to_datetime(pubdate),
            views=views,
            likes=likes,
            like_rate=like_rate,
            comments=comments,
            raw={"bvid": bvid} if bvid else None,
        )
        items.append(item)
    return items


async def fetch_hot_search(limit: int = 50) -> List[TopicItem]:
    if limit <= 0:
        return []
    data = await b.search.get_hot_search_keywords()
    candidates = []
    if isinstance(data, dict):
        if "list" in data and isinstance(data["list"], list):
            candidates = data["list"]
        elif "trending" in data and isinstance(data["trending"], dict):
            trending = data["trending"]
            if "list" in trending and isinstance(trending["list"], list):
                candidates = trending["list"]
            elif "rank_list" in trending and isinstance(trending["rank_list"], list):
                candidates = trending["rank_list"]
        elif "data" in data and isinstance(data["data"], dict):
            d = data["data"]
            if "list" in d and isinstance(d["list"], list):
                candidates = d["list"]
            elif "trending" in d and isinstance(d["trending"], dict):
                t = d["trending"]
                if "list" in t and isinstance(t["list"], list):
                    candidates = t["list"]
    items: List[TopicItem] = []
    for raw in candidates[:limit]:
        kw = raw.get("keyword") or raw.get("show_name") or raw.get("word") or raw.get("name") or ""
        if not kw:
            continue
        item = TopicItem(
            id=kw,
            keyword=kw,
            title=kw,
            raw=raw if isinstance(raw, dict) else None,
        )
        items.append(item)
    return items


async def fetch_bilibili_hot_topics(limit: int = 50) -> List[HotTopic]:
    if limit <= 0:
        return []
    url = "https://app.bilibili.com/x/v2/search/trending/ranking"
    headers = {
        "User-Agent": "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Mobile",
        "Accept": "application/json",
    }
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(url, headers=headers, params={"limit": max(1, min(limit, 100))})
        resp.raise_for_status()
        j = resp.json()
    data = j.get("data", {})
    lists: List[dict] = data.get("list", []) if isinstance(data, dict) else []
    if not lists:
        try:
            data2 = await b.search.get_hot_search_keywords()
            if isinstance(data2, dict):
                if "list" in data2 and isinstance(data2["list"], list):
                    lists = data2["list"]
                elif "data" in data2 and isinstance(data2["data"], dict):
                    d = data2["data"]
                    if "list" in d and isinstance(d["list"], list):
                        lists = d["list"]
                    elif "trending" in d and isinstance(d["trending"], dict):
                        t = d["trending"]
                        if "list" in t and isinstance(t["list"], list):
                            lists = t["list"]
        except Exception:
            pass
    items: List[HotTopic] = []
    for idx, raw in enumerate(lists[:limit], start=1):
        kw = raw.get("keyword") or raw.get("show_name") or raw.get("word") or raw.get("name") or ""
        if not kw:
            continue
        item = HotTopic(
            keyword=kw,
            rank=int(raw.get("position") or raw.get("pos") or idx),
            heat_value=(raw.get("heat_score") if isinstance(raw.get("heat_score"), int) else None),
            hot_id=(raw.get("hot_id") if isinstance(raw.get("hot_id"), int) else None),
            icon=raw.get("icon") or None,
        )
        items.append(item)
    return items


async def _keyword_stats(keyword: str, per: int) -> tuple[int, Optional[int]]:
    if per <= 0:
        return 0, None
    data = await b.search.search_by_type(
        keyword=keyword,
        search_type=b.search.SearchObjectType.VIDEO,
        page=1,
        page_size=per,
    )
    results = data.get("result", [])
    views = []
    for raw in results[:per]:
        v = _parse_int(raw.get("play"))
        if v is not None:
            views.append(v)
    count = len(results[:per])
    avg = None
    if views:
        avg = int(sum(views) / len(views))
    return count, avg


async def enrich_hot_topics_with_stats(items: List[HotTopic], per: int = 10, concurrency: int = 5) -> List[HotTopic]:
    if per <= 0 or not items:
        return items
    sem = asyncio.Semaphore(concurrency)
    async def run(item: HotTopic) -> None:
        async with sem:
            count, avg = await _keyword_stats(item.keyword, per)
            item.video_count = count
            item.avg_views = avg
    await asyncio.gather(*(run(i) for i in items))
    return items
