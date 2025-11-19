package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

var (
	queueURL       = flag.String("queue", "", "SQS queue URL")
	maxMessages    = flag.Int("max-messages", 10, "Maximum number of messages to receive per request (1-10)")
	waitTime       = flag.Int("wait-time", 20, "Long polling wait time in seconds (0-20)")
	visibilityTime = flag.Int("visibility", 30, "Visibility timeout in seconds")
	workers        = flag.Int("workers", 5, "Number of concurrent worker goroutines")
	deleteOnRead   = flag.Bool("delete", true, "Delete messages after processing")
)

type Message struct {
	Body          string
	MessageID     string
	ReceiptHandle string
	Attributes    map[string]string
}

func main() {
	flag.Parse()

	if *queueURL == "" {
		fmt.Fprintln(os.Stderr, "Error: -queue is required")
		flag.Usage()
		os.Exit(1)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle interrupt signals for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading AWS config: %v\n", err)
		os.Exit(1)
	}

	// Create SQS client
	client := sqs.NewFromConfig(cfg)

	// Create message channel and worker pool
	messageChan := make(chan Message, *maxMessages)
	var wg sync.WaitGroup

	// Start worker goroutines
	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go worker(ctx, i, messageChan, client, &wg)
	}

	// Start message receiver
	go receiveMessages(ctx, client, messageChan)

	fmt.Printf("Listening for messages on queue: %s\n", *queueURL)
	fmt.Printf("Workers: %d, Max messages per batch: %d, Wait time: %ds\n", *workers, *maxMessages, *waitTime)
	fmt.Println("Press Ctrl+C to stop...")

	// Wait for interrupt signal
	<-sigChan
	fmt.Println("\nShutting down gracefully...")
	cancel()

	// Close message channel and wait for workers to finish
	close(messageChan)
	wg.Wait()

	fmt.Println("Shutdown complete")
}

func receiveMessages(ctx context.Context, client *sqs.Client, messageChan chan<- Message) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			// Receive messages from SQS
			result, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
				QueueUrl:            queueURL,
				MaxNumberOfMessages: int32(*maxMessages),
				WaitTimeSeconds:     int32(*waitTime),
				VisibilityTimeout:   int32(*visibilityTime),
				AttributeNames: []types.QueueAttributeName{
					types.QueueAttributeNameAll,
				},
			})

			if err != nil {
				fmt.Fprintf(os.Stderr, "Error receiving messages: %v\n", err)
				time.Sleep(5 * time.Second)
				continue
			}

			// Send each message to the worker pool
			for _, msg := range result.Messages {
				message := Message{
					Body:          *msg.Body,
					MessageID:     *msg.MessageId,
					ReceiptHandle: *msg.ReceiptHandle,
					Attributes:    make(map[string]string),
				}

				// Copy attributes
				for k, v := range msg.Attributes {
					message.Attributes[k] = v
				}

				select {
				case messageChan <- message:
				case <-ctx.Done():
					return
				}
			}
		}
	}
}

func worker(ctx context.Context, id int, messageChan <-chan Message, client *sqs.Client, wg *sync.WaitGroup) {
	defer wg.Done()

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-messageChan:
			if !ok {
				return
			}

			// Process the message
			processMessage(id, msg)

			// Delete message if flag is set
			if *deleteOnRead {
				if err := deleteMessage(ctx, client, msg.ReceiptHandle); err != nil {
					fmt.Fprintf(os.Stderr, "[Worker %d] Error deleting message %s: %v\n", id, msg.MessageID, err)
				} else {
					fmt.Printf("[Worker %d] Deleted message %s\n", id, msg.MessageID)
				}
			}
		}
	}
}

func processMessage(workerID int, msg Message) {
	fmt.Printf("\n[Worker %d] ========== New Message ==========\n", workerID)
	fmt.Printf("[Worker %d] Message ID: %s\n", workerID, msg.MessageID)

	if formatted, ok := prettyJSON(msg.Body); ok {
		fmt.Printf("[Worker %d] Event JSON:\n%s\n", workerID, formatted)
	} else {
		fmt.Printf("[Worker %d] Body (non-JSON): %s\n", workerID, msg.Body)
	}

	if len(msg.Attributes) > 0 {
		fmt.Printf("[Worker %d] SQS Attributes:\n", workerID)
		for k, v := range msg.Attributes {
			fmt.Printf("[Worker %d]   %s: %s\n", workerID, k, v)
		}
	}

	fmt.Printf("[Worker %d] ================================\n", workerID)

	// Small pause to avoid spamming logs when throughput is very high
	time.Sleep(50 * time.Millisecond)
}

func prettyJSON(body string) (string, bool) {
	var buf bytes.Buffer
	if err := json.Indent(&buf, []byte(body), "", "  "); err != nil {
		return "", false
	}
	return buf.String(), true
}

func deleteMessage(ctx context.Context, client *sqs.Client, receiptHandle string) error {
	_, err := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      queueURL,
		ReceiptHandle: &receiptHandle,
	})
	return err
}
