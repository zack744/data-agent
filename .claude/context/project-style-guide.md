---
created: 2025-11-22T10:34:40Z
last_updated: 2025-11-22T10:34:40Z
version: 1.0
author: Claude Code PM System
---

# 项目风格指南 (Project Style Guide)

## 编码规范

### Python代码规范
**遵循标准**：PEP 8 Python代码风格指南

#### 1. 命名约定
**类名**：使用CapWords（首字母大写）命名
```python
# ✅ 正确
class TopicRecord(BaseModel):
    pass

class Metrics(BaseModel):
    pass

# ❌ 错误
class topic_record(BaseModel):
    pass

class metrics(BaseModel):
    pass
```

**函数名**：使用snake_case（全部小写，下划线分隔）
```python
# ✅ 正确
def load_bilibili_data(date: str | None = None) -> List[Dict]:
    def adapt_crawler_data(crawler_data: List[Dict]) -> List[Dict]:
        pass

# ❌ 错误
def loadBilibiliData(date):
    pass
```

**变量名**：使用snake_case
```python
# ✅ 正确
openai_api_key = "..."
topic_records = []
file_path = "/path/to/file"

# ❌ 错误
openaiAPIKey = "..."
TopicRecords = []
filePath = "/path/to/file"
```

**常量名**：使用UPPER_SNAKE_CASE（全大写）
```python
# ✅ 正确
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30
API_BASE_URL = "https://api.openai.com/v1"

# ❌ 错误
max_retries = 3
DefaultTimeout = 30
apiBaseUrl = "https://api.openai.com/v1"
```

#### 2. 导入规范
**标准库导入**：按字母顺序，先标准库，再第三方库
```python
# ✅ 正确
import json
import os
from datetime import datetime

import pandas as pd
from fastapi import FastAPI
from langchain_openai import ChatOpenAI

# 本地导入
from .config import get_settings
from .tools.fetch_bilibili import load_bilibili_data
```

**避免通配符导入**
```python
# ✅ 正确
from mymodule import specific_function

# ❌ 错误
from mymodule import *
```

#### 3. 函数设计
**函数长度**：建议不超过50行，单一职责原则
```python
# ✅ 好的函数设计
def adapt_topic_item_to_analysis_format(crawler_item: Dict[str, Any]) -> Dict[str, Any]:
    """
    将爬虫系统的TopicItem数据适配成分析系统需要的格式
    负责字段映射和数据类型转换
    """
    return {
        "topic": crawler_item.get("keyword", ""),
        "platform": crawler_item.get("platform", "bilibili"),
        "metrics": {
            "views": crawler_item.get("views"),
            "like_rate": crawler_item.get("like_rate"),
            "published_at": crawler_item.get("publish_time"),
        },
        "raw": crawler_item.get("raw") or crawler_item
    }
```

**参数设计**：避免过多参数（建议不超过5个）
```python
# ✅ 正确：使用配置对象
def create_client(config: ClientConfig):
    pass

# ❌ 错误：过多参数
def create_client(api_key, base_url, timeout, retries, user_agent):
    pass
```

#### 4. 异常处理
**使用具体异常类型**
```python
# ✅ 正确
try:
    data = load_json_file(path)
except FileNotFoundError:
    logger.error(f"文件不存在: {path}")
    return []
except json.JSONDecodeError as e:
    logger.error(f"JSON解析错误: {e}")
    return []

# ❌ 错误
try:
    data = load_json_file(path)
except:
    pass
```

**异常日志记录**
```python
# ✅ 正确
import logging

logger = logging.getLogger(__name__)

try:
    result = risky_operation()
except SpecificException as e:
    logger.error(f"操作失败: {e}", exc_info=True)
    raise
```

#### 5. 类型注解
**必须使用类型注解**
```python
# ✅ 正确
from typing import List, Dict, Optional

def load_data(date: Optional[str] = None) -> List[Dict]:
    pass

def process_records(records: List[Dict]) -> Dict[str, int]:
    pass

# ❌ 错误
def load_data(date=None):
    pass
```

