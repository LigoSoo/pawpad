# tests/ctxdb-fpr/extract-corpus.py
# Claude Code transcript(~/.claude/projects/<slug>/*.jsonl)에서 실제 사용자 프롬프트만 뽑아
# run-fpr-replay.ps1이 먹는 JSON 배열로 저장한다.
#
#   python tests/ctxdb-fpr/extract-corpus.py <transcript-dir> <out.json>
#
# 제외 대상: isMeta / isSidechain(서브에이전트) / tool_result / <command-name> 등 슬래시커맨드 래퍼 /
# [Request interrupted...]. message.content는 문자열일 때도 있고 text 파트 배열일 때도 있어 둘 다 받는다.
# uuid로 중복 제거 후 timestamp 오름차순 정렬. 건수는 stderr로 찍는다.
import json,sys,os,glob
d=sys.argv[1]; out=[]
for f in glob.glob(os.path.join(d,"*.jsonl")):
    for ln in open(f,encoding="utf-8",errors="replace"):
        ln=ln.strip()
        if not ln or '"type":"user"' not in ln: continue
        try: o=json.loads(ln)
        except Exception: continue
        if o.get("type")!="user" or o.get("isMeta") or o.get("isSidechain"): continue
        c=o.get("message",{}).get("content"); t=None
        if isinstance(c,str): t=c
        elif isinstance(c,list):
            parts=[p.get("text","") for p in c if isinstance(p,dict) and p.get("type")=="text"]
            if parts and not any(isinstance(p,dict) and p.get("type")=="tool_result" for p in c):
                t="\n".join(parts)
        if not t: continue
        t=t.strip()
        if not t or t.startswith("<") or t.startswith("[Request interrupted"): continue
        out.append({"ts":o.get("timestamp"),"sid":o.get("sessionId"),"uuid":o.get("uuid"),"text":t})
seen=set(); u=[]
for r in out:
    if r["uuid"] in seen: continue
    seen.add(r["uuid"]); u.append(r)
u.sort(key=lambda r: r["ts"] or "")
print(len(u), file=sys.stderr)
json.dump(u,open(sys.argv[2],"w",encoding="utf-8"),ensure_ascii=False,indent=0)
