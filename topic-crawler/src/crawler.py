import asyncio
from typing import List, Optional, Tuple, Dict
from datetime import datetime, timezone
import re
import json
from bs4 import BeautifulSoup
import httpx
from .models import NewsItem


def _parse_datetime_str(s: str) -> Optional[datetime]:
    x = s.strip()
    if not x:
        return None
    if x.endswith("Z"):
        x = x[:-1] + "+00:00"
    fmts = [
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%d",
        "%Y/%m/%d %H:%M",
        "%Y/%m/%d",
    ]
    for f in fmts:
        try:
            dt = datetime.strptime(x, f)
            return dt.replace(tzinfo=dt.tzinfo or timezone.utc)
        except Exception:
            pass
    m = re.search(r"(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}:\d{2}|\d{2}:\d{2}))?", x)
    if m:
        ymd = m.group(1)
        hms = m.group(2) or "00:00:00"
        try:
            return datetime.strptime(f"{ymd} {hms}", "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
        except Exception:
            return None
    return None


def _extract_details(html: str) -> Tuple[Optional[datetime], Optional[str]]:
    soup = BeautifulSoup(html, "html.parser")
    summary = None
    for attrs in [
        {"property": "og:description"},
        {"name": "twitter:description"},
        {"name": "description"},
    ]:
        el = soup.find("meta", attrs=attrs)
        if el and el.get("content"):
            summary = el.get("content").strip()
            if summary:
                break
    dt = None
    for attrs in [
        {"property": "article:published_time"},
        {"property": "og:published_time"},
        {"property": "og:updated_time"},
        {"name": "pubdate"},
        {"name": "publish-date"},
        {"name": "parsely-pub-date"},
        {"itemprop": "datePublished"},
    ]:
        el = soup.find("meta", attrs=attrs)
        if el and el.get("content"):
            dt = _parse_datetime_str(el.get("content"))
            if dt:
                break
    if not dt:
        try:
            for sc in soup.find_all("script", attrs={"type": "application/ld+json"}):
                data = json.loads(sc.get_text(strip=True))
                if isinstance(data, dict):
                    val = data.get("datePublished") or data.get("dateCreated")
                    if isinstance(val, str):
                        dt = _parse_datetime_str(val)
                        if dt:
                            break
        except Exception:
            pass
    return dt, summary


async def fetch_newsnow_latest(platform_id: str, platform_name: Optional[str] = None, proxy_url: Optional[str] = None, retries: int = 2, max_details: int = 8) -> List[NewsItem]:
    if not platform_id:
        return []
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Connection": "keep-alive",
        "Cache-Control": "no-cache",
    }
    params = {"id": platform_id, "latest": ""}
    proxies = None
    if proxy_url:
        proxies = {"http": proxy_url, "https": proxy_url}

    attempt = 0
    data = None
    async with httpx.AsyncClient(timeout=15, proxies=proxies) as client:
        while attempt <= retries and data is None:
            try:
                resp = await client.get("https://newsnow.busiyi.world/api/s", params=params, headers=headers)
                resp.raise_for_status()
                j = resp.json()
                status = j.get("status", "")
                if status not in ("success", "cache"):
                    raise ValueError(f"bad status: {status}")
                data = j
            except Exception:
                attempt += 1
                if attempt > retries:
                    break
                await asyncio.sleep(3 + attempt)

    if not data:
        return []

    now = datetime.now(timezone.utc)
    items: List[NewsItem] = []
    for idx, it in enumerate(data.get("items", [])[:100], start=1):
        title = it.get("title")
        if title is None or isinstance(title, float) or not str(title).strip():
            continue
        title = str(title).strip()
        url = it.get("url") or ""
        mobile_url = it.get("mobileUrl") or None
        id_val = url or f"{platform_id}:{idx}:{abs(hash(title))}"
        items.append(NewsItem(
            id=id_val,
            title=title,
            url=url,
            mobile_url=mobile_url,
            platform_id=platform_id,
            platform_name=platform_name,
            rank=idx,
            fetch_time=now,
            raw=it if isinstance(it, dict) else None,
        ))
    if max_details > 0 and items:
        count = 0
        for it in items:
            if count >= max_details:
                break
            if not it.url.startswith("http"):
                continue
            try:
                r = await client.get(it.url, headers=headers)
                r.raise_for_status()
                dt, summ = _extract_details(r.text)
                if dt:
                    it.publish_time = dt
                if summ:
                    it.summary = summ
            except Exception:
                pass
            count += 1
    return items


async def fetch_newsnow_batch(platforms: List[Tuple[str, Optional[str]]], interval_ms: int = 1000, proxy_url: Optional[str] = None) -> Dict[str, List[NewsItem]]:
    results: Dict[str, List[NewsItem]] = {}
    for i, (pid, pname) in enumerate(platforms):
        items = await fetch_newsnow_latest(pid, pname, proxy_url)
        results[pid] = items
        if i < len(platforms) - 1:
            await asyncio.sleep(max(0.05, interval_ms / 1000))
    return results