**泛型类型注解**
```python
# ✅ 正确
from typing import List, Dict, Any

records: List[Dict[str, Any]]
metrics: Dict[str, Optional[int]]

# ❌ 错误
records: List[Dict]
metrics: Dict
```

#### 6. 文档字符串
**使用docstring描述函数功能**
```python
# ✅ 正确
def load_bilibili_data(date: str | None = None) -> List[Dict]:
    """
    加载B站热搜数据工具（带适配器版本）

    1. 从本地存储加载爬虫系统输出的JSON数据
    2. 通过适配器转换成分析系统需要的格式
    3. 返回标准化的数据列表

    Args:
        date: 可选的日期字符串，格式为YYYY-MM-DD

    Returns:
        转换后的数据列表

    Raises:
        FileNotFoundError: 当数据文件不存在时
    """
    pass

# ❌ 错误
def load_bilibili_data(date: str | None = None) -> List[Dict]:
    # 加载数据
    pass
```

#### 7. 代码注释
**中文注释规范**（本项目特殊要求）
```python
# ✅ 好的中文注释
def process_data(data: List[Dict]) -> List[Dict]:
    """
    处理原始数据，应用过滤和转换规则
    """
    # 过滤掉无效的记录（缺少关键字段）
    valid_data = [item for item in data if validate_item(item)]

    # 转换时间格式为UTC标准时间
    for item in valid_data:
        item['timestamp'] = convert_to_utc(item['publish_time'])

    return valid_data
```

**注释风格**
```python
# 单行注释前加两个空格，# 后加一个空格
x = x + 1  # 递增操作

# 多行注释使用块注释
# 这是一个重要的计算过程
# 第一步：数据预处理
# 第二步：特征提取
# 第三步：模型预测
```

## 文件组织规范

### 项目目录结构
```
project/
├── 模块名称/
│   ├── __init__.py           # 包初始化文件
│   ├── main_module.py        # 主要功能模块
│   ├── submodules/           # 子模块目录
│   │   ├── __init__.py
│   │   └── helper.py         # 辅助功能
│   └── tests/                # 测试目录
│       ├── __init__.py
│       └── test_main.py      # 测试用例
```

### 文件命名规范
- **文件名**：使用snake_case
- **测试文件**：以test_开头
- **配置文件**：使用有意义的名称

```python
# ✅ 正确
data_loader.py
config_manager.py
test_data_loader.py

# ❌ 错误
DataLoader.py
ConfigManager.py
data_loader_test.py
```

## 配置文件规范

### 环境变量命名
```bash
# ✅ 正确
OPENAI_API_KEY=your_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
MODEL_NAME=gpt-4o-mini
DATA_ROOT=./data/raw

# ❌ 错误
api_key=your_key_here
baseUrl=https://api.openai.com/v1
model=model_name
dataPath=./data/raw
```

### JSON/YAML格式
```json
{
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "myapp"
  },
  "features": {
    "enable_cache": true,
    "max_retries": 3
  }
}
```

## API设计规范

### RESTful API
**HTTP方法使用**
- GET：获取资源
- POST：创建资源
- PUT：更新资源
- DELETE：删除资源

**URL设计**
```python
# ✅ 好的API设计
GET /api/v1/reports/{report_id}     # 获取特定报告
POST /api/v1/reports                # 创建新报告
GET /api/v1/topics                  # 获取话题列表

# ❌ 错误的API设计
GET /api/v1/getReport?id=123        # 不符合REST规范
POST /api/v1/createReport           # 不符合REST规范
```

**响应格式**
```python
# ✅ 统一响应格式
{
  "success": true,
  "data": {...},
  "message": "操作成功",
  "timestamp": "2025-11-22T10:34:40Z"
}
```

**错误响应**
```python
# ✅ 标准错误格式
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "输入参数无效",
    "details": {...}
  },
  "timestamp": "2025-11-22T10:34:40Z"
}
```

## 数据库规范

### 字段命名
- **数据库列名**：snake_case
- **表名**：snake_case，复数形式

