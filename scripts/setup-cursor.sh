#!/bin/bash
set -euo pipefail

# ── Install Docker CE ──────────────────────────────────────────────────────
# Base image is stock ubuntu:24.04 (no pre-baked custom VM image in Labs 2.0
# yet), so Docker has to be installed at boot.
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ensure Docker is running
systemctl enable docker
systemctl start docker
sleep 2

WORKSPACE=/opt/cursor-workspace
PROJECT=$WORKSPACE/mulesoft-order-api

mkdir -p "$PROJECT/src/main/mule"
mkdir -p "$PROJECT/src/main/resources/dwl"
mkdir -p "$PROJECT/src/main/resources/schemas"

# ── pom.xml ──────────────────────────────────────────────────────────────────
cat > "$PROJECT/pom.xml" << 'HEREDOC'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.acme.integration</groupId>
    <artifactId>order-processing-api</artifactId>
    <version>1.0.0</version>
    <packaging>mule-application</packaging>

    <name>Order Processing API</name>
    <description>
        Mule 4 integration that receives orders from multiple channels,
        normalizes them to a canonical format, enriches with customer data,
        and routes by order type to downstream fulfillment systems.
    </description>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <app.runtime>4.6.0</app.runtime>
        <mule.maven.plugin.version>4.1.0</mule.maven.plugin.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.mule.connectors</groupId>
            <artifactId>mule-http-connector</artifactId>
            <version>1.9.1</version>
            <classifier>mule-plugin</classifier>
        </dependency>
        <dependency>
            <groupId>org.mule.modules</groupId>
            <artifactId>mule-apikit-module</artifactId>
            <version>1.9.0</version>
            <classifier>mule-plugin</classifier>
        </dependency>
    </dependencies>

    <repositories>
        <repository>
            <id>anypoint-exchange-v3</id>
            <name>Anypoint Exchange</name>
            <url>https://maven.anypoint.mulesoft.com/api/v3/maven</url>
        </repository>
        <repository>
            <id>mulesoft-releases</id>
            <name>MuleSoft Releases Repository</name>
            <url>https://repository.mulesoft.org/releases/</url>
        </repository>
    </repositories>
</project>
HEREDOC

# ── mule-artifact.json ───────────────────────────────────────────────────────
cat > "$PROJECT/mule-artifact.json" << 'HEREDOC'
{
  "minMuleVersion": "4.6.0",
  "name": "order-processing-api",
  "configs": [
    "order-api.xml",
    "error-handling.xml"
  ],
  "redeploymentEnabled": true,
  "secureProperties": ["db.password", "http.client.secret"]
}
HEREDOC

# ── config.yaml ──────────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/config.yaml" << 'HEREDOC'
http:
  listener:
    host: "0.0.0.0"
    port: "8081"

fulfillment:
  retail:
    url: "https://fulfillment.acme.internal/api/v2/retail"
    timeout: 5000
  wholesale:
    url: "https://fulfillment.acme.internal/api/v2/wholesale"
    timeout: 10000
  express:
    url: "https://fulfillment.acme.internal/api/v2/express"
    timeout: 3000

customer:
  service:
    url: "https://customers.acme.internal/api/v1"
    timeout: 4000

dlq:
  enabled: true
  maxRetries: 3
  backoffMs: 2000
HEREDOC

# ── order-api.xml ─────────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/mule/order-api.xml" << 'HEREDOC'
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:doc="http://www.mulesoft.org/schema/mule/documentation"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
          http://www.mulesoft.org/schema/mule/core
          http://www.mulesoft.org/schema/mule/core/current/mule.xsd
          http://www.mulesoft.org/schema/mule/http
          http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
          http://www.mulesoft.org/schema/mule/ee/core
          http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <http:listener-config name="HTTP_Listener_config" doc:name="HTTP Listener config">
        <http:listener-connection host="${http.listener.host}" port="${http.listener.port}" />
    </http:listener-config>

    <!--
        Main Flow: POST /api/orders
        1. Receive inbound order payload (JSON)
        2. Normalize to canonical Order schema via DataWeave
        3. Enrich with customer profile data
        4. Route to fulfillment sub-flow by orderType
        5. Return 202 Accepted with confirmation
    -->
    <flow name="post-orders-flow" doc:name="POST /api/orders">

        <http:listener config-ref="HTTP_Listener_config"
                       path="/api/orders"
                       allowedMethods="POST"
                       doc:name="POST /api/orders" />

        <logger level="INFO"
                message="Received order request from #[attributes.remoteAddress]"
                doc:name="Log inbound request" />

        <ee:transform doc:name="Normalize to Canonical Order">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
