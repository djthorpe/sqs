package custom

// Event structures matching the JSON schemas
type OrderItem struct {
	SKU      string  `json:"sku"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

type Event struct {
	OrderID    string `json:"orderId"`
	CustomerID string `json:"customerId"`
	Status     string `json:"status"`
	Timestamp  string `json:"timestamp"`
}

type OrderCreated struct {
	Event
	Amount   float64     `json:"amount"`
	Currency string      `json:"currency"`
	Items    []OrderItem `json:"items,omitempty"`
}

type OrderUpdated struct {
	Event
	PreviousStatus string   `json:"previousStatus,omitempty"`
	UpdatedFields  []string `json:"updatedFields,omitempty"`
}

type PaymentProcessed struct {
	Event
	PaymentID     string  `json:"paymentId"`
	TransactionID string  `json:"transactionId,omitempty"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	PaymentMethod string  `json:"paymentMethod"`
}
