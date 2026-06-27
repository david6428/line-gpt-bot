"""
LINE Bot — 負責接收訊息和推播通知。

兩個功能：
1. /webhook  — LINE 聊天，使用者傳訊息，AI 回覆
2. /notify   — 任務系統呼叫這個端點來推播結果給主人
"""

from flask import Flask, request, abort
import requests
import json
import os

app = Flask(__name__)

LINE_CHANNEL_SECRET = os.environ.get("LINE_CHANNEL_SECRET", "")
LINE_CHANNEL_ACCESS_TOKEN = os.environ.get("LINE_CHANNEL_ACCESS_TOKEN", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

LINE_REPLY_URL = "https://api.line.me/v2/bot/message/reply"
LINE_PUSH_URL = "https://api.line.me/v2/bot/message/push"


def line_headers():
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {LINE_CHANNEL_ACCESS_TOKEN}",
    }


@app.route("/webhook", methods=["POST"])
def webhook():
    body = request.get_data(as_text=True)
    try:
        events = json.loads(body).get("events", [])
        for event in events:
            if event["type"] == "message" and event["message"]["type"] == "text":
                user_msg = event["message"]["text"]
                reply_token = event["replyToken"]
                ai_reply = ask_ai(user_msg)
                reply_line(reply_token, ai_reply)
        return "OK"
    except Exception as e:
        print(f"Webhook error: {e}")
        abort(400)


@app.route("/notify", methods=["POST"])
def notify():
    """任務系統呼叫此端點推播訊息給指定使用者。"""
    data = request.get_json(force=True)
    user_id = data.get("user_id")
    message = data.get("message", "")

    if not user_id or not message:
        return json.dumps({"error": "缺少 user_id 或 message"}), 400

    push_line(user_id, message)
    return json.dumps({"status": "sent"}), 200


def ask_ai(message):
    try:
        import openai
        openai.api_key = OPENAI_API_KEY
        response = openai.ChatCompletion.create(
            model="gpt-4-turbo",
            messages=[{"role": "user", "content": message}],
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"AI error: {e}")
        return "AI 回覆時發生錯誤。"


def reply_line(token, message):
    body = {
        "replyToken": token,
        "messages": [{"type": "text", "text": message}],
    }
    requests.post(LINE_REPLY_URL, headers=line_headers(), json=body)


def push_line(user_id, message):
    """主動推播訊息給指定使用者。"""
    chunks = split_message(message, 5000)
    for chunk in chunks:
        body = {
            "to": user_id,
            "messages": [{"type": "text", "text": chunk}],
        }
        requests.post(LINE_PUSH_URL, headers=line_headers(), json=body)


def split_message(text, max_len):
    if len(text) <= max_len:
        return [text]
    parts = []
    while text:
        parts.append(text[:max_len])
        text = text[max_len:]
    return parts


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