(readUrl("classpath://dwl/normalize-order.dwl") as Function)(payload)]]></ee:set-payload>
            </ee:message>
            <ee:variables>
                <ee:set-variable variableName="canonicalOrder"><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-variable>
            </ee:variables>
        </ee:transform>

        <flow-ref name="enrich-customer-subflow" doc:name="Enrich Customer Data" />

        <choice doc:name="Route by Order Type">
            <when expression="#[vars.canonicalOrder.orderType == 'retail']">
                <flow-ref name="retail-fulfillment-subflow" doc:name="Route to Retail" />
            </when>
            <when expression="#[vars.canonicalOrder.orderType == 'wholesale']">
                <flow-ref name="wholesale-fulfillment-subflow" doc:name="Route to Wholesale" />
            </when>
            <when expression="#[vars.canonicalOrder.orderType == 'express']">
                <flow-ref name="express-fulfillment-subflow" doc:name="Route to Express" />
            </when>
            <otherwise>
                <flow-ref name="dead-letter-subflow" doc:name="Route to Dead Letter" />
            </otherwise>
        </choice>

        <ee:transform doc:name="Build 202 Response">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "ACCEPTED",
    orderId: vars.canonicalOrder.orderId,
    orderType: vars.canonicalOrder.orderType,
    message: "Order received and queued for fulfillment",
    receivedAt: vars.canonicalOrder.receivedAt
}]]></ee:set-payload>
            </ee:message>
            <ee:variables>
                <ee:set-variable variableName="httpStatus">202</ee:set-variable>
            </ee:variables>
        </ee:transform>

        <http:response statusCode="#[vars.httpStatus]" doc:name="HTTP 202 Response" />

    </flow>

    <!-- Sub-flow: Enrich with customer profile data -->
    <sub-flow name="enrich-customer-subflow" doc:name="Enrich Customer">
        <logger level="DEBUG"
                message="Enriching customer #[vars.canonicalOrder.customer.id]"
                doc:name="Log enrichment start" />
        <http:request method="GET"
                      url="${customer.service.url}/customers/#[vars.canonicalOrder.customer.id]"
                      responseTimeout="${customer.service.timeout}"
                      doc:name="GET Customer Profile" />
        <ee:transform doc:name="Merge Customer Data">
            <ee:variables>
                <ee:set-variable variableName="canonicalOrder"><![CDATA[%dw 2.0
output application/json
---
(readUrl("classpath://dwl/enrich-customer.dwl") as Function)(vars.canonicalOrder, payload)]]></ee:set-variable>
            </ee:variables>
        </ee:transform>
    </sub-flow>

    <!-- Sub-flow: Retail fulfillment — standard dispatch, inventory reservation -->
    <sub-flow name="retail-fulfillment-subflow" doc:name="Retail Fulfillment">
        <logger level="INFO"
                message="Dispatching retail order #[vars.canonicalOrder.orderId]"
                doc:name="Log retail dispatch" />
        <ee:transform doc:name="Format Retail Payload">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
(readUrl("classpath://dwl/format-fulfillment.dwl") as Function)(vars.canonicalOrder, "retail")]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <http:request method="POST"
                      url="${fulfillment.retail.url}"
                      responseTimeout="${fulfillment.retail.timeout}"
                      doc:name="POST to Retail Fulfillment" />
    </sub-flow>

    <!-- Sub-flow: Wholesale fulfillment — bulk dispatch, volume pricing, scheduled delivery -->
    <sub-flow name="wholesale-fulfillment-subflow" doc:name="Wholesale Fulfillment">
        <logger level="INFO"
                message="Dispatching wholesale order #[vars.canonicalOrder.orderId] (qty: #[vars.canonicalOrder.totalQuantity])"
                doc:name="Log wholesale dispatch" />
        <ee:transform doc:name="Format Wholesale Payload">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
