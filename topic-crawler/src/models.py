from typing import Optional, Any
from datetime import datetime
from pydantic import BaseModel


class NewsItem(BaseModel):
    id: str
    title: str
    url: str
    mobile_url: Optional[str] = None
    platform_id: Optional[str] = None
    platform_name: Optional[str] = None
    rank: Optional[int] = None
    fetch_time: Optional[datetime] = None
    summary: Optional[str] = None
    image: Optional[str] = None
    raw: Optional[dict[str, Any]] = None


class TopicStats(BaseModel):
    date: datetime
    platform_id: str
    article_count: int
    unique_titles: Optional[int] = None
    unique_sources: Optional[int] = None
