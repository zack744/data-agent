---
created: 2025-11-22T10:23:42Z
last_updated: 2025-11-22T10:23:42Z
version: 1.0
author: Claude Code
---

# 项目结构 (Project Structure)

## 根目录结构
```
d:/project/data-agent/
├── .git/                    # Git版本控制
├── .claude/                 # Claude Code配置
│   ├── commands/            # 自定义命令（暂不可用）
│   ├── context/             # 项目上下文文档
│   ├── agents/              # AI智能体配置
│   ├── rules/               # 规则文件
│   └── scripts/             # 脚本文件
├── hot_topic_agent/         # AI分析系统 ⭐
│   ├── __init__.py
│   ├── README.md
│   ├── config.py            # 配置管理
│   ├── registry.py          # 工具注册
│   ├── agent_runner.py      # Agent引擎
│   ├── app_api.py           # FastAPI接口
│   ├── protocol/
│   │   ├── __init__.py
│   │   └── types.py         # 数据模型
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── fetch_bilibili.py # 数据加载+适配器 ⭐
│   │   ├── stat_summary.py   # 数据统计
│   │   └── title_generator.py # 标题生成
│   ├── report.py            # 报告渲染
│   └── requirements.txt
├── topic-crawler/           # 爬虫系统 ⭐
│   ├── cli.py               # 命令行入口
│   ├── src/
│   │   ├── __init__.py
│   │   ├── models.py        # 数据模型
│   │   └── crawler.py       # 爬虫核心
│   ├── tests/
│   │   └── test_crawler.py
│   └── requirements.txt
├── CLAUDE.md                # 项目指导文档 ⭐
├── .env.example             # 环境变量示例
├── .gitignore               # Git忽略文件
└── prd.md                   # 产品需求文档
```

## 核心模块说明

### hot_topic_agent（AI分析系统）
**职责**：基于LangChain构建智能分析系统
**关键文件**：
- `config.py` - 环境变量和API配置管理
- `registry.py` - LangChain工具注册中心
- `agent_runner.py` - Agent构建和运行引擎
- `app_api.py` - FastAPI Web服务（`/report`接口）
- `tools/fetch_bilibili.py` - 数据加载工具，**包含适配器模式**
- `tools/stat_summary.py` - 统计分析工具
- `tools/title_generator.py` - AI标题生成工具

### topic-crawler（爬虫系统）
**职责**：采集B站热搜数据
**关键文件**：
- `src/models.py` - Pydantic数据模型（TopicItem、HotTopic）
- `src/crawler.py` - 爬虫核心逻辑
- `cli.py` - 命令行调度入口

## 数据流向
```
爬虫采集 → JSON存储 → 适配器转换 → 统计分析 → AI增强 → 报告生成
```

## 关键设计模式
- **适配器模式**：`fetch_bilibili.py`中实现数据格式转换
- **注册器模式**：`registry.py`集中管理LangChain工具
- **模板方法模式**：`report.py`使用Jinja2模板渲染