(readUrl("classpath://dwl/format-fulfillment.dwl") as Function)(vars.canonicalOrder, "wholesale")]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <http:request method="POST"
                      url="${fulfillment.wholesale.url}"
                      responseTimeout="${fulfillment.wholesale.timeout}"
                      doc:name="POST to Wholesale Fulfillment" />
    </sub-flow>

    <!-- Sub-flow: Express fulfillment — priority dispatch, SLA 2 hours, carrier pre-auth -->
    <sub-flow name="express-fulfillment-subflow" doc:name="Express Fulfillment">
        <logger level="INFO"
                message="PRIORITY: Express order #[vars.canonicalOrder.orderId] — SLA 2h"
                doc:name="Log express dispatch" />
        <ee:transform doc:name="Format Express Payload">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
(readUrl("classpath://dwl/format-fulfillment.dwl") as Function)(vars.canonicalOrder, "express")]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <http:request method="POST"
                      url="${fulfillment.express.url}"
                      responseTimeout="${fulfillment.express.timeout}"
                      doc:name="POST to Express Fulfillment" />
    </sub-flow>

    <!-- Sub-flow: Dead Letter — unroutable orders logged and parked for manual review -->
    <sub-flow name="dead-letter-subflow" doc:name="Dead Letter Queue">
        <logger level="WARN"
                message="Unroutable order #[vars.canonicalOrder.orderId] — type '#[vars.canonicalOrder.orderType]' has no handler."
                doc:name="Log DLQ routing" />
        <set-variable variableName="httpStatus" value="422" doc:name="Set 422 status" />
    </sub-flow>

</mule>
HEREDOC

# ── error-handling.xml ────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/mule/error-handling.xml" << 'HEREDOC'
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:doc="http://www.mulesoft.org/schema/mule/documentation"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
          http://www.mulesoft.org/schema/mule/core
          http://www.mulesoft.org/schema/mule/core/current/mule.xsd
          http://www.mulesoft.org/schema/mule/ee/core
          http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!--
        Global Error Handler
        Handles error types in order of specificity.
        All flows reference this handler unless they define a local error-handler.
    -->
    <error-handler name="Global_Error_Handler" doc:name="Global Error Handler">

        <on-error-propagate type="HTTP:UNAUTHORIZED" doc:name="401 Unauthorized">
            <ee:transform doc:name="Build 401 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{ status: 401, error: "UNAUTHORIZED", message: "Valid credentials are required.", timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"} }]]></ee:set-payload>
                </ee:message>
                <ee:variables>
                    <ee:set-variable variableName="httpStatus">401</ee:set-variable>
                </ee:variables>
            </ee:transform>
        </on-error-propagate>

        <on-error-propagate type="VALIDATION:INVALID_INPUT" doc:name="400 Bad Request">
            <ee:transform doc:name="Build 400 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{ status: 400, error: "INVALID_INPUT", message: error.description default "Request payload failed schema validation.", timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"} }]]></ee:set-payload>
                </ee:message>
                <ee:variables>
                    <ee:set-variable variableName="httpStatus">400</ee:set-variable>
                </ee:variables>
            </ee:transform>
        </on-error-propagate>

        <on-error-propagate type="HTTP:CONNECTIVITY" doc:name="503 Service Unavailable">
            <logger level="ERROR" message="Downstream connectivity failure: #[error.description]" doc:name="Log connectivity error" />
            <ee:transform doc:name="Build 503 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{ status: 503, error: "SERVICE_UNAVAILABLE", message: "A downstream service is temporarily unavailable. Please retry.", retryAfter: 30, timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"} }]]></ee:set-payload>
                </ee:message>
                <ee:variables>
                    <ee:set-variable variableName="httpStatus">503</ee:set-variable>
                </ee:variables>
            </ee:transform>
        </on-error-propagate>

        <on-error-propagate type="HTTP:TIMEOUT" doc:name="504 Gateway Timeout">
            <logger level="ERROR" message="Downstream timeout: #[error.description]" doc:name="Log timeout" />
            <ee:transform doc:name="Build 504 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{ status: 504, error: "GATEWAY_TIMEOUT", message: "A downstream service did not respond in time.", timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"} }]]></ee:set-payload>
                </ee:message>
                <ee:variables>
                    <ee:set-variable variableName="httpStatus">504</ee:set-variable>
                </ee:variables>
            </ee:transform>
        </on-error-propagate>

        <on-error-propagate type="ANY" doc:name="500 Internal Server Error">
            <logger level="ERROR" message="Unhandled error: #[error.description] | Type: #[error.errorType]" doc:name="Log unhandled error" />
            <ee:transform doc:name="Build 500 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{ status: 500, error: "INTERNAL_SERVER_ERROR", message: "An unexpected error occurred. The request has been logged.", errorId: correlationId, timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"} }]]></ee:set-payload>
                </ee:message>
                <ee:variables>
                    <ee:set-variable variableName="httpStatus">500</ee:set-variable>
                </ee:variables>
            </ee:transform>
        </on-error-propagate>

    </error-handler>

