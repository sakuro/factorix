// Package rcon is a TCP client for the Source RCON protocol, ported from
// the rcon-client gem. Factorio splits large responses across packets with
// no length indication, so Execute sends a sentinel command after the real
// one and treats the sentinel's response as the end marker.
package rcon

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"strconv"
)

// Packet types of the Source RCON protocol. An auth response arrives as
// type 2 (the same value as an exec command) with the auth request's ID, or
// -1 on failure.
const (
	typeResponseValue int32 = 0
	typeExecCommand   int32 = 2
	typeAuth          int32 = 3
)

// The server truncates bodies at 511 bytes; fail early instead.
const bodyByteLimit = 511

var (
	ErrConnection     = errors.New("RCON connection error")
	ErrAuthentication = errors.New("RCON authentication failed")
)

// Client is an authenticated RCON connection. It is not safe for
// concurrent use.
type Client struct {
	conn            net.Conn
	sentinelCommand string
	nextID          int32
}

// Dial connects and authenticates. sentinelCommand is the no-op command
// whose response marks the end of a fragmented reply ("/c" for Factorio).
func Dial(ctx context.Context, host string, port int, password, sentinelCommand string) (*Client, error) {
	var dialer net.Dialer
	conn, err := dialer.DialContext(ctx, "tcp", net.JoinHostPort(host, strconv.Itoa(port)))
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrConnection, err)
	}
	c := &Client{conn: conn, sentinelCommand: sentinelCommand}
	if err := c.authenticate(password); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return c, nil
}

// Close closes the connection.
func (c *Client) Close() error {
	return c.conn.Close()
}

// Execute sends a command and returns the server's full response,
// reassembled across packets.
func (c *Client) Execute(command string) (string, error) {
	cmdID := c.newID()
	sentinelID := c.newID()

	if err := c.send(cmdID, typeExecCommand, command); err != nil {
		return "", err
	}
	if err := c.send(sentinelID, typeExecCommand, c.sentinelCommand); err != nil {
		return "", err
	}

	var parts bytes.Buffer
	for {
		id, packetType, body, err := c.receive()
		if err != nil {
			return "", err
		}
		if packetType != typeResponseValue {
			continue
		}
		switch id {
		case cmdID:
			parts.Write(body)
		case sentinelID:
			return parts.String(), nil
		}
	}
}

func (c *Client) authenticate(password string) error {
	authID := c.newID()
	if err := c.send(authID, typeAuth, password); err != nil {
		return err
	}
	// Standard RCON sends an empty RESPONSE_VALUE before the auth response;
	// some implementations (e.g. Factorio) send the auth response directly.
	for {
		id, packetType, _, err := c.receive()
		if err != nil {
			return err
		}
		if packetType == typeResponseValue {
			continue
		}
		if id == -1 {
			return ErrAuthentication
		}
		return nil
	}
}

func (c *Client) newID() int32 {
	c.nextID++
	return c.nextID
}

// send writes one packet: size(4) + id(4) + type(4) + body + null(1) +
// empty-string(1), all little-endian.
func (c *Client) send(id, packetType int32, body string) error {
	if len(body) > bodyByteLimit {
		return fmt.Errorf("body too long (%d > %d)", len(body), bodyByteLimit)
	}
	size := int32(8 + len(body) + 2)
	var buf bytes.Buffer
	for _, v := range []int32{size, id, packetType} {
		if err := binary.Write(&buf, binary.LittleEndian, v); err != nil {
			return err
		}
	}
	buf.WriteString(body)
	buf.Write([]byte{0, 0})
	if _, err := c.conn.Write(buf.Bytes()); err != nil {
		return fmt.Errorf("%w: %s", ErrConnection, err)
	}
	return nil
}

func (c *Client) receive() (id, packetType int32, body []byte, err error) {
	var size int32
	if err := binary.Read(c.conn, binary.LittleEndian, &size); err != nil {
		return 0, 0, nil, connectionError(err)
	}
	payload := make([]byte, size)
	if _, err := io.ReadFull(c.conn, payload); err != nil {
		return 0, 0, nil, connectionError(err)
	}
	id = int32(binary.LittleEndian.Uint32(payload[0:4]))
	packetType = int32(binary.LittleEndian.Uint32(payload[4:8]))
	// The body is followed by a null terminator and an empty string.
	return id, packetType, payload[8 : size-2], nil
}

func connectionError(err error) error {
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
		return fmt.Errorf("%w: connection closed by server", ErrConnection)
	}
	return fmt.Errorf("%w: %s", ErrConnection, err)
}
