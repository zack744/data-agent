# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述 (Project Overview)

这是一个**智能选题决策与分析报告生成平台**（代号：Topic Agent），基于AI Agent和LangChain构建的热搜数据分析系统。项目包含两个核心模块：

1. **hot_topic_agent** - 基于LangChain的AI数据分析系统
2. **topic-crawler** - B站热搜数据爬虫系统

### 核心特性
- 🤖 AI驱动的数据分析（LangChain + OpenAI）
- 📊 热搜数据采集与分析
- 📝 自动生成Markdown分析报告
- 🔄 适配器模式实现数据源解耦
- 🌐 FastAPI Web服务接口

---

## 系统架构 (Architecture)

### 整体架构
```
┌─────────────────────────────┐
│      客户端/前端界面           │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│         FastAPI Web服务               │
│      (app_api.py - /report)         │
└────────────┬────────────────────────┘
             │
             ▼
    ┌──────────────────────┐
    │   LangChain Agent     │
    │   (agent_runner.py)   │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │  工具集 (Tools)       │
    │  - 数据加载           │
    │  - 统计汇总           │
    │  - 标题生成           │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │   适配器层            │
    │ (fetch_bilibili.py)   │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │   数据源             │
    │ - 爬虫系统 (JSON)     │
    │ - B站API             │
    └──────────────────────┘
```

---

## 模块详解 (Modules)

### 1. hot_topic_agent - AI分析系统

**职责**：基于LangChain构建的AI智能体，负责任务调度、数据分析和报告生成。

#### 核心文件说明

| 文件 | 功能 | 重要性 |
|------|------|--------|
| `config.py` | 配置管理（环境变量、API密钥等） | ⭐⭐⭐ |
| `registry.py` | 工具注册中心（注册所有LangChain Tools） | ⭐⭐⭐ |
| `agent_runner.py` | Agent构建与运行引擎 | ⭐⭐⭐ |
| `app_api.py` | FastAPI Web服务，提供`/report`接口 | ⭐⭐⭐ |
| `protocol/types.py` | 数据模型定义（Metrics、TopicRecord） | ⭐⭐ |
| `tools/fetch_bilibili.py` | **数据加载工具 + 适配器**（⭐关键设计） | ⭐⭐⭐ |
| `tools/stat_summary.py` | 数据统计工具（计算count、views、like_rate） | ⭐⭐ |
| `tools/title_generator.py` | AI标题生成工具（调用OpenAI） | ⭐⭐ |
| `report.py` | Markdown报告模板渲染（Jinja2） | ⭐⭐ |

#### 数据流向
```python
load_bilibili_data() → adapt_crawler_data() → stat_summary() → title_generator() → render_markdown()
```

### 2. topic-crawler - 爬虫系统

**职责**：采集B站热搜数据，输出标准化的JSON格式。

#### 核心文件说明

| 文件 | 功能 | 重要性 |
|------|------|--------|
| `src/models.py` | 数据模型定义（TopicItem、HotTopic） | ⭐⭐⭐ |
| `src/crawler.py` | 爬虫核心逻辑 | ⭐⭐⭐ |
| `cli.py` | 命令行入口，调度爬虫任务 | ⭐⭐ |

#### 数据模型 (TopicItem)
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

---

## 关键设计模式 (Key Design Patterns)

### 适配器模式 (Adapter Pattern) - 重点关注

**位置**：`hot_topic_agent/tools/fetch_bilibili.py`

**作用**：将爬虫系统的`TopicItem`数据格式适配为分析系统需要的`TopicRecord`格式。

**核心函数**：
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
            # B站API无法获取的字段设为None
            "work_count": None,
            "top_creator_ratio": None,
            "view_growth_24h": None,
            "keyword_freq": None,
        },
        "raw": crawler_item.get("raw") or crawler_item
    }
```

**设计优势**：
- ✅ **解耦**：爬虫和分析系统独立演进
- ✅ **兼容**：保留`raw`字段存储原始数据
- ✅ **扩展**：可轻松添加新字段映射
- ✅ **清晰**：明确标识哪些字段可用/不可用

---

## 开发指南 (Development Guide)

### 环境准备

1. **创建虚拟环境**
```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
source .venv/bin/activate  # Linux/Mac
```

2. **安装依赖**
```bash
# 安装AI分析系统依赖
cd hot_topic_agent
pip install -r requirements.txt

# 安装爬虫系统依赖（另一个终端）
cd topic-crawler
pip install -r requirements.txt
```

3. **配置环境变量**
```bash
# 复制并编辑环境变量文件
cp .env.example .env
```

在`.env`中添加：
```env
OPENAI_API_KEY=your_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
MODEL_NAME=gpt-4o-mini
DATA_ROOT=./data/raw
```

### 常用开发命令

#### hot_topic_agent模块
```bash
# 启动FastAPI服务
cd hot_topic_agent
uvicorn app_api:app --reload --host 0.0.0.0 --port 8000

# 测试API接口
curl -X POST http://localhost:8000/report \
  -H "Content-Type: application/json" \
  -d '{"topic": "测试话题", "date": "2024-01-15"}'

# 运行LangChain Agent
cd hot_topic_agent
python -c "from agent_runner import run; print(run('分析B站热门话题'))"
```

#### topic-crawler模块
```bash
# 运行爬虫
cd topic-crawler
python cli.py crawl --keyword "测试关键词"

# 运行测试
cd topic-crawler
pytest tests/test_crawler.py -v
```

### 数据流测试

1. **完整流程测试**
```bash
# 1. 运行爬虫采集数据
cd topic-crawler
python cli.py crawl --keyword "AI技术"