</mule>
HEREDOC

# ── normalize-order.dwl ───────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/dwl/normalize-order.dwl" << 'HEREDOC'
%dw 2.0
/**
 * normalize-order.dwl
 *
 * Transforms an inbound order payload into the canonical Order schema.
 * Handles three source formats:
 *
 *   Web storefront  → { order_id, customerId, type, items: [{sku, qty, price}] }
 *   Mobile app      → { id, customer: {id, name, email}, orderType, lineItems: [...] }
 *   EDI partner     → { PurchaseOrder: { PONumber, BuyerParty, Lines: [...] } }
 *
 * Called as a function:
 *   (readUrl("classpath://dwl/normalize-order.dwl") as Function)(payload)
 */
output application/json

fun normalizeItems(raw: Any): Array = do {
    var webItems    = raw.items default []
    var mobileItems = raw.lineItems default []
    var ediLines    = raw.PurchaseOrder.Lines default []
    var source =
        if (!isEmpty(webItems))    webItems
        else if (!isEmpty(mobileItems)) mobileItems
        else ediLines
    ---
    source map (item, idx) -> {
        lineNumber:  idx + 1,
        sku:         item.sku          default item.productSku    default item.ItemNumber      default "UNKNOWN",
        description: item.name         default item.description   default item.ItemDescription default null,
        quantity:    (item.qty         default item.quantity      default item.OrderedQty      default 1)    as Number,
        unitPrice:   (item.price       default item.unitPrice     default item.UnitCost        default 0.00) as Number,
        lineTotal:   ((item.qty        default item.quantity      default item.OrderedQty      default 1)    as Number)
                     * ((item.price    default item.unitPrice     default item.UnitCost        default 0.00) as Number)
    }
}

fun normalizeCustomer(raw: Any): Object = do {
    var mobile  = raw.customer default {}
    var edi     = raw.PurchaseOrder.BuyerParty default {}
    ---
    {
        id:    raw.customerId    default mobile.id      default edi.PartyId    default "GUEST",
        name:  mobile.name
               default ((mobile.firstName default "") ++ " " ++ (mobile.lastName default ""))
               default edi.PartyName
               default "Unknown",
        email: mobile.email      default edi.ContactEmail default null,
        tier:  mobile.accountTier default "standard"
    }
}
---
{
    orderId:       raw.order_id        default raw.id                    default raw.PurchaseOrder.PONumber default uuid(),
    channel:       raw.channel         default raw.source                default "unknown",
    orderType:     lower(raw.type      default raw.orderType             default raw.PurchaseOrder.OrderClass default "retail"),
    customer:      normalizeCustomer(raw),
    items:         normalizeItems(raw),
    orderTotal:    sum(normalizeItems(raw) map $.lineTotal),
    totalQuantity: sum(normalizeItems(raw) map $.quantity),
    currency:      upper(raw.currency  default raw.PurchaseOrder.Currency default "USD"),
    notes:         raw.notes           default raw.specialInstructions   default null,
    status:        "RECEIVED",
    receivedAt:    now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"}
}
HEREDOC

