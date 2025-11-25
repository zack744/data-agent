import sys
import json
import asyncio
from pathlib import Path
from src.crawler import fetch_newsnow_latest, fetch_newsnow_batch


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python cli.py <platform_id|--all> [--compact]", file=sys.stderr)
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
    target = args[0]
    if target == "--all":
        # 最小集平台，后续可改为读取 YAML
        platforms = [("toutiao", "今日头条"), ("weibo", "微博"), ("zhihu", "知乎")]
        data = asyncio.run(fetch_newsnow_batch(platforms))
        payload = {pid: [i.model_dump(mode="json", exclude_none=True) for i in items] for pid, items in data.items()}
        if compact:
            for pid in payload:
                for i in payload[pid]:
                    i.pop("raw", None)
        print(json.dumps(payload, ensure_ascii=False))
        out = Path(__file__).with_name("newsnow.json")
        out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        return 0
    else:
        items = asyncio.run(fetch_newsnow_latest(target))
    if compact:
        for i in items:
            if hasattr(i, "raw"):
                i.raw = None
    payload = [i.model_dump(mode="json", exclude_none=True) for i in items]
    print(json.dumps(payload, ensure_ascii=False))
    out = Path(__file__).with_name("newsnow.json")
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0

# 功能：命令行入口，读取参数并调用抓取，输出 JSON 与文件；模块：cli.py


if __name__ == "__main__":
    raise SystemExit(main())
