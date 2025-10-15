package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

var (
	queueURL = flag.String("queue", "", "SQS queue URL")
	message  = flag.String("message", "", "Message body to send")
	groupID  = flag.String("group-id", "", "Message group ID (for FIFO queues)")
	dedupID  = flag.String("dedup-id", "", "Message deduplication ID (for FIFO queues)")
)

func main() {
	flag.Parse()

	if *queueURL == "" {
		fmt.Fprintln(os.Stderr, "Error: -queue is required")
		flag.Usage()
		os.Exit(1)
	}

	if *message == "" {
		fmt.Fprintln(os.Stderr, "Error: -message is required")
		flag.Usage()
		os.Exit(1)
	}

	ctx := context.Background()

	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading AWS config: %v\n", err)
		os.Exit(1)
	}

	// Create SQS client
	client := sqs.NewFromConfig(cfg)

	// Prepare message input
	input := &sqs.SendMessageInput{
		QueueUrl:    queueURL,
		MessageBody: message,
	}

	// Add FIFO queue parameters if provided
	if *groupID != "" {
		input.MessageGroupId = groupID
	}
	if *dedupID != "" {
		input.MessageDeduplicationId = dedupID
	}

	// Send message
	result, err := client.SendMessage(ctx, input)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending message: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Message sent successfully\n")
	fmt.Printf("Message ID: %s\n", *result.MessageId)
	if result.SequenceNumber != nil {
		fmt.Printf("Sequence Number: %s\n", *result.SequenceNumber)
	}
}
