import os
from dotenv import load_dotenv
from pydantic import BaseModel

# 应用配置类，定义所有可配置的参数
class Settings(BaseModel):
    OPENAI_API_KEY: str | None = None  # OpenAI API密钥
    OPENAI_BASE_URL: str | None = None  # OpenAI API基础URL
    MODEL_NAME: str = "gpt-4o-mini"  # 默认使用的模型名称
    DATA_ROOT: str = os.path.join(os.getcwd(), "data", "raw")  # 数据存储根目录

_settings: Settings | None = None  # 全局设置实例，初始为None

def get_settings() -> Settings:
    """
    获取应用设置实例（单例模式）
    如果设置尚未加载，则从环境变量加载
    """
    global _settings
    if _settings is None:
        load_dotenv()  # 加载.env文件中的环境变量
        # 创建设置实例，从环境变量或默认值获取配置
        _settings = Settings(
            OPENAI_API_KEY=os.getenv("OPENAI_API_KEY"),
            OPENAI_BASE_URL=os.getenv("OPENAI_BASE_URL"),
            MODEL_NAME=os.getenv("MODEL_NAME", "gpt-4o-mini"),
            DATA_ROOT=os.getenv("DATA_ROOT", os.path.join(os.getcwd(), "data", "raw")),
        )
    return _settings