# ── enrich-customer.dwl ───────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/dwl/enrich-customer.dwl" << 'HEREDOC'
%dw 2.0
/**
 * enrich-customer.dwl
 *
 * Merges a Customer Service API response into a canonical Order,
 * replacing sparse customer data with the full verified profile.
 *
 * Called as a function:
 *   (readUrl("classpath://dwl/enrich-customer.dwl") as Function)(canonicalOrder, customerPayload)
 *
 * Adds: verified name/email/phone, account tier, shipping address,
 *       payment method type, express eligibility, loyalty balance.
 */
output application/json

fun resolveShippingAddress(profile: Object): Object = do {
    var addrs   = profile.addresses default []
    var default = (addrs filter $.isDefault)[0] default addrs[0] default {}
    ---
    {
        line1:      default.street1  default default.addressLine1 default null,
        line2:      default.street2  default default.addressLine2 default null,
        city:       default.city     default null,
        state:      default.state    default default.province     default null,
        postalCode: default.zip      default default.postalCode   default null,
        country:    default.country  default "US"
    }
}

fun expressEligible(profile: Object, order: Object): Boolean =
    (profile.accountTier default "standard") != "standard"
    and (order.orderTotal default 0) >= 50.00
    and (profile.expressOptIn default false)
---
{
    (order - "customer"),
    customer: {
        id:              order.customer.id,
        name:            profile.fullName      default profile.name       default order.customer.name,
        email:           profile.email         default order.customer.email,
        phone:           profile.phone         default profile.mobilePhone default null,
        tier:            profile.accountTier   default order.customer.tier default "standard",
        shippingAddress: resolveShippingAddress(profile),
        paymentMethod: {
            type: profile.defaultPayment.type  default "unknown",
            last4: profile.defaultPayment.last4 default null
        },
        expressEligible: expressEligible(profile, order),
        loyaltyPoints:   profile.loyaltyBalance default 0
    }
}
HEREDOC

# ── format-fulfillment.dwl ────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/dwl/format-fulfillment.dwl" << 'HEREDOC'
%dw 2.0
/**
 * format-fulfillment.dwl
 *
 * Formats a canonical Order into the payload expected by a specific
 * fulfillment channel. Each channel has different field requirements
 * and priority rules.
 *
 * Called as a function:
 *   (readUrl("classpath://dwl/format-fulfillment.dwl") as Function)(canonicalOrder, channel)
 *
 * Supported channels: "retail", "wholesale", "express"
 */
output application/json

var channelConfig = {
    retail:    { priority: "STANDARD", slaHours: 48, requiresCarrierAuth: false },
    wholesale: { priority: "BULK",     slaHours: 120, requiresCarrierAuth: false },
    express:   { priority: "URGENT",   slaHours: 2,   requiresCarrierAuth: true }
}

var config = channelConfig[channel] default { priority: "STANDARD", slaHours: 48, requiresCarrierAuth: false }
---
{
    fulfillmentRequest: {
        referenceId:    order.orderId,
        channel:        upper(channel),
        priority:       config.priority,
        slaHours:       config.slaHours,
        submittedAt:    now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"},
        customer: {
            id:          order.customer.id,
            name:        order.customer.name,
            email:       order.customer.email,
            phone:       order.customer.phone default null,
            tier:        order.customer.tier
        },
        shipTo:          order.customer.shippingAddress,
        lineItems: order.items map (item) -> {
            sku:         item.sku,
            description: item.description,
            quantity:    item.quantity,
            unitPrice:   item.unitPrice
        },
        orderTotal:      order.orderTotal,
        currency:        order.currency,
        carrierAuth:     if (config.requiresCarrierAuth) "REQUIRED" else "NOT_REQUIRED",
        notes:           order.notes default null
    }
}
HEREDOC

