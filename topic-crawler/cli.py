import sys
import json
import asyncio
from pathlib import Path
from src.crawler_bili import fetch_hot_topics, fetch_hot_search, fetch_bilibili_hot_topics, enrich_hot_topics_with_stats


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python cli.py <keyword|--hot|--hot-topics> [limit] [--compact] [--per N]", file=sys.stderr)
        return 2
    args = sys.argv[1:]
    compact = False
    per = None
    if "--compact" in args:
        compact = True
        args = [a for a in args if a != "--compact"]
    if "--per" in args:
        i = args.index("--per")
        try:
            per = int(args[i+1])
        except Exception:
            print("--per requires integer", file=sys.stderr)
            return 2
        args = args[:i] + args[i+2:]
    keyword = args[0]
    limit = 20
    if len(args) >= 2:
        try:
            limit = int(args[1])
        except Exception:
            print("limit must be integer", file=sys.stderr)
            return 2
    if "--per" in args:
        i = args.index("--per")
        try:
            per = int(args[i+1])
        except Exception:
            print("--per requires integer", file=sys.stderr)
            return 2
        args = args[:i] + args[i+2:]
    if keyword == "--hot":
        items = asyncio.run(fetch_hot_search(limit))
    elif keyword == "--hot-topics":
        hot_items = asyncio.run(fetch_bilibili_hot_topics(limit))
        if per is not None:
            hot_items = asyncio.run(enrich_hot_topics_with_stats(hot_items, per))
        items = hot_items
    else:
        items = asyncio.run(fetch_hot_topics(keyword, limit))
    if compact:
        for i in items:
            if hasattr(i, "raw"):
                i.raw = None
    payload = [i.model_dump(mode="json", exclude_none=True) for i in items]
    print(json.dumps(payload, ensure_ascii=False))
    out = Path(__file__).with_name("topics.json")
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0

# 功能：命令行入口，读取参数并调用抓取，输出 JSON 与文件；模块：cli.py


if __name__ == "__main__":
    raise SystemExit(main())
