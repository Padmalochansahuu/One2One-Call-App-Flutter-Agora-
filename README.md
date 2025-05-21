# 📞 Flutter Agora Video Call Demo  
_A One-to-One Call App with Simulated Local Notifications_

This Flutter app demonstrates **1:1 video calling** using the [Agora RTC SDK](https://www.agora.io/) and **simulated incoming call notifications** via `flutter_local_notifications`.

> 🚧 **Note:** This is a frontend-only demo. Notifications work only if the app is in the foreground or background — not terminated.

---

## ✨ Features

- 🔹 Simulated User A ↔ User B video call
- 🔹 Local notification for incoming calls
- 🔹 Local notification when the remote user joins
- 🔹 Video call actions: Mute, Camera toggle, Switch camera, End call
- 🔹 Simple call state handling (Idle, Calling, Ringing, Connected)

---

## 🚀 Quick Start (Test Now)

Use these test IDs directly to save time:

- 🔑 **Channel ID:** `call_user_A_user_B_d0a99145`  
- 🔔 **Caller ID (Agora UID):** `3987177741`

### 🅰️ Device 1 – User A (Caller)
1. Open app → Login as **User A**
2. Tap **Start Video Call**  
   *(App will automatically use the correct Channel ID)*

### 🅱️ Device 2 – User B (Callee)
1. Open app → Login as **User B**
2. In **Callee Simulation**, enter:
   - **Channel Name:** `call_user_A_user_B_d0a99145`
   - **Caller ID:** `user_A`
3. Tap **Simulate Receive Call**
4. Accept the call via popup or notification

---

## 🛠 Setup Instructions

```bash
git clone <your-repo-url>
cd <project-folder>
flutter pub get
flutter run
