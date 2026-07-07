The Order Processing API you've inherited handles orders from three different source systems — a web storefront, a mobile app, and an EDI partner — and routes them to separate fulfillment systems based on order type.

Cursor Agent can read your entire codebase and answer questions about it in plain language. Let's put it to work.

---

## Step 1: Open Cursor Agent

Click the **Cursor IDE** tab. The Agent panel is already open on the right side. Make sure the mode is set to **Agent** (not Ask or Edit).

---

## Step 2: Ask for a Project Overview

Paste this prompt into the Agent panel and press Enter:

```
Explore this project and give me a plain-English overview. I want to understand:
1. What does this integration do at a high level?
2. What are the main files and what is each responsible for?
3. What happens to an order from the moment it arrives to when it leaves the system?
4. What are the three order types and how are they handled differently?
```

Read through the Agent's response. It should reference specific files, flow names, and sub-flows.

---

## Step 3: Dig into the DataWeave Layer

Follow up with:

```
Focus on the DataWeave transforms in src/main/resources/dwl/.
Explain what each .dwl file does and why the project uses three separate files
instead of one large transform.
```

> **Tip:** Notice how the Agent references specific function names, line numbers, and the design intent behind the code. This is the same explanation a senior engineer would give you — in seconds.

---

## Step 4: Ask a Harder Question

Try one more:

```
What happens to an order with an orderType that isn't "retail", "wholesale", or "express"?
Trace the exact path it takes through the code.
```

---

✅ You've used Cursor Agent to map the codebase faster than reading every file manually. Move on to the next chapter to trace a specific data transformation end-to-end.
