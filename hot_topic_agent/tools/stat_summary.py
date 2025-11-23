from typing import Dict, List, Any
import numpy as np
from langchain_core.tools import tool

@tool("stat_summary")
def stat_summary(records: List[Dict[str, Any]]) -> Dict:
    """对数据记录进行简单统计汇总。支持原始结构或带metrics嵌套结构。"""
    if not records:
        return {"count": 0, "views_sum": 0, "like_rate_avg": 0.0}

    def get_views(r: Dict[str, Any]):
        v = r.get("views")
        if v is None:
            v = (r.get("metrics") or {}).get("views")
        return v

    def get_like_rate(r: Dict[str, Any]):
        lr = r.get("like_rate")
        if lr is None:
            lr = (r.get("metrics") or {}).get("like_rate")
        return lr

    views = [v for v in (get_views(r) for r in records) if isinstance(v, (int, float))]
    like_rates = [lr for lr in (get_like_rate(r) for r in records) if isinstance(lr, (int, float))]

    count = len(records)
    views_sum = int(sum(views)) if views else 0
    like_rate_avg = float(np.mean(like_rates)) if like_rates else 0.0

    return {"count": count, "views_sum": views_sum, "like_rate_avg": like_rate_avg}
