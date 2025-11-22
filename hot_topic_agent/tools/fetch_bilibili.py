import os
import json
from typing import List, Dict, Any
from langchain_core.tools import tool
from ..config import get_settings

def adapt_topic_item_to_analysis_format(crawler_item: Dict[str, Any]) -> Dict[str, Any]:
    """
    将爬虫系统的TopicItem数据适配成分析系统需要的格式
    负责字段映射和数据类型转换
    """
    return {
        "topic": crawler_item.get("keyword", ""),  # keyword -> topic
        "platform": crawler_item.get("platform", "bilibili"),  # platform
        "metrics": {
            "views": crawler_item.get("views"),  # 浏览量
            "like_rate": crawler_item.get("like_rate"),  # 点赞率
            "published_at": crawler_item.get("publish_time"),  # 发布时间
            # 以下字段B站API无法直接获取，保持为None
            "work_count": None,
            "top_creator_ratio": None,
            "view_growth_24h": None,
            "keyword_freq": None,
        },
        "raw": crawler_item.get("raw") or crawler_item  # 保留原始数据
    }

def adapt_crawler_data(crawler_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    批量适配函数
    将爬虫系统的TopicItem列表转换为分析系统需要的格式
    """
    if not crawler_data:
        return []

    return [adapt_topic_item_to_analysis_format(item) for item in crawler_data]

@tool("load_bilibili_data")
def load_bilibili_data(date: str | None = None) -> List[Dict]:
    """
    加载B站热搜数据工具（带适配器版本）
    1. 从本地存储加载爬虫系统输出的JSON数据
    2. 通过适配器转换成分析系统需要的格式
    3. 返回标准化的数据列表
    """
    s = get_settings()
    base = os.path.join(s.DATA_ROOT, "bilibili")  # 构建B站数据目录路径

    # 如果数据目录不存在，返回空列表
    if not os.path.isdir(base):
        return []

    # 如果指定了日期，尝试加载指定日期的数据
    if date:
        path = os.path.join(base, f"{date}.json")
        # 如果指定日期的文件不存在，返回空列表
        if not os.path.exists(path):
            return []
        # 读取爬虫原始数据（TopicItem格式）
        with open(path, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    else:
        # 未指定日期时，加载最新的数据
        files = [fn for fn in os.listdir(base) if fn.endswith(".json")]
        if not files:
            return []
        # 按修改时间排序，获取最新的文件
        files.sort(key=lambda fn: os.path.getmtime(os.path.join(base, fn)), reverse=True)
        target = os.path.join(base, files[0])
        # 读取最新文件的数据
        with open(target, "r", encoding="utf-8") as f:
            raw_data = json.load(f)

    # 通过适配器将爬虫数据转换为分析系统格式
    return adapt_crawler_data(raw_data)