import asyncio
from typing import List, Optional
from datetime import datetime, timezone
import httpx
import bilibili_api as b
from .models import TopicItem, HotTopic


def _parse_int(value: Optional[str]) -> Optional[int]:
    """
    将字符串数值转换为整数，支持中文"万"单位转换
    例如：'123万' -> 1230000
    """
    if value is None:
        return None
    s = str(value).strip()
    try:
        return int(float(s))
    except Exception:
        # 如果是中文"万"单位，转换为实际数值
        if s.endswith("万"):
            try:
                return int(float(s[:-1]) * 10000)
            except Exception:
                return None
        return None

# 功能：解析数值字符串为整数，兼容中文“万”；模块：crawler.py


def _to_datetime(ts: Optional[int]) -> Optional[datetime]:
    """
    将时间戳（秒）转换为 UTC 时间格式
    例如：1692123456 -> 2023-08-16 04:37:36+00:00
    """
    if ts is None:
        return None
    try:
        # 将时间戳转换为UTC时间对象
        return datetime.fromtimestamp(int(ts), tz=timezone.utc)
    except Exception:
        return None

# 功能：将时间戳转换为 UTC 时间；模块：crawler.py

# 特定话题的热门
async def fetch_hot_topics(keyword: str, limit: int = 20) -> List[TopicItem]:
    """
    根据关键词搜索B站视频并返回热门视频数据

    参数:
        keyword: 搜索关键词（例如：'Python教程', '原神'）
        limit: 返回视频数量，默认20个

    返回:
        List[TopicItem]: 视频信息列表，包含标题、作者、播放量、点赞数等
    """
    # 检查输入参数有效性
    if not keyword:
        return []
    if limit <= 0:
        return []

    # 调用B站搜索API，搜索视频类型内容
    # search_by_type 是 bilibili_api 库提供的搜索接口
    data = await b.search.search_by_type(
        keyword=keyword,  # 搜索关键词
        search_type=b.search.SearchObjectType.VIDEO,  # 只搜索视频
        page=1,  # 第1页
        page_size=max(1, limit),  # 每页数量，最少1个
    )

    # 从返回结果中提取视频列表
    results = data.get("result", [])
    items: List[TopicItem] = []

    # 遍历搜索结果，处理每个视频数据
    for raw in results[:limit]:
        # 提取视频ID：BVID优先，否则使用AV号
        bvid = raw.get("bvid") or str(raw.get("aid")) if raw.get("aid") is not None else None

        # 提取基本信息
        title = raw.get("title") or ""  # 视频标题
        author = raw.get("author") or raw.get("up_name")  # UP主名称

        # 发布时间（时间戳）
        pubdate = raw.get("pubdate")

        # 解析互动数据（播放量、点赞数、评论数）
        # B站可能返回"123万"这样的中文格式，需要特殊处理
        views = _parse_int(raw.get("play"))  # 播放量
        likes = _parse_int(raw.get("like"))  # 点赞数
        comments = _parse_int(raw.get("video_review") or raw.get("review"))  # 评论数

        # 计算点赞率（点赞数 / 播放量）
        like_rate = None
        if likes is not None and views is not None and views > 0:
            like_rate = round(likes / views, 6)

        # 创建TopicItem对象，存储视频信息
        item = TopicItem(
            id=bvid or "",  # 视频ID
            platform="bilibili",  # 来源平台
            keyword=keyword,  # 搜索关键词
            title=title,  # 标题
            author=author,  # 作者
            publish_time=_to_datetime(pubdate),  # 发布时间
            views=views,  # 播放量
            likes=likes,  # 点赞数
            like_rate=like_rate,  # 点赞率
            comments=comments,  # 评论数
            raw={"bvid": bvid} if bvid else None,  # 原始数据
        )
        items.append(item)

    return items

