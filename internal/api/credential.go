package api

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	envUsername = "FACTORIO_USERNAME"
	envToken    = "FACTORIO_TOKEN"
	envAPIKey   = "FACTORIO_API_KEY"
)

// ServiceCredential is the username/token pair used by the download
// endpoints. Fields are unexported so the values do not leak through
// formatting; String renders masked.
type ServiceCredential struct {
	username string
	token    string
}

// Username returns the service username.
func (c ServiceCredential) Username() string {
	return c.username
}

// Token returns the service token.
func (c ServiceCredential) Token() string {
	return c.token
}

func (ServiceCredential) String() string {
	return `ServiceCredential{username: "*****", token: "*****"}`
}

// LoadServiceCredential loads the username/token pair from the environment
// (FACTORIO_USERNAME / FACTORIO_TOKEN), falling back to player-data.json at
// the given path when neither is set. Setting only one variable is an error.
func LoadServiceCredential(playerDataPath string) (ServiceCredential, error) {
	username := os.Getenv(envUsername)
	token := os.Getenv(envToken)

	switch {
	case username != "" && token != "":
		return ServiceCredential{username: username, token: token}, nil
	case username != "" || token != "":
		return ServiceCredential{}, fmt.Errorf("%w: both %s and %s must be set (or neither)", ErrCredential, envUsername, envToken)
	}

	data, err := os.ReadFile(playerDataPath)
	if err != nil {
		return ServiceCredential{}, fmt.Errorf("%w: cannot read player-data.json: %s", ErrCredential, err)
	}
	var playerData struct {
		ServiceUsername string `json:"service-username"`
		ServiceToken    string `json:"service-token"`
	}
	if err := json.Unmarshal(data, &playerData); err != nil {
		return ServiceCredential{}, fmt.Errorf("%w: invalid player-data.json: %s", ErrCredential, err)
	}
	if playerData.ServiceUsername == "" {
		return ServiceCredential{}, fmt.Errorf("%w: service-username is missing in player-data.json", ErrCredential)
	}
	if playerData.ServiceToken == "" {
		return ServiceCredential{}, fmt.Errorf("%w: service-token is missing in player-data.json", ErrCredential)
	}
	return ServiceCredential{username: playerData.ServiceUsername, token: playerData.ServiceToken}, nil
}

// APICredential is the API key required by the management API.
type APICredential struct {
	apiKey string
}

// APIKey returns the API key.
func (c APICredential) APIKey() string {
	return c.apiKey
}

func (APICredential) String() string {
	return `APICredential{api_key: "*****"}`
}

// LoadAPICredential loads the API key from FACTORIO_API_KEY.
func LoadAPICredential() (APICredential, error) {
	apiKey := os.Getenv(envAPIKey)
	if apiKey == "" {
		return APICredential{}, fmt.Errorf("%w: %s environment variable is not set", ErrCredential, envAPIKey)
	}
	return APICredential{apiKey: apiKey}, nil
}
