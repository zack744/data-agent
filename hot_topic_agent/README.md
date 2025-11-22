# 热搜选题助手（hot_topic_agent）

一个基于 LangChain 的最小可用数据分析 Agent 骨架，用于「热搜选题」的端到端流程：读取数据 → 基础统计 →（可选）生成标题 → 渲染 Markdown 报告 → 提供 API。

## 架构总览
- 编排层：`create_agent` 将 LLM 与工具仓库组合为单轮任务执行器。参见 `hot_topic_agent/agent_runner.py:6-14`。
- 工具层：以“插件函数”形式注册工具，支持扩展与替换。注册表见 `hot_topic_agent/registry.py:7-8`。
- 数据协议：`pydantic` 定义标准化结构，降低平台适配耦合。参见 `hot_topic_agent/protocol/types.py:1-18`。
- 报告层：`Jinja2` 模板生成 Markdown。参见 `hot_topic_agent/report.py:1-9` 与 `hot_topic_agent/templates/report.md.jinja`。
- API 层：`FastAPI` 暴露接口，触发整条链路。参见 `hot_topic_agent/app_api.py:15-27`。

## 目录结构
```
hot_topic_agent/
├─ app_api.py            # FastAPI 入口：/health、/report
├─ agent_runner.py       # LangChain 编排：create_agent + run 函数
├─ registry.py           # 工具注册表：集中返回可用工具列表
├─ report.py             # 报告渲染：Jinja2 输出 Markdown
├─ templates/
│  └─ report.md.jinja    # 报告模板（可自定义图表/表格）
├─ tools/                # 工具仓库（插件化）
│  ├─ fetch_bilibili.py  # 读取 DATA_ROOT/bilibili/*.json 最新数据
│  ├─ stat_summary.py    # 基础统计汇总（样本量、播放总和、点赞率均值）
│  └─ title_generator.py # 标题生成（需配置模型密钥，否则跳过）
├─ protocol/
│  └─ types.py           # 数据协议（Metrics/TopicRecord）
├─ config.py             # 环境与模型配置（.env 支持）
├─ requirements.txt      # 框架依赖清单
└─ README.md             # 本说明文档
```

## 依赖与环境
- Python 3.11（建议）
- 主要依赖（已收敛在 `requirements.txt`）：
  - `langchain`、`langchain-community`、`langchain-openai`
  - `python-dotenv`、`pydantic`、`tiktoken`
  - `pandas`、`numpy`
  - `fastapi`、`uvicorn`
  - `jinja2`

- 环境变量（`.env` 支持）：
  - `OPENAI_API_KEY`：模型密钥（国内兼容 OpenAI 的服务亦可）
  - `OPENAI_BASE_URL`：兼容端点（如通义、DeepSeek 等）
  - `MODEL_NAME`：模型名（如 `qwen-plus`、`deepseek-chat`）
  - `DATA_ROOT`：数据目录（例如 `d:\project\data-agent\data\raw`）

## 快速开始
1. 安装依赖（在激活的虚拟环境内）：
   ```powershell
   pip install -r hot_topic_agent/requirements.txt
   ```
2. 配置 `.env`（可拷贝 `.env.example`）并填写必要变量：
   ```env
   OPENAI_API_KEY=xxx
   OPENAI_BASE_URL=https://xxx.compatible/v1
   MODEL_NAME=qwen-plus
   DATA_ROOT=d:\project\data-agent\data\raw
   ```
3. 准备数据：将爬虫输出写到 `DATA_ROOT/bilibili/YYYY-MM-DD.json`（或最新文件名），示例记录（字段名可后续统一映射）：
   ```json
   {"title":"示例视频","views":12345,"like_rate":0.12,"published_at":"2025-11-20T12:00:00"}
   ```
4. 启动 API：
   ```powershell
   python -m uvicorn hot_topic_agent.app_api:app --host 127.0.0.1 --port 8000
   ```
5. 生成报告：
   ```powershell
   Invoke-RestMethod -Uri http://127.0.0.1:8000/report -Method POST -ContentType 'application/json' -Body (@{topic='Citywalk'} | ConvertTo-Json)
   ```

## 文件功能详解
- `agent_runner.py`
  - `build_agent()`：构建最小可用 LangChain Agent（`create_agent`），绑定工具与系统提示。参见 `hot_topic_agent/agent_runner.py:6-11`。
  - `run(input_text)`：以 `{"input": input_text}` 触发编排执行。参见 `hot_topic_agent/agent_runner.py:12-14`。
- `registry.py`
  - `get_tools()`：集中返回工具列表，新增工具只需加入此函数返回值。参见 `hot_topic_agent/registry.py:7-8`。
- `tools/fetch_bilibili.py`
  - `load_bilibili_data(date:str|None)`：读取指定日期或最新 JSON 文件，返回列表。参见 `hot_topic_agent/tools/fetch_bilibili.py:7-26`。
- `tools/stat_summary.py`
  - `stat_summary(records:list)`：统计样本量、播放总和、点赞率均值。参见 `hot_topic_agent/tools/stat_summary.py:6-15`。
- `tools/title_generator.py`
  - `title_generator(topic, context)`：调用模型生成最多 5 个中文标题（需配置密钥）。参见 `hot_topic_agent/tools/title_generator.py:7-18`。
- `report.py`
  - `render_markdown(topic, summary, titles)`：渲染 Markdown 报告文本。参见 `hot_topic_agent/report.py:1-9`。
- `app_api.py`
  - `GET /health`：健康检查。
  - `POST /report`：核心流程：加载数据 → 统计 →（若配置模型）生成标题 → 渲染报告并返回。

## 模型对接（国内兼容 OpenAI）
- 若使用通义/DeepSeek 等兼容端点：
  - 设置 `OPENAI_BASE_URL` 为厂商兼容地址，`MODEL_NAME` 为对应模型名。
  - `langchain-openai` 会走 OpenAI SDK，因此只要端点兼容即可直接调用。
- 未配置密钥时：`/report` 会跳过标题生成，仅返回统计与基础报告。

## 扩展指南
- 新增工具（插件）：
  - 在 `tools/` 新建 Python 文件，使用 `@tool("your_tool_name")` 装饰器并写好函数文档；
  - 将工具对象加入 `registry.get_tools()` 返回值；
  - Agent 会自动可用该工具。
- 适配其它平台：
  - 建议在 `tools/` 下新增 `fetch_weibo.py`/`fetch_douyin.py` 等，并统一映射到 `protocol/types.py` 的字段；
  - 保持工具输入/输出的字典键一致，减少下游改动。
- 多代理演进：
  - 当前为单代理；后续可拆分为 `DataAgent`/`AnalysisAgent`/`ReportAgent` 并引入中间件或状态图。

## 注意事项
- Windows 路径中的反斜杠需转义或使用原始字符串（如 `r"d:\\project\\data-agent\\data\\raw"`）。
- 避免在代码中写入明文密钥，统一通过环境变量加载。
- 若出现乱码（终端显示），使用前端渲染 Markdown 或在控制台设置 UTF-8 输出。

---
如需我继续补齐「数据清洗与字段映射」或「关键字频次工具」，告诉我你当前爬虫输出的 JSON 字段名，我会按此 README 的协议快速映射并完善统计与报告模板。