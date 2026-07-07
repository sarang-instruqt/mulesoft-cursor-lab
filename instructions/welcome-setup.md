You've just been handed the keys to a MuleSoft Order Processing API. The previous team left clean code but zero documentation. Your job: get up to speed fast, and extend the integration before your sprint ends.

Cursor AI will be your guide through the codebase. Let's get it set up.

---

## Step 1: Open Cursor IDE

Click the **Cursor IDE** tab. The **Welcome to Cursor** screen will appear automatically.

---

## Step 2: Sign into Cursor

Cursor's AI features require a free account. On the welcome screen you'll see **Sign Up** and **Log In** buttons.

1. Click **Log In** (or **Sign Up** if you don't have an account yet)
2. A Chromium browser window will open — sign in with GitHub, Google, or email
3. When you see **"All set! Feel free to return to Cursor."** — close the browser window
4. Return to the **Cursor IDE** tab — you should see your account name in the top-right corner

> **Tip:** The Hobby plan is completely free — no credit card required. Signing up takes 30 seconds.

> **Note:** If a button doesn't respond to a direct click (a known KasmVNC behavior), right-click it → **Copy Link** → open in a new tab to proceed.

> **Tip:** If you see a **"New update available"** banner at the bottom of Cursor, click **Later** — it won't affect any features in this lab.

---

## Step 3: Open the Project

In Cursor, go to **File → Open Folder** and navigate to:

```
/cursor/mulesoft-order-api
```

Click **Open**. You should see the project tree in the left sidebar:

```
mulesoft-order-api/
├── pom.xml
├── mule-artifact.json
└── src/main/
    ├── mule/
    │   ├── order-api.xml
    │   └── error-handling.xml
    └── resources/
        ├── config.yaml
        ├── dwl/
        │   ├── normalize-order.dwl
        │   ├── enrich-customer.dwl
        │   └── format-fulfillment.dwl
        └── schemas/
```

---

✅ Project open and Cursor signed in. Move on to the next chapter to start exploring the codebase with AI.
