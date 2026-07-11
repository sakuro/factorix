package rcon

import (
	"bytes"
	"context"
	"encoding/binary"
	"io"
	"net"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// fakeServer speaks just enough RCON for the tests: it authenticates
// against a fixed password and answers every exec with handle.
type fakeServer struct {
	listener net.Listener
	password string
	// handle maps a received command body to response bodies (multiple
	// entries model a fragmented response).
	handle func(command string) []string
	// commands records every exec body received.
	commands []string
}

func newFakeServer(t *testing.T, password string, handle func(string) []string) *fakeServer {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	s := &fakeServer{listener: listener, password: password, handle: handle}
	go s.serve()
	t.Cleanup(func() { _ = listener.Close() })
	return s
}

func (s *fakeServer) port() int {
	return s.listener.Addr().(*net.TCPAddr).Port
}

func (s *fakeServer) serve() {
	conn, err := s.listener.Accept()
	if err != nil {
		return
	}
	defer conn.Close()
	for {
		id, packetType, body, err := readPacket(conn)
		if err != nil {
			return
		}
		switch packetType {
		case typeAuth:
			if string(body) == s.password {
				writePacket(conn, id, typeExecCommand, "")
			} else {
				writePacket(conn, -1, typeExecCommand, "")
			}
		case typeExecCommand:
			s.commands = append(s.commands, string(body))
			for _, part := range s.handle(string(body)) {
				writePacket(conn, id, typeResponseValue, part)
			}
		}
	}
}

func readPacket(conn net.Conn) (id, packetType int32, body []byte, err error) {
	var size int32
	if err := binary.Read(conn, binary.LittleEndian, &size); err != nil {
		return 0, 0, nil, err
	}
	payload := make([]byte, size)
	if _, err := io.ReadFull(conn, payload); err != nil {
		return 0, 0, nil, err
	}
	id = int32(binary.LittleEndian.Uint32(payload[0:4]))
	packetType = int32(binary.LittleEndian.Uint32(payload[4:8]))
	return id, packetType, payload[8 : size-2], nil
}

func writePacket(conn net.Conn, id, packetType int32, body string) {
	var buf bytes.Buffer
	_ = binary.Write(&buf, binary.LittleEndian, int32(8+len(body)+2))
	_ = binary.Write(&buf, binary.LittleEndian, id)
	_ = binary.Write(&buf, binary.LittleEndian, packetType)
	buf.WriteString(body)
	buf.Write([]byte{0, 0})
	_, _ = conn.Write(buf.Bytes())
}

// echoOrEmpty responds to the sentinel with nothing and echoes everything
// else in two fragments.
func echoOrEmpty(command string) []string {
	if command == "/c" {
		return []string{""}
	}
	half := len(command) / 2
	return []string{command[:half], command[half:]}
}

func TestExecuteReassemblesFragments(t *testing.T) {
	s := newFakeServer(t, "secret", echoOrEmpty)
	client, err := Dial(context.Background(), "127.0.0.1", s.port(), "secret", "/c")
	require.NoError(t, err)
	defer client.Close()

	result, err := client.Execute("/server-save now")
	require.NoError(t, err)
	assert.Equal(t, "/server-save now", result)
	assert.Equal(t, []string{"/server-save now", "/c"}, s.commands)
}

func TestDialAuthenticationFailure(t *testing.T) {
	s := newFakeServer(t, "secret", echoOrEmpty)
	_, err := Dial(context.Background(), "127.0.0.1", s.port(), "wrong", "/c")
	require.ErrorIs(t, err, ErrAuthentication)
}

func TestDialConnectionRefused(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	port := listener.Addr().(*net.TCPAddr).Port
	require.NoError(t, listener.Close())

	_, err = Dial(context.Background(), "127.0.0.1", port, "secret", "/c")
	require.ErrorIs(t, err, ErrConnection)
}

func TestExecuteBodyTooLong(t *testing.T) {
	s := newFakeServer(t, "secret", echoOrEmpty)
	client, err := Dial(context.Background(), "127.0.0.1", s.port(), "secret", "/c")
	require.NoError(t, err)
	defer client.Close()

	_, err = client.Execute(strings.Repeat("x", 512))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "body too long (512 > 511)")
}

func TestExecuteServerClosesConnection(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	t.Cleanup(func() { _ = listener.Close() })
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		// Complete the auth handshake, then hang up.
		id, _, _, err := readPacket(conn)
		if err == nil {
			writePacket(conn, id, typeExecCommand, "")
		}
		_ = conn.Close()
	}()

	client, err := Dial(context.Background(), "127.0.0.1", listener.Addr().(*net.TCPAddr).Port, "secret", "/c")
	require.NoError(t, err)
	defer client.Close()

	_, err = client.Execute("/players")
	require.ErrorIs(t, err, ErrConnection)
	assert.Contains(t, err.Error(), "connection closed by server")
}
