# AI Coding Agent Skills 參考清單

> 來源：Threads 貼文 @sofi.life_official（2026 年整理），記錄可安裝給 Codex / Claude Code 等 AI coding agent 使用的 Skills。
> 用途：開發前先確認有沒有合適的 Skill 可以安裝，讓 agent 有清楚的 SOP 可以依循，減少重複描述與不必要的 token 浪費。

## 使用模式

開一個新專案或新任務前，先檢查下方清單，看看有沒有符合當下階段（架構 / UI / 除錯 / 自動化）的 Skill 可以先裝上，再開始寫 code。核心邏輯：**把腦袋裡模糊的需求，轉成 agent 可以穩定執行的任務**——先給清楚的 SOP，agent 才知道怎麼做，不用每次重新解釋一遍。

## Skill 清單

### 1. UI/UX 設計強化 Skill
- 推薦：`nextlevelbuilder/ui-ux-pro-max-skill`
- 適合：網站、Landing Page、個人品牌頁、產品頁
- 內建 50+ UI 風格、97 組配色、50 組字體搭配、20 種圖表樣式，支援 9 種技術框架
- 可以先幫 agent 整理設計知識庫，避免一開始就亂生畫面（例如常見的「AI 感」藍紫漸層卡片版型）
- 支援 plan / build / design / review / fix / improve 等動作指令，對應不同開發階段

### 2. 除錯與錯誤修復 Skill
- 推薦：`addyosmani/agent-skills`（`debugging-and-error-recovery`）
- 作者：Addy Osmani（前 Google Chrome DevRel，現任職 Anthropic）
- 流程：Five-step triage — reproduce → localize → reduce → fix → guard
- 特色：先重現問題再定位，偏向最小修改，降低「修一個壞三個」的機率
- 適合：build 失敗、測試失敗、行為與預期不符，或專案快完成時突然跑不起來

### 3. 專案架構師 Skill（Project Scaffolding）
- 推薦：`hmohamed01/Claude-Code-Scaffolding-Skill`
- 適合：專案剛開始時使用，幫忙建立基本架構
- 適用場景：網站、小工具、後台系統、簡單 SaaS 原型
- 對新手友善：先把「這個專案要怎麼開始」拆清楚，架構先弄好，後面加功能、debug、部署都會順很多

### 4. Codex Skills 實用清單
- 推薦：`ComposioHQ/awesome-codex-skills`
- 官方描述：A curated list of practical Codex skills for automating workflows across the Codex CLI and API
- 每個 Skill 獨立資料夾，內含 SKILL.md 說明文件，結構清楚好套用
- 適合：想用 Codex CLI 或 Codex API 做自動化、開發流程、工具串接的人
- 新手可以把它當成「Codex 的技能選單」，先看有哪些能力可以補上

### 5. Agent Skills 大型資源庫
- 推薦：`VoltAgent/awesome-agent-skills`
- 官方描述：收錄超過 1000 個 Agent Skills，來自官方開發團隊與社群貢獻
- 相容於 Claude Code、Codex、Gemini CLI、Cursor 等多種 AI Coding Agent
- 適合同時使用多個 AI Coding Agent 的情況，不用分頭找資源
- 涵蓋 code review、測試、文件、前端、後端、自動化、資料處理相關 Skill

### 6. LINE OA Chatbot Designer Skill（本專案相關）
- 用途：設計 LINE 官方帳號 AI 機器人時，規劃 Webhook 流程
- 可以協助拆解：系統架構、資料表設計、意圖判斷邏輯、人工接手機制
- **與本專案（line-gpt-bot）直接相關**：之後要擴充 webhook 流程、意圖判斷或轉接人工客服邏輯時，可以先參考這個 Skill 的方法拆解需求，再讓 agent 執行
