# LINE Bot 協調紀錄

## 系統概述

這是「李導任務控制器」的 LINE Bot 端。負責：
1. `/webhook` — LINE 聊天，使用者傳訊息，AI 回覆
2. `/notify` — 接收任務系統推播請求，推送結果給主人

搭配 `openclaw-task-bridge` repo 的任務系統使用。

## 主人的規則（必須遵守）

- 不推垃圾訊息：只有通過品質檢查的結果才會送到這裡
- 不要問主人技術問題
- 不要用技術名詞溝通
- 品質檢查邏輯在 `openclaw-task-bridge` 的 `task_runner.py`

## 目前狀態

- `app.py` — LINE Bot 主程式，含聊天和推播功能
- `/notify` 端點接收 JSON：`{"user_id": "...", "message": "..."}`
- 長訊息自動拆分

## 環境變數

- `LINE_CHANNEL_SECRET`
- `LINE_CHANNEL_ACCESS_TOKEN`
- `OPENAI_API_KEY`

## Claude / Codex 交接注意

- 誰接手就繼續做，透過這個 repo 同步
- 改了什麼要更新這個檔案
- 推播邏輯的品質把關在 `openclaw-task-bridge`，不在這裡
