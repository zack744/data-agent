# 简单版 Dockerfile - 使用 Python 3.11
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装依赖包
RUN pip install -r requirements.txt

# 复制所有代码文件
COPY . .

# 运行命令：爬取热搜数据
CMD ["python", "cli.py", "--hot-topics", "50", "--compact"]
