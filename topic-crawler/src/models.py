from typing import Optional, Literal, Any
from datetime import datetime
from pydantic import BaseModel


class TopicItem(BaseModel):
    id: str
    platform: Literal["bilibili"] = "bilibili"
    keyword: str
    title: str
    author: Optional[str] = None
    publish_time: Optional[datetime] = None
    views: Optional[int] = None
    likes: Optional[int] = None
    like_rate: Optional[float] = None
    comments: Optional[int] = None
    raw: Optional[dict[str, Any]] = None


class HotTopic(BaseModel):
    keyword: str
    rank: int
    heat_value: Optional[int] = None
    hot_id: Optional[int] = None
    icon: Optional[str] = None
    video_count: Optional[int] = None
    avg_views: Optional[int] = None
