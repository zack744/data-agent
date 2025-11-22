from typing import List
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from ..config import get_settings

@tool("title_generator")
def title_generator(topic: str, context: str | None = None) -> List[str]:
    """
    标题生成工具
    基于指定主题和上下文，调用AI生成5个中文标题建议
    """
    s = get_settings()
    # 初始化OpenAI模型，使用较高温度值以获得更有创意的标题
    llm = ChatOpenAI(model=s.MODEL_NAME, api_key=s.OPENAI_API_KEY, base_url=s.OPENAI_BASE_URL, temperature=0.7)

    # 构建提示词，要求AI生成5个爆款中文标题
    prompt = f"根据主题{topic}生成5个可能爆款的中文标题。{context or ''}"

    # 调用AI模型生成标题
    msg = llm.invoke([HumanMessage(content=prompt)])
    text = msg.content or ""

    # 解析AI返回的内容，提取标题行
    lines = [x.strip("-• ") for x in text.splitlines() if x.strip()]

    # 如果没有找到标题行但有文本内容，将整个文本作为一个标题
    if not lines and text:
        lines = [text]

    # 最多返回5个标题
    return lines[:5]