package aws

import (
	"encoding/json"
	"fmt"
	"time"
)

type Event struct {
	Account    string    `json:"account"`
	DetailType string    `json:"detail-type"`
	Id         string    `json:"id"`
	Region     string    `json:"region"`
	Resources  []string  `json:"resources"`
	Source     string    `json:"source"`
	Time       time.Time `json:"time"`
	Version    string    `json:"version"`
}

func MarshalJSON(bytes []byte) (any, error) {
	// Attempt to unmarshal into ObjectCreated or ObjectDeleted based on detail-type
	var base Event
	if err := json.Unmarshal(bytes, &base); err != nil {
		return nil, err
	}

	switch base.DetailType {
	case "Object Created":
		var objCreated ObjectCreated
		if err := json.Unmarshal(bytes, &objCreated); err != nil {
			return nil, err
		}
		return objCreated, nil
	case "Object Deleted":
		var objDeleted ObjectDeleted
		if err := json.Unmarshal(bytes, &objDeleted); err != nil {
			return nil, err
		}
		return objDeleted, nil
	default:
		return nil, fmt.Errorf("unknown detail-type: %s", base.DetailType)
	}
}
