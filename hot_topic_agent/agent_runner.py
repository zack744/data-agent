from langchain_openai import ChatOpenAI
from langchain.agents import create_agent
from .config import get_settings
from .registry import get_tools

def build_agent():
    """
    构建LangChain智能体
    创建配置好工具和提示词的AI Agent实例
    """
    s = get_settings()
    # 初始化OpenAI聊天模型，使用配置中的API密钥和模型名称
    llm = ChatOpenAI(model=s.MODEL_NAME, api_key=s.OPENAI_API_KEY, base_url=s.OPENAI_BASE_URL, temperature=0)
    tools = get_tools()  # 获取可用的工具列表
    # 创建智能体，设置系统提示词为数据分析助手
    return create_agent(llm, tools=tools, system_prompt="你是数据分析助手，使用工具读取数据并生成选题建议。")

def run(input_text: str):
    """
    运行智能体
    输入文本并返回智能体的处理结果
    """
    agent = build_agent()
    return agent.invoke({"input": input_text})