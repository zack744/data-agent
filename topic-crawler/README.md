# Topic Crawler (Bilibili 热搜 MVP)

一个独立、可插拔的爬虫子模块，用于抓取 B 站热搜词与轻量统计，输出标准化 JSON，便于后续接入 Agent 框架。

## 功能
- 抓取热搜榜（移动端/网页接口，自动回退），返回热词与排名等核心字段
- 轻统计：可选按热词检索前 N 条视频，计算 `video_count` 与 `avg_views`
- 关键词视频检索：按关键词拉取视频基本信息（保留接口，便于扩展）
- CLI 输出到 stdout，并同时写入 `topic-crawler/topics.json`

## 目录结构
- `requirements.txt` 依赖锁定（httpx、bilibili-api、pydantic、pytest 等）
- `src/models.py` 模型定义
  - `HotTopic`：`keyword`, `rank`, `heat_value?`, `hot_id?`, `icon?`, `video_count?`, `avg_views?`
  - `TopicItem`：`id`, `platform='bilibili'`, `keyword`, `title`, `author?`, `publish_time?`, `views?`, `likes?`, `like_rate?`, `comments?`, `raw?`
- `src/crawler.py` 采集逻辑
  - `fetch_bilibili_hot_topics(limit)`：热搜榜 → `HotTopic[]`
  - `enrich_hot_topics_with_stats(items, per)`：轻统计（并发）
  - `fetch_hot_topics(keyword, limit)`：关键词视频检索 → `TopicItem[]`
  - `fetch_hot_search(limit)`：热搜关键词基础列表（旧接口，保留）
- `cli.py` 命令行入口
- `tests/test_crawler.py` 基础用例

## 环境准备（Windows PowerShell）
- 创建并激活虚拟环境：
  - `python -m venv .venv`
  - `.\.venv\Scripts\Activate.ps1`
- 安装依赖：
  - `pip install -r topic-crawler\requirements.txt`
- 运行测试（可选）：
  - `python -m pytest -q`

## 使用
- 抓取热搜榜前 50 条（精简输出）：
  - `python topic-crawler\cli.py --hot-topics 50 --compact`
- 抓取热搜并做轻统计（每个热词取前 10 条视频，统计视频数与平均播放量）：
  - `python topic-crawler\cli.py --hot-topics 10 --compact --per 10`
- 按关键词检索视频（用于验证映射与留作扩展）：
  - `python topic-crawler\cli.py "AI 绘画" 20`
- 旧版热搜关键词接口（基础列表）：
  - `python topic-crawler\cli.py --hot 50`

说明：所有命令会在控制台打印 JSON，同时写入 `topic-crawler/topics.json`。

## 字段说明
- `HotTopic`（热词层，MVP 最小字段集）：
  - `keyword` 热词文本
  - `rank` 排名（来自 `position` 或顺序）
  - `heat_value?` 热度值（部分接口为 `heat_score`，若不存在则不输出）
  - `hot_id?` 热词唯一 ID
  - `icon?` 展示图标 URL
  - `video_count?` 统计：为该热词检索的视频条数（最多 `--per` 指定数量）
  - `avg_views?` 统计：平均播放量（按检索到的有播放量的条目计算）

- `TopicItem`（视频层，保留接口，便于后续分析扩展）：
  - 基本元数据：`id`, `keyword`, `title`, `author?`, `publish_time?`
  - 指标：`views?`, `likes?`, `like_rate?`, `comments?`
  - `raw?` 原始字段片段（定位与追查用）

## 备注
- 为避免 Web 接口校验导致的 `412`，热搜抓取实现了库方法 + 移动端接口的回退机制；两者字段不完全一致时，模型仅映射最小交集。
- `--compact` 会去除空值与 `raw`，便于审阅与传输；如需完整上下文，去掉该参数。
- 统计阶段有并发控制（默认 5），如需调整可在代码中修改 `enrich_hot_topics_with_stats` 的 `concurrency`。

## 路线
- 今晚：仅 MVP（热词 + 轻统计）
- 明天：Docker 封装与 Agent 框架集成；可按同目录结构拓展微博等平台的爬虫子模块