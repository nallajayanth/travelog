# 🌍 Travlog – Your Personal Travel Journal App

> ✈️ A cross-platform **offline-first** mobile application to create, manage, and relive your travel memories.  
Built with **Flutter**, **Riverpod**, and **Supabase**, designed for seamless performance whether you’re online or off.

---

## 🎯 Objective
The goal of **Travlog** is to let travelers **capture, store, and organize** their journeys with:
- 📸 Photos
- 📍 Auto-fetched geolocation
- 🤖 AI-generated tags
- 🔍 Smart search & filters

All with **offline-first** capabilities – so your adventures are saved even without internet.

---

## ✨ Features

### 🔐 Authentication
- Secure **social login** using **Google** and/or **Apple**.

### 📒 Journal Entries
- Create, edit, and delete travel entries.
- Include **title**, **description**, **photos (up to 5)**, **date**, and **time**.
- Auto-fetch **location details**.

### 📶 Offline-First Mode
- Stores data locally using **Hive**.
- Syncs automatically with **Supabase** when back online.

### 🤖 AI Auto-Tagging
- Upload a photo and get **up to 5 relevant tags** using **Google Vision API** (e.g., “🌄 mountain”, “🏖 beach”, “🏙 cityscape”).

### 🔍 Search & Filters
- Search by **keywords**, **tags**, or **date range**.

### 🎨 UI/UX
- Clean, minimalistic design.
- **Light & Dark Mode** support.

---

## 🛠 Tech Stack

| Layer        | Technology |
|--------------|------------|
| **Framework** | Flutter (3.x+) |
| **State Management** | Riverpod |
| **Local Storage** | Hive |
| **Backend** | Supabase |
| **API Calls** | http |
| **Image Handling** | image_picker, cached_network_image |
| **Geolocation** | geolocator, geocoding |
| **Connectivity** | connectivity_plus |

---

## 🚀 Setup Instructions

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/nallajayanth/travlog_app.git
cd travlog_app
