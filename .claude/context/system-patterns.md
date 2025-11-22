---
created: 2025-11-22T10:34:40Z
last_updated: 2025-11-22T10:34:40Z
version: 1.0
author: Claude Code PM System
---

# 系统模式 (System Patterns)

## 架构风格
**分层架构 + 适配器模式**

项目采用清晰的分层架构，将数据采集、分析和报告生成分离为独立模块，通过适配器模式实现数据源解耦。

## 核心设计模式

### 1. 适配器模式 (Adapter Pattern) - 最重要
**位置**：`hot_topic_agent/tools/fetch_bilibili.py`

**用途**：将爬虫系统的`TopicItem`数据格式转换为分析系统需要的`TopicRecord`格式

**实现**：
```python
def adapt_topic_item_to_analysis_format(crawler_item: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "topic": crawler_item.get("keyword", ""),
        "platform": crawler_item.get("platform", "bilibili"),
        "metrics": {
            "views": crawler_item.get("views"),
            "like_rate": crawler_item.get("like_rate"),
            "published_at": crawler_item.get("publish_time"),
            "work_count": None,      # B站API无法获取
            "top_creator_ratio": None,  # B站API无法获取
            "view_growth_24h": None,    # B站API无法获取
            "keyword_freq": None,       # B站API无法获取
        },
        "raw": crawler_item.get("raw") or crawler_item
    }
```

**优势**：
- 解耦：爬虫和分析系统独立演进
- 兼容：保留raw字段存储原始数据
- 扩展：可轻松添加新字段映射
- 清晰：明确标识哪些字段可用/不可用

### 2. 注册器模式 (Registry Pattern)
**位置**：`hot_topic_agent/registry.py`

**用途**：集中管理所有LangChain工具，便于Agent调用

**实现**：
```python
def get_tools() -> List[BaseTool]:
    return [load_bilibili_data, stat_summary, title_generator]
```

**优势**：
- 集中管理：所有工具统一注册
- 易于扩展：新工具只需在registry中注册
- 清晰可见：可快速查看所有可用工具

### 3. 模板方法模式 (Template Method)
**位置**：`hot_topic_agent/report.py`

**用途**：使用Jinja2模板渲染Markdown报告

**实现**：
```python
def render_markdown(topic: str, summary: Dict, titles: List[str]) -> str:
    env = Environment(loader=FileSystemLoader(base), autoescape=select_autoescape())
    tpl = env.get_template("report.md.jinja")
    return tpl.render(topic=topic, summary=summary, titles=titles)
```

**优势**：
- 灵活性：模板可自定义
- 分离关注点：业务逻辑与视图分离
- 可维护性：修改报告格式无需改动代码

### 4. 工厂模式 (Factory Pattern)
**位置**：`hot_topic_agent/agent_runner.py`

**用途**：构建LangChain Agent实例

**实现**：
```python
def build_agent():
    s = get_settings()
    llm = ChatOpenAI(model=s.MODEL_NAME, api_key=s.OPENAI_API_KEY, base_url=s.OPENAI_BASE_URL, temperature=0)
    tools = get_tools()
    return create_agent(llm, tools=tools, system_prompt="你是数据分析助手，使用工具读取数据并生成选题建议。")
```

**优势**：
- 封装复杂性：隐藏Agent构建细节
- 可配置：支持不同模型和工具配置
- 复用性：可多次创建相同的Agent

## 数据流模式

### 数据处理流水线
```
爬虫数据 → JSON存储 → 适配器转换 → 统计分析 → AI增强 → 报告生成
    ↓           ↓           ↓           ↓          ↓          ↓
  TopicItem  原始文件   TopicRecord   汇总指标    标题建议   Markdown
```

### API调用链
```
客户端请求 → FastAPI → 数据加载 → 数据适配 → 统计分析 → 标题生成 → 报告渲染 → 返回结果
     ↓          ↓         ↓           ↓           ↓           ↓            ↓          ↓
   HTTP      /report   JSON文件    标准格式    count等     AI生成      Jinja2     完整报告
```

## 状态管理模式

### 配置管理
**单例模式**：`get_settings()`确保全局只加载一次配置

```python
_settings: Settings | None = None

def get_settings() -> Settings:
    global _settings
    if _settings is None:
        load_dotenv()
        _settings = Settings(...)
    return _settings
```

### 数据生命周期
1. **采集阶段**：topic-crawler采集B站数据
2. **存储阶段**：JSON文件按日期存储
3. **适配阶段**：转换为分析系统标准格式
4. **分析阶段**：统计计算和AI增强
5. **输出阶段**：生成Markdown报告

## 错误处理模式

### 优雅降级
**场景**：OpenAI API密钥未配置
**策略**：跳过标题生成，仅返回统计数据和基础报告

```python
if s.OPENAI_API_KEY:
    titles = title_generator.invoke({"topic": req.topic, "context": "热搜选题"})
else:
    titles = []
```

### 空值安全
**场景**：数据字段可能缺失
**策略**：使用Optional类型和默认值

```python
views_sum = int(df["views"].sum()) if "views" in df.columns else 0
```

## 扩展性设计

### 工具扩展
新增工具只需：
1. 在tools/目录下创建Python文件
2. 使用`@tool`装饰器定义工具
3. 在registry.py中注册工具

### 数据源扩展
新增数据源只需：
1. 创建新的适配器函数
2. 映射字段到标准格式
3. 在load_bilibili_data中添加支持

### 分析指标扩展
新增指标只需：
1. 在Metrics类中添加字段
2. 在相应工具中计算新指标
3. 更新报告模板

## 性能优化模式

### 懒加载
- 配置只在首次调用时加载
- 数据文件只在需要时读取

### 缓存策略
- 模板环境一次性创建
- Agent实例可复用

### 批量处理
- 数据转换使用列表推导式
- 统计分析使用pandas向量化操作

## 总结

项目采用现代化的设计模式，核心特点是：
- **解耦**：通过适配器模式实现模块独立
- **灵活**：通过注册器模式支持工具扩展
- **可维护**：清晰的分层架构和职责分离
- **用户友好**：支持配置和优雅降级