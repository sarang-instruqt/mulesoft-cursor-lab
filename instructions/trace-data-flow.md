DataWeave is MuleSoft's transformation language. In this project, it does the heavy lifting: normalizing inconsistent input formats, enriching with customer data, and reshaping for downstream systems.

In this challenge you'll trace a specific field — `orderType` — from raw inbound payload all the way to the fulfillment request. Then answer a quick question to confirm your understanding.

Click the **Cursor IDE** tab to continue.

---

## Step 1: Trace the orderType Field

Continue in the same Agent panel from the previous challenge — no need to start a new thread. Paste this prompt and press Enter:

```
Trace the "orderType" field through the entire integration. Starting from an inbound
JSON payload, show me exactly:
1. Where is orderType first read or derived?
2. What transformation does it go through in normalize-order.dwl?
3. How does it determine which sub-flow runs in order-api.xml?
4. Does it appear in the final fulfillment payload — and if so, how?
```

---

## Step 2: Check the Default Behavior

Follow up with:

```
What value does orderType get if the inbound payload doesn't include a "type",
"orderType", or "OrderClass" field? Show me the exact line in normalize-order.dwl
that handles this.
```

---

## Step 3: Answer the Question

Based on what you learned from the Agent, answer the question below.

<instruqt-quiz id="order_type_quiz"></instruqt-quiz>
