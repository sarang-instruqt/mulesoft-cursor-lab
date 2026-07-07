The product team has a new requirement: the system needs to handle **subscription** orders — recurring orders with different fulfillment rules than retail, wholesale, or express.

In this challenge you'll use Cursor Agent to understand exactly what needs to change, then make the change yourself with Agent's guidance.

---

## Step 1: Ask the Agent What Needs to Change

Click the **Cursor IDE** tab.

Start a **New Agent** thread for this challenge — click the **+** icon in the Agent panel to open a fresh session. Then paste this prompt and press Enter:

```
I need to add a new order type called "subscription" to this integration.
Subscription orders are recurring, lower priority than express but higher than
wholesale, with a 72-hour SLA and no carrier pre-authorization required.

What files need to change, and what specifically needs to be added or modified
in each one? Don't make changes yet — just tell me the plan.
```

Review the plan before proceeding. The Agent should identify at minimum:
- `order-api.xml` — new `<when>` branch in the Choice router + new sub-flow
- `format-fulfillment.dwl` — new entry in `channelConfig`
- `schemas/order-canonical.json` — new enum value for `orderType`

---

## Step 2: Make the Changes with Agent

Now let Agent do the work:

```
Make all of those changes now. Add the "subscription" order type with:
- Priority: RECURRING
- SLA hours: 72
- requiresCarrierAuth: false
- Fulfillment URL property key: fulfillment.subscription.url

Add the new when branch and sub-flow to order-api.xml, update channelConfig in
format-fulfillment.dwl, and add "subscription" to the orderType enum in
order-canonical.json.
```

For each file the Agent modifies, click **Review** to inspect the diff, then click **Keep All** to accept the changes.

---

## Step 3: Verify the Changes

Ask Agent to confirm everything is consistent:

```
Review all the changes just made. Is the "subscription" order type handled
consistently across all files? Is there anything missing — like a dead-letter
fallback for an unknown type, or the config.yaml property for the fulfillment URL?
```

Add any missing pieces the Agent flags.

---

✅ You've extended a real MuleSoft integration using Cursor Agent — without a MuleSoft license, without Anypoint Studio, and without reading every file manually. Move on to the next chapter to wrap up.
