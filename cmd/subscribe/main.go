package main

import (
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
	deleteOnRead   = flag.Bool("delete", false, "Delete messages after processing")
)

type Message struct {
	Body          string
	MessageID     string
	ReceiptHandle string
	Attributes    map[string]string
}

// Event structures matching the JSON schemas

type OrderItem struct {
	SKU      string  `json:"sku"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

type OrderCreated struct {
	OrderID    string      `json:"orderId"`
	CustomerID string      `json:"customerId"`
	Amount     float64     `json:"amount"`
	Currency   string      `json:"currency"`
	Items      []OrderItem `json:"items,omitempty"`
	Status     string      `json:"status"`
	Timestamp  string      `json:"timestamp"`
}

type OrderUpdated struct {
	OrderID        string   `json:"orderId"`
	Status         string   `json:"status"`
	PreviousStatus string   `json:"previousStatus,omitempty"`
	UpdatedFields  []string `json:"updatedFields,omitempty"`
	Timestamp      string   `json:"timestamp"`
}

type PaymentProcessed struct {
	PaymentID     string  `json:"paymentId"`
	OrderID       string  `json:"orderId"`
	CustomerID    string  `json:"customerId,omitempty"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	PaymentMethod string  `json:"paymentMethod"`
	Status        string  `json:"status"`
	TransactionID string  `json:"transactionId,omitempty"`
	Timestamp     string  `json:"timestamp"`
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

	// Try to decode the message body as JSON and determine the event type
	var rawEvent map[string]interface{}
	if err := json.Unmarshal([]byte(msg.Body), &rawEvent); err != nil {
		fmt.Printf("[Worker %d] Failed to parse JSON: %v\n", workerID, err)
		fmt.Printf("[Worker %d] Raw Body: %s\n", workerID, msg.Body)
		return
	}

	// Determine event type based on fields present
	eventType := determineEventType(rawEvent)
	fmt.Printf("[Worker %d] Event Type: %s\n", workerID, eventType)

	switch eventType {
	case "OrderCreated":
		var event OrderCreated
		if err := json.Unmarshal([]byte(msg.Body), &event); err != nil {
			fmt.Printf("[Worker %d] Error decoding OrderCreated: %v\n", workerID, err)
			return
		}
		fmt.Printf("[Worker %d] Order ID: %s\n", workerID, event.OrderID)
		fmt.Printf("[Worker %d] Customer ID: %s\n", workerID, event.CustomerID)
		fmt.Printf("[Worker %d] Amount: %.2f %s\n", workerID, event.Amount, event.Currency)
		fmt.Printf("[Worker %d] Status: %s\n", workerID, event.Status)
		if len(event.Items) > 0 {
			fmt.Printf("[Worker %d] Items: %d\n", workerID, len(event.Items))
			for i, item := range event.Items {
				fmt.Printf("[Worker %d]   Item %d: %s (qty: %d, price: %.2f)\n",
					workerID, i+1, item.SKU, item.Quantity, item.Price)
			}
		}
		fmt.Printf("[Worker %d] Timestamp: %s\n", workerID, event.Timestamp)

	case "OrderUpdated":
		var event OrderUpdated
		if err := json.Unmarshal([]byte(msg.Body), &event); err != nil {
			fmt.Printf("[Worker %d] Error decoding OrderUpdated: %v\n", workerID, err)
			return
		}
		fmt.Printf("[Worker %d] Order ID: %s\n", workerID, event.OrderID)
		fmt.Printf("[Worker %d] Status: %s", workerID, event.Status)
		if event.PreviousStatus != "" {
			fmt.Printf(" (was: %s)", event.PreviousStatus)
		}
		fmt.Println()
		if len(event.UpdatedFields) > 0 {
			fmt.Printf("[Worker %d] Updated Fields: %v\n", workerID, event.UpdatedFields)
		}
		fmt.Printf("[Worker %d] Timestamp: %s\n", workerID, event.Timestamp)

	case "PaymentProcessed":
		var event PaymentProcessed
		if err := json.Unmarshal([]byte(msg.Body), &event); err != nil {
			fmt.Printf("[Worker %d] Error decoding PaymentProcessed: %v\n", workerID, err)
			return
		}
		fmt.Printf("[Worker %d] Payment ID: %s\n", workerID, event.PaymentID)
		fmt.Printf("[Worker %d] Order ID: %s\n", workerID, event.OrderID)
		if event.CustomerID != "" {
			fmt.Printf("[Worker %d] Customer ID: %s\n", workerID, event.CustomerID)
		}
		fmt.Printf("[Worker %d] Amount: %.2f %s\n", workerID, event.Amount, event.Currency)
		fmt.Printf("[Worker %d] Payment Method: %s\n", workerID, event.PaymentMethod)
		fmt.Printf("[Worker %d] Status: %s\n", workerID, event.Status)
		if event.TransactionID != "" {
			fmt.Printf("[Worker %d] Transaction ID: %s\n", workerID, event.TransactionID)
		}
		fmt.Printf("[Worker %d] Timestamp: %s\n", workerID, event.Timestamp)

	default:
		fmt.Printf("[Worker %d] Unknown event type\n", workerID)
		fmt.Printf("[Worker %d] Raw Body: %s\n", workerID, msg.Body)
	}

	if len(msg.Attributes) > 0 {
		fmt.Printf("[Worker %d] SQS Attributes:\n", workerID)
		for k, v := range msg.Attributes {
			fmt.Printf("[Worker %d]   %s: %s\n", workerID, k, v)
		}
	}

	fmt.Printf("[Worker %d] ================================\n", workerID)

	// Simulate processing time
	time.Sleep(100 * time.Millisecond)
}

// determineEventType inspects the JSON fields to determine which event type it is
func determineEventType(event map[string]interface{}) string {
	// Check for distinctive fields in each event type
	if _, hasPaymentID := event["paymentId"]; hasPaymentID {
		return "PaymentProcessed"
	}

	if _, hasCustomerID := event["customerId"]; hasCustomerID {
		if _, hasAmount := event["amount"]; hasAmount {
			if _, hasItems := event["items"]; hasItems {
				return "OrderCreated"
			}
		}
	}

	if _, hasPreviousStatus := event["previousStatus"]; hasPreviousStatus {
		return "OrderUpdated"
	}

	if _, hasOrderID := event["orderId"]; hasOrderID {
		if _, hasStatus := event["status"]; hasStatus {
			// Could be OrderCreated or OrderUpdated, check for more distinctive fields
			if _, hasCustomerID := event["customerId"]; hasCustomerID {
				return "OrderCreated"
			}
			return "OrderUpdated"
		}
	}

	return "Unknown"
}

func deleteMessage(ctx context.Context, client *sqs.Client, receiptHandle string) error {
	_, err := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      queueURL,
		ReceiptHandle: &receiptHandle,
	})
	return err
}
