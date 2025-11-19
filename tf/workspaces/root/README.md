# SQS EventBridge Integration Example

## Testing

Subscribe to messages:

```go
go run ./cmd/subscribe -queue https://sqs.eu-central-1.amazonaws.com/394577501925/fabric-dev-target
```

Send a message onto the event bus:

```go
go run ./cmd/publish -source "root.source" -detail-type "OrderCreated" -message '{ "xx": "yy" }' -bus fabric-dev-events
```