# 2. 启动分析服务
cd hot_topic_agent
uvicorn app_api:app --reload

# 3. 调用API生成报告
curl -X POST http://localhost:8000/report \
  -H "Content-Type: application/json" \
  -d '{"topic": "AI技术"}'
```

---

## 项目配置说明 (Configuration)

### 数据存储结构
```
data/
└── raw/
    └── bilibili/
        ├── 2024-01-15.json  # 按日期存储的爬虫数据
        ├── 2024-01-14.json
        └── ...
```

### 环境变量配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `OPENAI_API_KEY` | OpenAI API密钥 | 无 |
| `OPENAI_BASE_URL` | OpenAI API基础URL | https://api.openai.com/v1 |
| `MODEL_NAME` | 使用的模型名称 | gpt-4o-mini |
| `DATA_ROOT` | 数据存储根目录 | ./data/raw |

---

## 核心工作流程 (Workflow)

### 完整数据分析流程

1. **数据采集** (topic-crawler)
   - 爬虫采集B站热搜数据
   - 输出JSON文件到`data/raw/bilibili/{date}.json`

2. **数据适配** (fetch_bilibili.py)
   - 加载爬虫JSON数据
   - 通过适配器转换为标准格式

3. **数据分析** (stat_summary.py)
   - 统计记录数量
   - 计算总浏览量和平均点赞率

4. **AI增强** (title_generator.py)
   - 基于主题生成爆款标题建议
   - 调用OpenAI模型生成创意内容

5. **报告生成** (report.py)
   - 使用Jinja2模板渲染Markdown报告
   - 返回结构化分析结果

### API接口使用

#### POST /report
生成热搜分析报告。

**请求体**：
```json
{
    "topic": "AI技术",        // 分析主题
    "date": "2024-01-15"     // 可选，指定日期
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
    "titles": [
        "5个AI技术趋势，不看后悔！",
        ...
    ],
    "markdown": "# AI技术分析报告\n..."
}
```

---

## 扩展指南 (Extension Guide)

### 添加新数据源

1. **在`fetch_bilibili.py`中添加新适配器**
```python
def adapt_new_source_data(raw_data: List[Dict]) -> List[Dict]:
    """适配新的数据源"""
    return [adapt_single_item(item) for item in raw_data]
```

2. **在`registry.py`中注册新工具**
```python
def get_tools() -> List[BaseTool]:
    return [
        load_bilibili_data,
        load_new_source_data,  # 新工具
        stat_summary,
        title_generator
    ]
```

### 添加新分析指标

1. **修改`protocol/types.py`中的Metrics类**
```python
class Metrics(BaseModel):
    views: Optional[int] = None
    like_rate: Optional[float] = None
    new_metric: Optional[float] = None  # 新指标
```

2. **在相应工具中计算新指标**
```python
def calculate_new_metric(records: List[Dict]) -> float:
    # 计算逻辑
    pass
```

---

## 测试指南 (Testing)

### 运行测试
```bash
# 运行爬虫系统测试
cd topic-crawler
pytest tests/ -v

# 测试数据适配器
cd hot_topic_agent
python -c "
from tools.fetch_bilibili import adapt_crawler_data
test_data = [{'keyword': 'test', 'views': 1000}]
result = adapt_crawler_data(test_data)
print(result)
"
```

### 模拟数据测试
```python
# 创建模拟数据进行完整流程测试
mock_crawler_data = [
    {
        "keyword": "测试话题",
        "platform": "bilibili",
        "title": "测试视频",
        "views": 100000,
        "like_rate": 0.05,
        "publish_time": "2024-01-15T10:30:00"
    }
]

# 测试适配器
adapted = adapt_crawler_data(mock_crawler_data)
print(adapted)
```

---

## 故障排除 (Troubleshooting)

### 常见问题

1. **数据加载失败**
   - 检查`data/raw/bilibili/`目录是否存在
   - 确认JSON文件格式正确
   - 验证文件权限

2. **OpenAI API调用失败**
   - 验证`OPENAI_API_KEY`是否正确配置
   - 检查网络连接和API配额
   - 确认`OPENAI_BASE_URL`可访问

3. **适配器字段映射错误**
   - 对比`TopicItem`和`TopicRecord`字段名
   - 检查`adapt_topic_item_to_analysis_format`函数
   - 验证数据转换逻辑

4. **模板渲染失败**
   - 确认`templates/report.md.jinja`文件存在
   - 检查Jinja2模板语法
   - 验证模板变量传递

---

## 项目依赖 (Dependencies)

### hot_topic_agent依赖
- **LangChain生态**：langchain, langchain-community, langchain-openai
- **数据处理**：pandas, numpy
- **Web服务**：fastapi, uvicorn
- **工具类**：python-dotenv, pydantic, jinja2

### topic-crawler依赖
- **HTTP客户端**：httpx
- **B站API**：bilibili-api-python
- **数据验证**：pydantic
- **测试**：pytest

---

## 重要提醒 (Important Notes)

1. **数据兼容性**：通过适配器模式，爬虫系统可以独立升级，不影响分析系统
2. **环境变量**：所有API密钥必须通过`.env`文件管理，绝不硬编码
3. **版本控制**：已配置`.gitignore`，自动忽略虚拟环境、缓存和敏感文件
4. **模块解耦**：两个子系统独立开发、测试和部署
5. **扩展性**：新功能通过工具注册机制轻松集成

---

## 参考资料 (References)

- **项目PRD**：查看`prd.md`了解完整需求
- **LangChain文档**：https://python.langchain.com/
- **FastAPI文档**：https://fastapi.tiangolo.com/
- **Pydantic文档**：https://docs.pydantic.dev/