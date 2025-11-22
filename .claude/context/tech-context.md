---
created: 2025-11-22T10:23:42Z
last_updated: 2025-11-22T10:23:42Z
version: 1.0
author: Claude Code
---

# 技术上下文 (Technical Context)

## 开发环境
- **操作系统**：Windows
- **Python版本**：3.10+（推荐）
- **Git版本控制**：已初始化

## 依赖管理

### hot_topic_agent依赖（AI分析系统）
```txt
langchain              # LangChain核心框架
langchain-community    # LangChain社区组件
langchain-openai       # OpenAI集成
python-dotenv          # 环境变量管理
pydantic              # 数据验证
pandas                # 数据处理
numpy                 # 数值计算
tiktoken              # OpenAI分词器
fastapi               # Web API框架
uvicorn               # ASGI服务器
jinja2                # 模板引擎
```

### topic-crawler依赖（爬虫系统）
```txt
httpx==0.26.0                    # HTTP客户端
bilibili-api-python==16.3        # B站API
pydantic==2.8.2                  # 数据验证（固定版本）
uvloop==0.19.0; sys_platform != "win32"  # 高性能事件循环
pytest==8.3.0                    # 测试框架
```

## 核心配置文件

### .env.example
```env
OPENAI_API_KEY=your_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
MODEL_NAME=gpt-4o-mini
DATA_ROOT=./data/raw
```

### .gitignore
已配置全面的Python项目.gitignore，忽略：
- 虚拟环境（.venv）
- Python缓存（__pycache__）
- 环境变量（.env）
- 测试缓存（.pytest_cache）
- 数据文件（data/）
- IDE文件（.vscode/, .idea/）

## 关键API接口

### POST /report
生成热搜分析报告的FastAPI端点。

**请求体**：
```json
{
    "topic": "AI技术",
    "date": "2024-01-15"
}
```

**响应**：
```json
{
    "summary": {
        "count": 100,
        "views_sum": 1000000,
        "like_rate_avg": 0.05
    },
    "titles": ["标题1", "标题2", ...],
    "markdown": "# 分析报告..."
}
```

## 数据模型定义

### TopicItem（爬虫系统）
```python
{
    "id": str,              # 内容ID
    "platform": "bilibili", # 平台标识
    "keyword": str,         # 热搜关键词
    "title": str,          # 标题
    "author": str?,        # 作者
    "publish_time": datetime?,  # 发布时间
    "views": int?,         # 浏览量
    "likes": int?,         # 点赞数
    "like_rate": float?,   # 点赞率
    "comments": int?,      # 评论数
    "raw": dict?           # 原始API数据
}
```

### TopicRecord（分析系统）
```python
{
    "topic": str,          # 话题名称
    "platform": str,       # 来源平台
    "metrics": {           # 指标数据
        "views": int?,
        "like_rate": float?,
        "published_at": datetime?,
        "work_count": None,      # B站API无法获取
        "top_creator_ratio": None,  # B站API无法获取
        "view_growth_24h": None,    # B站API无法获取
        "keyword_freq": None,       # B站API无法获取
    },
    "raw": dict?          # 原始数据
}
```

## 适配器模式实现

### 核心适配函数
```python
def adapt_topic_item_to_analysis_format(crawler_item: Dict[str, Any]) -> Dict[str, Any]:
    """字段映射：keyword → topic, publish_time → published_at"""
    return {
        "topic": crawler_item.get("keyword", ""),
        "platform": crawler_item.get("platform", "bilibili"),
        "metrics": {
            "views": crawler_item.get("views"),
            "like_rate": crawler_item.get("like_rate"),
            "published_at": crawler_item.get("publish_time"),
            "work_count": None,      # 标记为不可用
            "top_creator_ratio": None,  # 标记为不可用
            "view_growth_24h": None,    # 标记为不可用
            "keyword_freq": None,       # 标记为不可用
        },
        "raw": crawler_item.get("raw") or crawler_item
    }
```

## 部署和运行

### 启动Web服务
```bash
cd hot_topic_agent
uvicorn app_api:app --reload --host 0.0.0.0 --port 8000
```

### 运行爬虫
```bash
cd topic-crawler
python cli.py crawl --keyword "测试关键词"
```

### 环境搭建
```bash
# 创建虚拟环境
python -m venv .venv

# 安装依赖
cd hot_topic_agent && pip install -r requirements.txt
cd topic-crawler && pip install -r requirements.txt
```