---
created: 2025-11-22T10:23:42Z
last_updated: 2025-11-22T10:23:42Z
version: 1.0
author: Claude Code
---

# 项目概览 (Project Overview)

## 项目名称
智能选题决策与分析报告生成平台（代号：Topic Agent）

## 核心功能
- 🤖 AI驱动的热搜数据分析
- 📊 B站数据采集与统计
- 📝 自动生成Markdown分析报告
- 🔄 适配器模式实现数据源解耦
- 🌐 FastAPI Web服务接口

## 技术架构
- **AI框架**：LangChain + OpenAI GPT-4o-mini
- **Web框架**：FastAPI + Uvicorn
- **数据处理**：Pandas + NumPy
- **爬虫系统**：Httpx + Bilibili-API-Python
- **模板引擎**：Jinja2

## 当前状态
- ✅ 项目基础架构已完成
- ✅ AI分析系统已实现（hot_topic_agent模块）
- ✅ 爬虫系统已实现（topic-crawler模块）
- ✅ 适配器模式已集成
- ✅ Git版本控制已配置
- ✅ CLAUDE.md指导文档已创建

## 下一步计划
- [ ] 配置开发环境
- [ ] 测试完整数据流
- [ ] 部署Web服务
- [ ] 添加前端界面