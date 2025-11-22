from typing import Dict, List
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

def render_markdown(topic: str, summary: Dict, titles: List[str]) -> str:
    """
    渲染Markdown报告模板
    使用Jinja2模板引擎，将数据渲染成Markdown格式的报告
    """
    # 构建模板文件目录路径
    base = os.path.join(os.path.dirname(__file__), "templates")

    # 创建Jinja2环境，配置模板加载器和自动转义
    env = Environment(loader=FileSystemLoader(base), autoescape=select_autoescape())

    # 获取报告模板
    tpl = env.get_template("report.md.jinja")

    # 渲染模板，传入数据并返回最终的Markdown字符串
    return tpl.render(topic=topic, summary=summary, titles=titles)