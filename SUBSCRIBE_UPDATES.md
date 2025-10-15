# Subscribe Command Updates

## Changes Made

Updated `cmd/subscribe/main.go` to decode JSON event messages into typed Go structures.

### New Event Structures

Added three event structures matching the JSON schemas in `etc/eventschema/`:

1. **OrderCreated**
   - OrderID, CustomerID, Amount, Currency
   - Items array (SKU, Quantity, Price)
   - Status, Timestamp

2. **OrderUpdated**
   - OrderID, Status, PreviousStatus
   - UpdatedFields array
   - Timestamp

3. **PaymentProcessed**
   - PaymentID, OrderID, CustomerID
   - Amount, Currency, PaymentMethod
   - Status, TransactionID, Timestamp

### Updated processMessage Function

The function now:

1. **Parses JSON** - Decodes message body as JSON
2. **Determines Event Type** - Uses `determineEventType()` to identify the event based on distinctive fields
3. **Decodes to Specific Type** - Unmarshals into the appropriate event structure
4. **Displays Structured Data** - Shows formatted event-specific information

### Event Type Detection Logic

The `determineEventType()` function identifies events by checking for distinctive fields:

- **PaymentProcessed** - Has `paymentId` field
- **OrderCreated** - Has `customerId`, `amount`, and `items` fields
- **OrderUpdated** - Has `previousStatus` field or just `orderId` and `status`

### Example Output

**Before:**

```
[Worker 0] Message ID: abc123
[Worker 0] Body: {"orderId":"123","customerId":"cust-456",...}
```

**After:**

```
[Worker 0] Message ID: abc123
[Worker 0] Event Type: OrderCreated
[Worker 0] Order ID: 123
[Worker 0] Customer ID: cust-456
[Worker 0] Amount: 99.99 USD
[Worker 0] Status: pending
[Worker 0] Items: 2
[Worker 0]   Item 1: SKU-001 (qty: 1, price: 49.99)
[Worker 0]   Item 2: SKU-002 (qty: 2, price: 25.00)
[Worker 0] Timestamp: 2025-10-15T12:00:00Z
```

## Usage

No changes to command-line usage:

```bash
./bin/subscribe -queue=<queue-url> -workers=5 -delete
```

The command now automatically detects and formats the event type based on the JSON structure.

## Benefits

✅ **Type Safety** - Structured Go types instead of raw strings  
✅ **Better Debugging** - Clear, formatted output showing event details  
✅ **Maintainability** - Easy to add validation or business logic  
✅ **Auto-Detection** - No need to specify event type manually  
