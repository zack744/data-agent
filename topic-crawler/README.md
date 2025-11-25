# Topic Crawler（NewsNow 聚合源）

一个独立、可插拔的爬虫子模块，使用 NewsNow 项目的聚合接口抓取多平台“当前榜单”的新闻标题链接，并输出结构化 JSON。支持轻量的文章页源标签解析，补充 `publish_time/summary` 字段，便于后续时序预测与分析。

**数据源**
- 端点：`https://newsnow.busiyi.world/api/s?id=<platform_id>&latest`
- 行为：返回指定平台的当前榜单条目（`items`），每条含 `title/url/mobileUrl`；排名按照返回顺序确定。

**目标**
- 快速拉取各平台当前热点列表，形成统一结构的数据集
- 为后续的 30 天时序聚合与预测打样（按日统计 `article_count/unique_titles`）

## 功能
- 单平台抓取：按平台 ID 拉取当前榜单，解析为 `NewsItem[]`
- 批量抓取：按平台列表顺序抓取，控制最小请求间隔，输出合并结果
- 源标签解析（轻量）：对前 N 条文章页解析 `publish_time/summary`（多标签候选，JSON-LD 回退）
- CLI 输出到 stdout，并写入 `topic-crawler/newsnow.json`

## 目录结构
- `requirements.txt` 依赖锁定（httpx、pydantic、beautifulsoup4、pytest 等）
- `src/models.py`
  - `NewsItem`：`id/title/url/mobile_url?/platform_id?/platform_name?/rank?/fetch_time?/summary?/publish_time?/raw?`
  - `TopicStats`：`date/platform_id/article_count/unique_titles?/unique_sources?`
- `src/crawler.py`
  - `fetch_newsnow_latest(platform_id, platform_name?, proxy_url?, retries?, max_details?) -> List[NewsItem]`
  - `fetch_newsnow_batch(platforms, interval_ms?, proxy_url?) -> Dict[str, List[NewsItem]]`
- `cli.py` 命令行入口
- `tests/test_crawler.py` 基础用例

## 环境准备（Windows PowerShell）
- 创建并激活虚拟环境：
  - `python -m venv .venv`
  - `\.venv\Scripts\Activate.ps1`
- 安装依赖：
  - `pip install -r topic-crawler\requirements.txt`
- 运行测试（可选）：
  - `python -m pytest -q`

## 使用
- 抓取单平台（今日头条）：
  - `python topic-crawler\cli.py toutiao --compact`
- 批量最小集（微博/知乎/今日头条）：
  - `python topic-crawler\cli.py --all --compact`
- 输出文件：`topic-crawler\newsnow.json`

## 字段说明（NewsItem）
- `id` 唯一标识（优先使用 `url`）
- `title` 标题
- `url` 桌面端链接
- `mobile_url?` 移动端链接
- `platform_id?/platform_name?` 平台标识与名称（由调用方传入）
- `rank?` 榜单顺序（从 1 开始）
- `fetch_time?` 抓取时间（UTC）
- `publish_time?` 文章发布时间（源标签解析，可能为空）
- `summary?` 文章摘要（源标签解析，可能为空）
- `raw?` 原始字段片段（定位与追查用）

## 源标签解析策略
- `summary`：`meta[og:description]` → `meta[name=twitter:description]` → `meta[name=description]`
- `publish_time`：
  - `meta[property=article:published_time|og:published_time|og:updated_time]`
  - `meta[name=pubdate|publish-date|parsely-pub-date]`
  - `meta[itemprop=datePublished]`
  - `script[type=application/ld+json]` 的 `datePublished|dateCreated`
- 解析数量：默认仅解析前 8 条，降低开销；缺失时保持为空

## 扩展方向
- 平台配置扩展：从 YAML 加载平台列表，与 TrendRadar 的 `config.yaml` 对齐
- 详情解析开关：CLI 暴露 `--details N` 控制解析数量与开销
- 限流与重试：平台级并发/速率限制与退避策略参数化
- 时序聚合：按日聚合 `TopicStats`（`article_count/unique_titles`），支撑 30 天预测
- 存储层：落盘分区或入库（SQLite/Parquet），支持增量更新与回溯
- 质量控制：标题归一化、去重、来源名归一化、无效链接过滤
- 监控与日志：采集失败率、解析命中率、平台可用性指标
- 单元测试：对解析函数与聚合逻辑新增用例，覆盖常见页面结构

## 注意事项
- 合理控制抓取频率与详情解析数量，避免对来源站点造成压力
- 不同来源页面结构差异较大，`publish_time/summary` 可能为空，需做空值容忍
- 若需历史补数与跨站统一字段，建议叠加使用具备历史检索能力的新闻 API

## 变更记录
- 2025-11-25 重构为 NewsNow 聚合源版本，新增 `NewsItem` 与源标签解析，CLI 支持单平台与批量抓取，并输出 `newsnow.json`
