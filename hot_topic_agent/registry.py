from typing import List
from langchain_core.tools import BaseTool
# 导入三个LangChain工具函数
from .tools.fetch_bilibili import load_bilibili_data
from .tools.stat_summary import stat_summary
from .tools.title_generator import title_generator

def get_tools() -> List[BaseTool]:
    """
    获取所有可用的LangChain工具列表
    注册Agent可以使用的所有工具函数
    """
    return [load_bilibili_data, stat_summary, title_generator]