package aws

type Bucket struct {
	Name string `json:"name"`
}

type Object struct {
	Etag      string  `json:"etag"`
	Key       string  `json:"key"`
	Sequencer string  `json:"sequencer"`
	Size      float64 `json:"size"`
	VersionId string  `json:"version-id,omitempty"`
}

type Detail struct {
	Bucket          Bucket `json:"bucket"`
	DeletionType    string `json:"deletion-type,omitempty"`
	Object          Object `json:"object"`
	Reason          string `json:"reason"`
	RequestId       string `json:"request-id"`
	Requester       string `json:"requester"`
	SourceIpAddress string `json:"source-ip-address"`
	Version         string `json:"version"`
}

type ObjectCreated struct {
	Event
	Detail Detail `json:"detail"`
}

type ObjectDeleted struct {
	Event
	Detail Detail `json:"detail"`
}