# ── schemas ───────────────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/schemas/order-request.json" << 'HEREDOC'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "OrderRequest",
  "description": "Inbound order payload — accepts web, mobile, and EDI formats",
  "type": "object",
  "oneOf": [
    {
      "title": "Web Storefront Format",
      "required": ["order_id", "customerId", "items"],
      "properties": {
        "order_id":   { "type": "string" },
        "customerId": { "type": "string" },
        "type":       { "type": "string", "enum": ["retail", "wholesale", "express"] },
        "channel":    { "type": "string" },
        "items": {
          "type": "array",
          "minItems": 1,
          "items": {
            "required": ["sku", "qty", "price"],
            "properties": {
              "sku":   { "type": "string" },
              "qty":   { "type": "number", "minimum": 1 },
              "price": { "type": "number", "minimum": 0 }
            }
          }
        }
      }
    },
    {
      "title": "Mobile App Format",
      "required": ["id", "customer", "lineItems"],
      "properties": {
        "id":        { "type": "string" },
        "orderType": { "type": "string" },
        "customer": {
          "required": ["id"],
          "properties": {
            "id":          { "type": "string" },
            "name":        { "type": "string" },
            "email":       { "type": "string", "format": "email" },
            "accountTier": { "type": "string" }
          }
        },
        "lineItems": { "type": "array", "minItems": 1 }
      }
    }
  ]
}
HEREDOC

cat > "$PROJECT/src/main/resources/schemas/order-canonical.json" << 'HEREDOC'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "CanonicalOrder",
  "description": "Normalized Order schema used throughout the integration layer",
  "type": "object",
  "required": ["orderId", "orderType", "customer", "items", "orderTotal", "status", "receivedAt"],
  "properties": {
    "orderId":       { "type": "string" },
    "channel":       { "type": "string" },
    "orderType":     { "type": "string", "enum": ["retail", "wholesale", "express"] },
    "customer": {
      "type": "object",
      "required": ["id"],
      "properties": {
        "id":              { "type": "string" },
        "name":            { "type": "string" },
        "email":           { "type": "string" },
        "phone":           { "type": ["string", "null"] },
        "tier":            { "type": "string" },
        "shippingAddress": { "type": "object" },
        "paymentMethod":   { "type": "object" },
        "expressEligible": { "type": "boolean" },
        "loyaltyPoints":   { "type": "number" }
      }
    },
    "items": {
      "type": "array",
      "minItems": 1,
      "items": {
        "required": ["sku", "quantity", "unitPrice", "lineTotal"],
        "properties": {
          "lineNumber":  { "type": "number" },
          "sku":         { "type": "string" },
          "description": { "type": ["string", "null"] },
          "quantity":    { "type": "number" },
          "unitPrice":   { "type": "number" },
          "lineTotal":   { "type": "number" }
        }
      }
    },
    "orderTotal":    { "type": "number" },
    "totalQuantity": { "type": "number" },
    "currency":      { "type": "string" },
    "notes":         { "type": ["string", "null"] },
    "status":        { "type": "string" },
    "receivedAt":    { "type": "string" }
  }
}
HEREDOC

# ── fix ownership (abc user = UID 911 inside the container) ───────────────────
chown -R 911:911 "$WORKSPACE"

# ── start cursor-in-browser container ────────────────────────────────────────
docker run -d \
  --name cursor-ide \
  --restart unless-stopped \
  -p 8080:8080 \
  -e CUSTOM_PORT=8080 \
  -e TITLE="Cursor AI — Order Processing API" \
  -e DISPLAY=:1 \
  -e BROWSER=chromium \
  -v "$WORKSPACE":/cursor \
  arfodublo/cursor-in-browser:latest-x64

# ── wait for KasmVNC to be ready ─────────────────────────────────────────────
echo "Waiting for Cursor IDE to be ready on port 8080..."
until curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -qE "^(200|302|401)$"; do
  sleep 3
done

echo "Cursor IDE ready."

# ── patch chromium to run as root (--no-sandbox) ──────────────────────────────
# Idempotent: only patch if chromium-real doesn't already exist.
# If the VM image was built with the patch already applied, skip — re-running
# mv would overwrite chromium-real with the wrapper, creating an infinite loop.
docker exec -u root cursor-ide bash -c "
  if [ ! -f /usr/bin/chromium-real ]; then
    mv /usr/bin/chromium /usr/bin/chromium-real
    printf '#!/bin/bash\nexec /usr/bin/chromium-real --no-sandbox \"\$@\"\n' > /usr/bin/chromium
    chmod +x /usr/bin/chromium
    echo 'Chromium patched (first run).'
  else
    echo 'Chromium already patched — skipping.'
  fi
"
