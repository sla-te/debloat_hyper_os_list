#!/bin/sh
# Rebuilds uad_lists.json (UAD-ng + Xiaomi Debloater ratings) and pushes it.
# Token is read from ~/.gh_token (never stored in this repo).
set -e
GH_USER="sla-te"
REPO="debloat_hyper_os_list"
command -v python3 >/dev/null || apk add python3
TOKEN=$(cat "$HOME/.gh_token" 2>/dev/null || true)
[ -n "$TOKEN" ] || { echo "Missing ~/.gh_token"; exit 1; }
cd "$HOME"
[ -d "$REPO" ] || git clone -q "https://github.com/$GH_USER/$REPO.git"
cd "$REPO"
git pull -q 2>/dev/null || true
python3 - <<'EOF'
import json, urllib.request
U="https://raw.githubusercontent.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/main/resources/assets/uad_lists.json"
F="https://raw.githubusercontent.com/fadeltd/xiaomi-debloater/main/bloatware.json"
get=lambda url: json.load(urllib.request.urlopen(url))
u=get(U); x=get(F)["packages"]
R={"Recommended":0,"Advanced":1,"Expert":2,"Unsafe":3}
M={"safe":"Recommended","caution":"Advanced","danger":"Unsafe"}
t=a=0
for p in x:
    k=p["package"]; r=M.get(p.get("risk"))
    if not r: continue
    if k in u:
        if R[r]>R.get(u[k].get("removal"),0):
            u[k]["removal"]=r; t+=1
            u[k]["description"]=(u[k].get("description") or "")+"\n[Xiaomi Debloater: "+p["risk"]+"] "+p["description"]
    else:
        u[k]={"list":"Oem","description":p["description"],"dependencies":[],"neededBy":[],"labels":[],"removal":r}; a+=1
json.dump(u,open("uad_lists.json","w",encoding="utf-8"),ensure_ascii=False,separators=(",",":"))
print("tightened",t,"added",a,"total",len(u))
EOF
git add uad_lists.json
git diff --cached --quiet && { echo "No changes"; exit 0; }
git -c user.name="$GH_USER" -c user.email="$GH_USER@users.noreply.github.com" commit -qm "Update merged list"
if ! git push -q "https://$GH_USER:$TOKEN@github.com/$GH_USER/$REPO.git" HEAD:main >/tmp/push.log 2>&1; then
  sed "s|$TOKEN|***|g" /tmp/push.log; rm -f /tmp/push.log
  echo "Push failed. Check ~/.gh_token."; exit 1
fi
rm -f /tmp/push.log
echo "Pushed. Canta URL: https://raw.githubusercontent.com/$GH_USER/$REPO/main/uad_lists.json"
