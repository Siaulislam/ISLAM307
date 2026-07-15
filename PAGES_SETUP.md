# Fix GitHub Pages 404 (one-time, ~30 seconds)

Your preview files are already deployed to the **`gh-pages`** branch.
GitHub just needs you to **turn on Pages** for this repository once.

## Steps

1. Open: **https://github.com/Siaulislam/ISLAM307/settings/pages**

2. Under **Build and deployment** → **Source**, choose:
   - **Deploy from a branch**

3. Set:
   - **Branch:** `gh-pages`
   - **Folder:** `/ (root)`

4. Click **Save**

5. Wait 1–2 minutes, then open:
   - https://siaulislam.github.io/ISLAM307/preview/
   - https://siaulislam.github.io/ISLAM307/design/mockups/index.html

## Already works locally

```powershell
C:\ISLAM307\scripts\start-local-preview.ps1
```

Then open http://localhost:5500/preview/

## Verify deploy succeeded

- `gh-pages` branch exists: https://github.com/Siaulislam/ISLAM307/tree/gh-pages
- Preview file on branch: https://raw.githubusercontent.com/Siaulislam/ISLAM307/gh-pages/preview/index.html

If both links work but the `github.io` URL is still 404, Pages is not enabled yet (step 1–4 above).
