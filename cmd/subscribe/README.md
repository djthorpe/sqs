# SQS Subscribe Command

A command-line tool to subscribe to and process messages from an AWS SQS queue using concurrent worker goroutines.

## Installation

```bash
go build -o subscribe ./cmd/subscribe
```

Or from the project root:

```bash
make build-subscribe
```

## Usage

### Basic Usage

```bash
./subscribe -queue <queue-url>
```

### Examples

#### Subscribe to a queue with default settings

```bash
./subscribe -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue"
```

#### Subscribe with custom worker pool size

```bash
./subscribe \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue" \
  -workers 10 \
  -max-messages 10
```

#### Auto-delete messages after processing

```bash
./subscribe \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue" \
  -delete
```

#### Configure polling and visibility timeout

```bash
./subscribe \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue" \
  -wait-time 20 \
  -visibility 300 \
  -workers 5
```

## Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-queue` | SQS queue URL (required) | - |
| `-max-messages` | Maximum number of messages to receive per request (1-10) | `10` |
| `-wait-time` | Long polling wait time in seconds (0-20) | `20` |
| `-visibility` | Visibility timeout in seconds | `30` |
| `-workers` | Number of concurrent worker goroutines | `5` |
| `-delete` | Delete messages after processing | `false` |

## Features

### Concurrent Processing

The command spawns multiple worker goroutines (configurable via `-workers`) that process messages concurrently from a shared channel. This allows for efficient parallel processing of messages.

### Long Polling

By default, the command uses long polling (`-wait-time 20`) to reduce the number of empty responses and lower costs. Long polling waits for messages to become available before returning.

### Graceful Shutdown

The command handles `SIGINT` (Ctrl+C) and `SIGTERM` signals gracefully:

1. Stops receiving new messages
2. Waits for all in-flight messages to complete processing
3. Closes all worker goroutines cleanly

### Message Information

For each message, the command displays:

- Worker ID that processed the message
- Message ID
- Message body
- Message attributes (if any)

## Architecture

```
SQS Queue → receiveMessages() → Message Channel → Worker Pool (goroutines)
                                                         ↓
                                                   processMessage()
                                                         ↓
                                                   deleteMessage() (optional)
```

1. **Receiver Goroutine**: Continuously polls SQS for new messages
2. **Message Channel**: Buffered channel that holds received messages
3. **Worker Pool**: Multiple goroutines that process messages concurrently
4. **Message Processing**: Each worker processes messages independently

## AWS Authentication

This tool uses the AWS SDK for Go v2 and will automatically use your AWS credentials from:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. AWS credentials file (`~/.aws/credentials`)
3. IAM role (if running on EC2, ECS, or Lambda)

Make sure your AWS credentials have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:*:*:*"
    }
  ]
}
```

## Example Output

```
Listening for messages on queue: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
Workers: 5, Max messages per batch: 10, Wait time: 20s
Press Ctrl+C to stop...

[Worker 0] ========== New Message ==========
[Worker 0] Message ID: abc123-def456-ghi789
[Worker 0] Body: {"event": "order.created", "order_id": 12345}
[Worker 0] Attributes:
[Worker 0]   SentTimestamp: 1634567890000
[Worker 0]   ApproximateReceiveCount: 1
[Worker 0] ================================

[Worker 1] ========== New Message ==========
[Worker 1] Message ID: xyz789-uvw456-rst123
[Worker 1] Body: Hello, SQS!
[Worker 1] ================================
[Worker 1] Deleted message xyz789-uvw456-rst123

^C
Shutting down gracefully...
Shutdown complete
```

## Best Practices

1. **Set appropriate visibility timeout**: Should be longer than your maximum processing time to prevent duplicate processing
2. **Use long polling**: Set `-wait-time 20` to reduce API costs and improve efficiency
3. **Scale workers based on load**: Adjust `-workers` based on your message volume and processing complexity
4. **Delete messages**: Use `-delete` flag after successful processing to prevent reprocessing
5. **Handle errors**: The command will retry on errors with exponential backoff

## Exit Codes

- `0` - Success (graceful shutdown via SIGINT/SIGTERM)
- `1` - Error (configuration error, AWS error, etc.)

## Notes

- Messages are processed concurrently by the worker pool
- Each worker processes one message at a time
- The visibility timeout is set per batch of received messages
- Without `-delete`, messages will become visible again after the visibility timeout
- The command runs indefinitely until interrupted (Ctrl+C)
