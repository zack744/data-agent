from typing import Any, Dict, List, Optional
from pydantic import BaseModel
from datetime import datetime

# 数据指标模型，存储各种统计数据
class Metrics(BaseModel):
    views: Optional[int] = None  # 播放量/浏览量
    like_rate: Optional[float] = None  # 点赞率
    work_count: Optional[int] = None  # 作品数量
    top_creator_ratio: Optional[float] = None  # 头部创作者占比
    published_at: Optional[datetime] = None  # 发布时间
    view_growth_24h: Optional[float] = None  # 24小时浏览量增长率
    keyword_freq: Optional[Dict[str, int]] = None  # 关键词频率统计

# 话题记录模型，代表一个热搜话题的完整信息
class TopicRecord(BaseModel):
    topic: str  # 话题名称
    platform: str  # 来源平台
    metrics: Metrics  # 指标数据
    raw: Optional[Dict[str, Any]] = None  # 原始数据