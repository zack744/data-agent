from fastapi import FastAPI
from pydantic import BaseModel
# 导入各个工具函数和报告渲染功能
from .tools.fetch_bilibili import load_bilibili_data
from .tools.stat_summary import stat_summary
from .tools.title_generator import title_generator
from .report import render_markdown
from .config import get_settings

# 报告请求模型，定义API输入参数
class ReportRequest(BaseModel):
    topic: str  # 主题名称
    date: str | None = None  # 可选的日期参数

# 创建FastAPI应用实例
app = FastAPI()

# 健康检查接口
@app.get("/health")
def health():
    """返回API服务状态"""
    return {"ok": True}

# 生成报告接口
@app.post("/report")
def report(req: ReportRequest):
    """
    生成数据分析报告
    加载B站数据，进行统计汇总，生成标题建议，并输出Markdown报告
    """
    # 1. 加载B站热搜数据
    data = load_bilibili_data.invoke({"date": req.date})

    # 2. 对数据进行统计汇总
    summary = stat_summary.invoke({"records": data})

    # 3. 初始化标题列表
    titles: list[str] = []
    s = get_settings()

    # 4. 如果配置了OpenAI API密钥，则生成标题建议
    if s.OPENAI_API_KEY:
        titles = title_generator.invoke({"topic": req.topic, "context": "热搜选题"})

    # 5. 渲染Markdown格式的报告
    md = render_markdown(req.topic, summary, titles)

    # 6. 返回完整的报告数据
    return {"summary": summary, "titles": titles, "markdown": md}