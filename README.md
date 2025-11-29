# Smart Spend

A modern, AI-assisted expense tracker built with **Flutter**, **AWS Amplify**, and intelligent prediction models. Smart Spend helps you understand your spending habits, visualize expenses, and forecast upcoming trends using ML-powered insights.

---

## 🚀 Features

- **📊 Real-time Expense Tracking** – Log expenses and categorize them effortlessly.
- **💳 Wallet & Bank Dashboard** – Unified view of total balance and cash flow.
- **📅 Monthly Budgeting** – Track how well you stay within your budget.
- **📈 AI Spending Forecasts** – Predict next-day and next-month spending using ML.
- **🥧 Category Analytics** – Pie-chart distribution of expenses by category.
- **📰 Financial News Feed** – Stay updated on market trends.
- **☁️ AWS Amplify Backend** – Secure authentication + scalable API.
- **🔄 Auto-refresh Insights** – Recent expenses, balances, and budgets update live.

---

## 🛠️ Tech Stack

- **Flutter** (UI + stateful widgets)
- **AWS Amplify** (Auth, API, Storage)
- **API Gateway + Lambda** (Expense CRUD + Prediction API)
- **DynamoDB** (NoSQL database)
- **LSTM-based model** (Next-day + monthly predictions)

---

## 🛡️ Badges

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?logo=flutter)
![AWS Amplify](https://img.shields.io/badge/AWS-Amplify-orange?logo=amazon-aws)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

---

## 📦 Installation

### **1️⃣ Clone the Repository**

```bash
git clone https://github.com/plufle/Expense-Tracker
cd Expense-Tracker
```

### **2️⃣ Install Dependencies**

```bash
flutter pub get
```

### **3️⃣ Setup AWS Amplify**

Make sure you have the Amplify CLI installed:

```bash
npm install -g @aws-amplify/cli
```

Then configure:

```bash
amplify pull --appId YOUR_APP_ID --envName dev
```

This will regenerate:

- `amplifyconfiguration.dart`
- Backend environment files

### **4️⃣ Create `.env` file (API Base URL, etc.)**

Inside project root:

```
API_BASE_URL=https://your-api-endpoint.amazonaws.com
```

Add to `.gitignore`:

```
.env
*.env
```

### **5️⃣ Run the App**

```bash
flutter run
```

---

## 🧠 API Architecture Diagram (Text Representation)

```
         ┌───────────────────────┐
         │      Flutter App      │
         │  Smart Spend (UI)     │
         └──────────┬────────────┘
                    │ REST Calls
                    ▼
       ┌─────────────────────────────┐
       │     API Gateway (REST)      │
       └──────────┬──────────┬──────┘
                  │          │
      Expenses CRUD         AI Predictions
                  │          │
                  ▼          ▼
     ┌────────────────┐   ┌────────────────┐
     │ Lambda (CRUD)  │   │  Lambda (ML)   │
     └───────┬────────┘   └───────┬────────┘
             │ DynamoDB           │ S3 / Model
             ▼                    ▼
     ┌────────────────┐    ┌─────────────────┐
     │ Transaction DB │    │ Prediction Model │
     └────────────────┘    └─────────────────┘
```

---

## 📚 API Endpoints

### **GET /expenses?limit=100**

Returns list of expenses.

### **POST /expenses**

Creates new expense.

### **DELETE /expenses/{id}**

Soft deletes an expense.

### **POST /predict-next**

Body:

```json
{
  "amounts": [120, 300, 150, ...]
}
```

Response:

```json
{
  "prediction": 245.6,
  "nextMonthTotal": 11240.0
}
```

---

## 🤝 Contributing

Pull requests are welcome! If you want to add new insights, charts, or ML models — feel free to open an issue.

---

## 📄 License

This project is licensed under the MIT License.

---

