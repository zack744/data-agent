from typing import Dict, List
import pandas as pd
import numpy as np
from langchain_core.tools import tool

@tool("stat_summary")
def stat_summary(records: List[Dict]) -> Dict:
    """
    统计数据汇总工具
    对数据记录列表进行简单的统计计算（数量、总浏览量、平均点赞率）
    """
    # 如果记录为空，返回默认统计值
    if not records:
        return {"count": 0, "views_sum": 0, "like_rate_avg": 0.0}

    # 将数据转换为DataFrame以便进行数据处理
    df = pd.DataFrame(records)
    count = len(df)  # 记录总数

    # 计算总浏览量（如果数据中存在views字段）
    views_sum = int(df["views"].sum()) if "views" in df.columns else 0

    # 计算平均点赞率（如果数据中存在like_rate字段）
    like_rate_avg = float(np.mean(df["like_rate"])) if "like_rate" in df.columns else 0.0

    return {"count": count, "views_sum": views_sum, "like_rate_avg": like_rate_avg}