# 热搜榜单的数据
async def fetch_hot_search(limit: int = 50) -> List[TopicItem]:
    """
    获取B站热搜榜单数据

    参数:
        limit: 返回热搜数量，默认50个

    返回:
        List[TopicItem]: 热搜关键词列表
    """
    if limit <= 0:
        return []

    # 获取B站热搜关键词
    data = await b.search.get_hot_search_keywords()

    # B站热搜数据可能有多种不同的返回格式，需要兼容处理
    # 可能的格式：{'list': [...]}, {'trending': {'list': [...]}}, {'data': {'list': [...]}}
    candidates = []
    if isinstance(data, dict):
        # 尝试不同的数据结构
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

    # 处理热搜关键词数据
    for raw in candidates[:limit]:
        # 热搜关键词可能有多个字段名，尝试多种可能
        kw = raw.get("keyword") or raw.get("show_name") or raw.get("word") or raw.get("name") or ""
        if not kw:
            continue

        title = kw

        # 创建TopicItem对象
        item = TopicItem(
            id=kw,  # 关键词作为ID
            keyword=kw,  # 搜索关键词
            title=title,  # 标题（这里也是关键词）
            raw=raw if isinstance(raw, dict) else None,  # 原始数据
        )
        items.append(item)

    return items

async def fetch_bilibili_hot_topics(limit: int = 50) -> List[HotTopic]:
    """
    获取B站热搜榜单详细信息（包含排名、热度值等）

    参数:
        limit: 返回热搜数量，默认50个

    返回:
        List[HotTopic]: 热搜详细信息列表，包含排名、热度值、图标等
    """
    if limit <= 0:
        return []

    # 优先使用移动端热搜接口，支持 limit（最大100）
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
    # 如果移动端接口异常或为空，再回退到库方法
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

    # 处理热搜数据，提取详细信息
    for idx, raw in enumerate(lists[:limit], start=1):
        # 提取热搜关键词
        kw = raw.get("keyword") or raw.get("show_name") or raw.get("word") or raw.get("name") or ""
        if not kw:
            continue

        # 创建HotTopic对象，包含更详细的热搜信息
        item = HotTopic(
            keyword=kw,  # 热搜关键词
            rank=int(raw.get("position") or raw.get("pos") or idx),  # 排名位置
            # 热度值（数值类型），可能不是数字则设为None
            heat_value=(raw.get("heat_score") if isinstance(raw.get("heat_score"), int) else None),
            # 热搜ID（数值类型），可能不是数字则设为None
            hot_id=(raw.get("hot_id") if isinstance(raw.get("hot_id"), int) else None),
            icon=raw.get("icon") or None,  # 热搜图标URL
        )
        items.append(item)

    return items

async def _keyword_stats(keyword: str, per: int) -> tuple[int, Optional[int]]:
    """
    计算指定关键词的视频统计信息

    参数:
        keyword: 搜索关键词
        per: 搜索数量限制

    返回:
        tuple[int, Optional[int]]: (搜索到的视频数量, 平均播放量)
    """
    if per <= 0:
        return 0, None

    # 搜索指定关键词的视频
    data = await b.search.search_by_type(
        keyword=keyword,
        search_type=b.search.SearchObjectType.VIDEO,
        page=1,
        page_size=per,
    )

    results = data.get("result", [])
    views = []

    # 提取所有视频的播放量数据
    for raw in results[:per]:
        v = _parse_int(raw.get("play"))
        if v is not None:
            views.append(v)  # 只保存有效的播放量数据

    # 计算统计信息
    count = len(results[:per])  # 实际搜索到的视频数量
    avg = None
    if views:  # 如果有播放量数据
        avg = int(sum(views) / len(views))  # 计算平均播放量

    return count, avg

async def enrich_hot_topics_with_stats(items: List[HotTopic], per: int = 10, concurrency: int = 5) -> List[HotTopic]:
    """
    为热搜话题添加详细的视频统计信息

    参数:
        items: 热搜话题列表
        per: 每个话题搜索的视频数量，默认10个
        concurrency: 并发数量限制，默认5个

    返回:
        List[HotTopic]: 增强后的热搜话题列表（包含video_count和avg_views字段）
    """
    if per <= 0 or not items:
        return items

    # 创建信号量，限制同时进行的并发请求数量，避免过多请求导致被限制
    sem = asyncio.Semaphore(concurrency)

    async def run(item: HotTopic) -> None:
        """为单个热搜项获取统计信息"""
        async with sem:  # 使用信号量控制并发
            count, avg = await _keyword_stats(item.keyword, per)
            item.video_count = count  # 视频数量
            item.avg_views = avg  # 平均播放量

    # 并发执行所有热搜项的统计任务
    await asyncio.gather(*(run(i) for i in items))
    return items

# 功能：异步抓取 B 站搜索结果并映射为 TopicItem 列表；模块：crawler.py