package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/eventbridge"
	"github.com/aws/aws-sdk-go-v2/service/eventbridge/types"
)

var (
	eventBus   = flag.String("bus", "default", "EventBridge event bus name")
	source     = flag.String("source", "", "Event source identifier (e.g. myapp.orders)")
	detailType = flag.String("detail-type", "", "Event detail type (e.g. OrderCreated)")
	message    = flag.String("message", "", "Event detail payload (JSON)")
	resources  = flag.String("resources", "", "Comma-separated list of resource ARNs to include (optional)")
	traceID    = flag.String("trace-header", "", "X-Ray trace header (optional)")
)

func main() {
	flag.Parse()

	if *source == "" {
		fmt.Fprintln(os.Stderr, "Error: -source is required")
		flag.Usage()
		os.Exit(1)
	}

	if *detailType == "" {
		fmt.Fprintln(os.Stderr, "Error: -detail-type is required")
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

	client := eventbridge.NewFromConfig(cfg)

	detail, err := prepareDetail(*message)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Invalid -message payload: %v\n", err)
		os.Exit(1)
	}

	entry := types.PutEventsRequestEntry{
		EventBusName: aws.String(*eventBus),
		Source:       aws.String(*source),
		DetailType:   aws.String(*detailType),
		Detail:       aws.String(detail),
		Time:         aws.Time(time.Now()),
	}

	if strings.TrimSpace(*resources) != "" {
		entry.Resources = splitAndTrim(*resources)
	}

	if strings.TrimSpace(*traceID) != "" {
		entry.TraceHeader = aws.String(strings.TrimSpace(*traceID))
	}

	resp, err := client.PutEvents(ctx, &eventbridge.PutEventsInput{
		Entries: []types.PutEventsRequestEntry{entry},
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending event: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Entries) == 0 {
		fmt.Fprintln(os.Stderr, "No response entries returned from EventBridge")
		os.Exit(1)
	}

	result := resp.Entries[0]
	if result.ErrorCode != nil {
		fmt.Fprintf(os.Stderr, "EventBridge error (%s): %s\n", aws.ToString(result.ErrorCode), aws.ToString(result.ErrorMessage))
		os.Exit(1)
	}

	fmt.Printf("Event sent successfully to bus %s\n", *eventBus)
	fmt.Printf("Event ID: %s\n", aws.ToString(result.EventId))

}

func prepareDetail(input string) (string, error) {
	if strings.TrimSpace(input) == "" {
		return "", fmt.Errorf("detail payload cannot be empty")
	}

	if json.Valid([]byte(input)) {
		return input, nil
	}

	// Wrap plain text in JSON string
	encoded, err := json.Marshal(input)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

func splitAndTrim(value string) []string {
	parts := strings.Split(value, ",")
	var cleaned []string
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	return cleaned

}
