# SQS Publish Command

A command-line tool to publish messages to an AWS SQS queue.

## Installation

```bash
go build -o publish ./cmd/publish
```

Or from the project root:

```bash
make build-publish
```

## Usage

### Basic Usage

```bash
./publish -queue <queue-url> -message <message-body>
```

### Examples

#### Publish a simple message

```bash
./publish \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue" \
  -message "Hello, SQS!"
```

#### Publish to a FIFO queue

```bash
./publish \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue.fifo" \
  -message "Hello, FIFO!" \
  -group-id "my-group" \
  -dedup-id "unique-id-123"
```

#### Publish JSON message

```bash
./publish \
  -queue "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue" \
  -message '{"event": "order.created", "order_id": 12345}'
```

## Flags

| Flag | Description | Required |
|------|-------------|----------|
| `-queue` | SQS queue URL | Yes |
| `-message` | Message body to send | Yes |
| `-group-id` | Message group ID (for FIFO queues only) | No |
| `-dedup-id` | Message deduplication ID (for FIFO queues only) | No |

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
        "sqs:SendMessage"
      ],
      "Resource": "arn:aws:sqs:*:*:*"
    }
  ]
}
```

## Output

On success, the command outputs:

```
Message sent successfully
Message ID: abc123-def456-ghi789
```

For FIFO queues, it also outputs:

```
Sequence Number: 1234567890
```

## Exit Codes

- `0` - Success
- `1` - Error (configuration error, AWS error, etc.)
