package api

import (
	"fmt"
	"net/url"
	"strings"
)

// MODDownloadAPI builds authenticated MOD download URLs. Credentials are
// resolved lazily so the environment is only consulted when a download
// actually happens; the download itself is performed by internal/transfer.
type MODDownloadAPI struct {
	Credentials func() (ServiceCredential, error)
	BaseURL     string
}

// NewMODDownloadAPI builds a download-URL builder with the default base URL.
func NewMODDownloadAPI(credentials func() (ServiceCredential, error)) *MODDownloadAPI {
	return &MODDownloadAPI{Credentials: credentials, BaseURL: DefaultPortalBaseURL}
}

// DownloadURL turns a relative download path from a Release into a full URL
// with the username/token credentials attached.
func (a *MODDownloadAPI) DownloadURL(downloadPath string) (string, error) {
	if !strings.HasPrefix(downloadPath, "/") {
		return "", fmt.Errorf("%w: download URL must be a relative path starting with '/', got %q", ErrInvalidArgument, downloadPath)
	}
	credential, err := a.Credentials()
	if err != nil {
		return "", err
	}
	params := url.Values{}
	params.Set("username", credential.Username())
	params.Set("token", credential.Token())
	return a.BaseURL + downloadPath + "?" + params.Encode(), nil
}
