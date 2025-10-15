#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SQS + EventBridge Integration Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Get outputs from Terraform
cd tf/workspaces/root

echo -e "${YELLOW}→ Getting queue URLs from Terraform...${NC}"
SOURCE_QUEUE=$(terraform output -raw source_queue_url)
TARGET_QUEUE=$(terraform output -raw target_queue_url)
EVENT_BUS=$(terraform output -raw event_bus_name)

# Restore
cd ../../..

if [ -z "$SOURCE_QUEUE" ] || [ -z "$TARGET_QUEUE" ]; then
    echo -e "${RED}✗ Error: Could not get queue URLs from Terraform${NC}"
    echo -e "${YELLOW}  Make sure you've run 'terraform apply' first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Source Queue: ${SOURCE_QUEUE}${NC}"
echo -e "${GREEN}✓ Target Queue: ${TARGET_QUEUE}${NC}"
echo -e "${GREEN}✓ Event Bus: ${EVENT_BUS}${NC}\n"

# Build the commands
echo -e "${YELLOW}→ Building publish and subscribe commands...${NC}"
make build 2>&1 | grep -v "^go: downloading" || true
echo -e "${GREEN}✓ Commands built${NC}\n"

# Test 1: Send a message to source queue
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test 1: Send message to source queue${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

ORDER_MESSAGE='{
  "orderId": "ORD-'$(date +%s)'",
  "customerId": "CUST-12345",
  "amount": 99.99,
  "currency": "USD",
  "status": "pending",
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

echo -e "${YELLOW}→ Sending order message to source queue...${NC}"
echo -e "${YELLOW}  Message: ${ORDER_MESSAGE}${NC}\n"

./bin/publish -queue "$SOURCE_QUEUE" -message "$ORDER_MESSAGE"
echo ""

# Wait for EventBridge to process
echo -e "${YELLOW}→ Waiting 10 seconds for EventBridge to process...${NC}"
sleep 10
echo ""

# Test 2: Check target queue for the event
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test 2: Receive one message from target queue${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}→ Receiving one message from target queue...${NC}\n"

# Use subscribe command to receive one message
./bin/subscribe -queue "$TARGET_QUEUE" -max-messages 1 -workers 1 -delete &
SUBSCRIBE_PID=$!

# Wait 5 seconds for message
sleep 5

# Kill the subscriber
kill $SUBSCRIBE_PID 2>/dev/null || true
wait $SUBSCRIBE_PID 2>/dev/null || true

echo ""

# Test 3: Send multiple messages
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test 3: Send multiple messages${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}→ Sending 3 messages to source queue...${NC}\n"

for i in {1..3}; do
    MSG='{
      "orderId": "ORD-'$(date +%s)'-'$i'",
      "customerId": "CUST-'$i'",
      "amount": '$((RANDOM % 500 + 50))'.99,
      "currency": "USD",
      "status": "pending",
      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
    
    echo -e "  ${GREEN}[$i/3]${NC} Sending order..."
    ./bin/publish -queue "$SOURCE_QUEUE" -message "$MSG" | grep "Message ID"
    sleep 1
done

echo ""
echo -e "${YELLOW}→ Waiting 10 seconds for EventBridge to process...${NC}"
sleep 10
echo ""

# Test 4: Subscribe to target queue with workers
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test 4: Subscribe to target queue (5 seconds)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}→ Starting subscriber with 3 workers...${NC}"
echo -e "${YELLOW}  Will run for 5 seconds to process remaining messages${NC}\n"

./bin/subscribe -queue "$TARGET_QUEUE" -workers 3 -delete &
SUBSCRIBE_PID=$!

# Wait 5 seconds
sleep 5

# Stop the subscriber
kill $SUBSCRIBE_PID 2>/dev/null || true
wait $SUBSCRIBE_PID 2>/dev/null || true

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Integration test complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Summary:${NC}"
echo -e "  • Messages flow: Source Queue → EventBridge Pipe → EventBridge Bus → Rule → Target Queue"
echo -e "  • You can use ./bin/publish to send messages"
echo -e "  • You can use ./bin/subscribe to receive messages"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  • View EventBridge metrics in AWS Console"
echo -e "  • Check CloudWatch Logs for pipe execution details"
echo -e "  • Review registered schemas in AWS Console"
echo ""