```sql
-- ✅ 正确
CREATE TABLE user_profiles (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ❌ 错误
CREATE TABLE UserProfiles (
    ID SERIAL PRIMARY KEY,
    UserID VARCHAR(50) NOT NULL,
    CreatedAt TIMESTAMP DEFAULT NOW()
);
```

## 日志规范

### 日志级别
- **DEBUG**：调试信息
- **INFO**：一般信息
- **WARNING**：警告信息
- **ERROR**：错误信息
- **CRITICAL**：严重错误

### 日志格式
```python
# ✅ 标准日志格式
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

logger = logging.getLogger(__name__)
logger.info("用户数据加载完成", extra={"user_id": "123", "count": 100})
```

## 测试规范

### 测试命名
```python
# ✅ 正确
def test_load_bilibili_data_with_valid_date():
    """测试加载指定日期的B站数据"""
    pass

def test_adapt_crawler_data_empty_list():
    """测试适配空数据列表"""
    pass

# 测试类命名
class TestDataLoader:
    def test_valid_data(self):
        pass

    def test_invalid_data(self):
        pass
```

### 测试覆盖率
- **目标覆盖率**：> 80%
- **核心功能**：> 90%
- **重要模块**：100%

### Mock使用
```python
# ✅ 正确使用mock
from unittest.mock import patch, MagicMock

@patch('requests.get')
def test_api_call(mock_get):
    mock_get.return_value.json.return_value = {"status": "ok"}
    result = call_api()
    assert result["status"] == "ok"
```

## 文档规范

### 代码文档
- 所有公共函数必须有docstring
- 复杂逻辑需要行内注释
- 注释使用中文

### API文档
- 使用docstring描述API端点
- 包含请求/响应示例
- 记录所有参数和返回值

### README规范
```
# 项目名称

## 项目简介
简要描述项目目标和功能

## 安装指南
```bash
pip install -r requirements.txt
```

## 使用示例
```python
from module import main_function

result = main_function("参数")
print(result)
```

## 配置说明
描述环境变量和配置文件

## 贡献指南
如何参与项目开发
```

## 提交规范

### Git提交信息
**格式**：`<type>: <subject>`

**类型**：
- `feat`：新功能
- `fix`：bug修复
- `docs`：文档更新
- `style`：代码格式调整
- `refactor`：代码重构
- `test`：测试相关
- `chore`：构建/工具相关

```bash
# ✅ 好的提交信息
feat: 添加B站数据适配器
fix: 修复日期格式解析错误
docs: 更新API文档
refactor: 重构数据处理逻辑
test: 添加单元测试

# ❌ 错误的提交信息
update
fix bug
修改代码
```

## 性能规范

### 代码性能
- 避免不必要的计算
- 使用适当的数据结构
- 合理使用缓存

### 资源管理
- 及时释放不需要的资源
- 关闭文件和网络连接
- 使用with语句自动管理资源

```python
# ✅ 正确的资源管理
with open('file.txt', 'r') as f:
    content = f.read()

# 或使用try-finally
f = None
try:
    f = open('file.txt', 'r')
    content = f.read()
finally:
    if f:
        f.close()
```

## 安全规范

### 敏感信息
- 不在代码中硬编码密钥
- 使用环境变量管理敏感信息
- 日志中不记录敏感数据

```python
# ✅ 安全做法
import os

API_KEY = os.getenv("API_KEY")
if not API_KEY:
    raise ValueError("API_KEY环境变量未设置")

# ❌ 不安全做法
API_KEY = "sk-1234567890abcdef"
logger.info(f"API密钥: {API_KEY}")
```

### 输入验证
- 验证所有用户输入
- 使用类型注解和Pydantic模型
- 避免SQL注入等安全问题

## 部署规范

### 环境管理
- 开发/测试/生产环境分离
- 使用配置文件管理不同环境设置
- 环境变量覆盖配置文件

### 版本管理
- 使用语义化版本号（Semantic Versioning）
- 主版本.次版本.修订版本（如：1.2.3）
- 在版本发布时更新版本号

这个风格指南将确保项目代码的一致性、可读性和可维护性。所有团队成员都应遵循这些规范进行开发。