# 幸福小家旺旺來 Supabase PWA

小家庭共用記帳 PWA。前端可部署在 GitHub Pages，登入、家庭同步與帳本資料放在 Supabase。圖片只送到 Edge Function 做 AI 解析，不會存進 Supabase Storage 或資料庫。

## 功能

- Supabase Auth 登入
- 家庭邀請碼共用同一份帳本
- 手機、電腦同步同一個 household 帳本
- Supabase Realtime 只訂閱目前 household
- 手動記帳與 AI 收據圖片解析共存
- 固定支出、房租、信貸、分期用規則自動產生月表
- 匯出 JSON 備份與 CSV
- PWA manifest 與 service worker

## Supabase 設定

1. 建立 Supabase project。
2. 到 SQL Editor 執行 `supabase/schema.sql`。
3. 到 Edge Functions 部署 `supabase/functions/parse-receipt`。
4. 在 Edge Function Secrets 設定：

```bash
OPENAI_API_KEY=你的 OpenAI API key
OPENAI_MODEL=gpt-4.1-mini
```

5. 複製 `app-config.example.js` 的內容到 `app-config.js`，填入：

```js
window.HAPPY_FAMILY_CONFIG = {
  supabaseUrl: "https://YOUR_PROJECT_ID.supabase.co",
  supabaseAnonKey: "YOUR_SUPABASE_ANON_KEY",
  parseReceiptFunctionName: "parse-receipt"
};
```

`supabaseAnonKey` 可以放前端；不要把 `service_role` key 或 OpenAI API key 放進前端。

## 家庭同步使用方式

1. 第一個人註冊或登入後，系統會建立家庭帳本並顯示邀請碼。
2. 另一個人註冊或登入時填入該邀請碼，就會加入同一個 household。
3. 新增、刪除、匯入、建立範例後會寫入 Supabase。
4. 切換頁籤、回到 App、重新整理頁面時會重新抓資料；Realtime 啟用時也會自動更新。

## GitHub Pages

這個專案仍是純前端檔案，可以直接部署：

1. 建立 GitHub repo。
2. commit 並 push 這些檔案。
3. 到 repo 的 Settings → Pages。
4. Source 選 `Deploy from a branch`。
5. Branch 選 `main` 與 `/root`。

## 檔案

- `index.html`：主程式與 UI
- `app-config.js`：前端 Supabase anon 設定
- `manifest.json`：PWA manifest
- `service-worker.js`：快取 GitHub Pages 前端資源
- `supabase/schema.sql`：資料表、RLS、Realtime 設定
- `supabase/functions/parse-receipt/index.ts`：AI 圖片解析 Edge Function
