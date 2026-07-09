package transfer

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"maps"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/sakuro/factorix/internal/httpx"
	"github.com/sakuro/factorix/internal/progress"
)

var mimeTypes = map[string]string{
	".zip":  "application/zip",
	".png":  "image/png",
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".gif":  "image/gif",
}

const defaultMIMEType = "application/octet-stream"

// Uploader posts files as multipart/form-data. It implements the api.Uploader
// interface. The multipart body is staged in a temporary file so arbitrarily
// large MOD ZIPs never sit in memory; the body is not replayable, so the
// retry transport performs uploads exactly once.
type Uploader struct {
	Client *httpx.Client
	Logger *slog.Logger
	// Listener receives progress for uploads performed by this Uploader.
	// It is a field rather than a parameter because the api.Uploader
	// interface knows nothing about progress; the CLI sets it per command.
	Listener progress.Listener
}

// NewUploader builds an uploader.
func NewUploader(client *httpx.Client, logger *slog.Logger) *Uploader {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &Uploader{Client: client, Logger: logger}
}

// Upload posts the file to uploadURL with the given extra form fields.
// fieldName is the file's form field; empty means "file". It returns the
// response body.
func (u *Uploader) Upload(ctx context.Context, uploadURL, filePath string, fields map[string]string, fieldName string) ([]byte, error) {
	if fieldName == "" {
		fieldName = "file"
	}
	u.Logger.Info("Uploading file", "url", httpx.MaskURL(mustParseForLog(uploadURL), []string{"username", "token", "secure"}), "file", filePath)

	body, size, err := u.buildMultipartFile(filePath, fields, fieldName)
	if err != nil {
		return nil, err
	}
	defer os.Remove(body.Name())
	defer body.Close()

	progress.Start(u.Listener, size)
	reader := io.TeeReader(body, &countingWriter{listener: u.Listener})

	header := http.Header{}
	header.Set("Content-Type", body.contentType)

	resp, err := u.Client.Request(ctx, http.MethodPost, uploadURL, header, reader)
	if err != nil {
		return nil, err
	}
	progress.Finish(u.Listener)
	u.Logger.Info("Upload completed", "file", filePath)
	return resp.Body, nil
}

// multipartFile is the staged multipart body with its content type.
type multipartFile struct {
	*os.File
	contentType string
}

// buildMultipartFile stages the complete multipart body in a temporary file
// and returns it positioned at the start, along with its total size.
func (u *Uploader) buildMultipartFile(filePath string, fields map[string]string, fieldName string) (*multipartFile, int64, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, 0, err
	}
	defer file.Close()

	tmp, err := os.CreateTemp("", "factorix-upload")
	if err != nil {
		return nil, 0, err
	}
	cleanup := func() {
		tmp.Close()
		os.Remove(tmp.Name())
	}

	writer := multipart.NewWriter(tmp)

	// Deterministic field order keeps requests reproducible.
	for _, name := range slices.Sorted(maps.Keys(fields)) {
		if err := writer.WriteField(name, fields[name]); err != nil {
			cleanup()
			return nil, 0, err
		}
	}

	partHeader := textproto.MIMEHeader{}
	partHeader.Set("Content-Disposition",
		fmt.Sprintf(`form-data; name=%q; filename=%q`, fieldName, filepath.Base(filePath)))
	partHeader.Set("Content-Type", detectContentType(filePath))
	part, err := writer.CreatePart(partHeader)
	if err != nil {
		cleanup()
		return nil, 0, err
	}
	if _, err := io.Copy(part, file); err != nil {
		cleanup()
		return nil, 0, err
	}
	if err := writer.Close(); err != nil {
		cleanup()
		return nil, 0, err
	}

	size, err := tmp.Seek(0, io.SeekEnd)
	if err != nil {
		cleanup()
		return nil, 0, err
	}
	if _, err := tmp.Seek(0, io.SeekStart); err != nil {
		cleanup()
		return nil, 0, err
	}
	return &multipartFile{File: tmp, contentType: writer.FormDataContentType()}, size, nil
}

func detectContentType(filePath string) string {
	if mimeType, ok := mimeTypes[strings.ToLower(filepath.Ext(filePath))]; ok {
		return mimeType
	}
	return defaultMIMEType
}

// mustParseForLog parses the URL for masking; on failure the raw string is
// not logged at all.
func mustParseForLog(rawURL string) *url.URL {
	u, err := url.Parse(rawURL)
	if err != nil {
		return &url.URL{}
	}
	return u
}
