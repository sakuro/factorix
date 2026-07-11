package cli

import (
	"bytes"
	"encoding/binary"
	"io"
	"net"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// fakeRCONServer accepts one connection, authenticates any password, and
// echoes exec bodies back (empty response for the "/c" sentinel).
type fakeRCONServer struct {
	listener net.Listener
	commands chan string
}

func newFakeRCONServer(t *testing.T) *fakeRCONServer {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	s := &fakeRCONServer{listener: listener, commands: make(chan string, 16)}
	t.Cleanup(func() { _ = listener.Close() })
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		for {
			var size int32
			if err := binary.Read(conn, binary.LittleEndian, &size); err != nil {
				return
			}
			payload := make([]byte, size)
			if _, err := io.ReadFull(conn, payload); err != nil {
				return
			}
			id := int32(binary.LittleEndian.Uint32(payload[0:4]))
			packetType := int32(binary.LittleEndian.Uint32(payload[4:8]))
			body := string(payload[8 : size-2])

			reply := func(replyID, replyType int32, replyBody string) {
				var buf bytes.Buffer
				_ = binary.Write(&buf, binary.LittleEndian, int32(8+len(replyBody)+2))
				_ = binary.Write(&buf, binary.LittleEndian, replyID)
				_ = binary.Write(&buf, binary.LittleEndian, replyType)
				buf.WriteString(replyBody)
				buf.Write([]byte{0, 0})
				_, _ = conn.Write(buf.Bytes())
			}
			switch packetType {
			case 3: // auth
				reply(id, 2, "")
			case 2: // exec
				s.commands <- body
				if body == "/c" {
					reply(id, 0, "")
				} else {
					reply(id, 0, "echo:"+body)
				}
			}
		}
	}()
	return s
}

func (s *fakeRCONServer) port() string {
	return strconv.Itoa(s.listener.Addr().(*net.TCPAddr).Port)
}

func TestRConExec(t *testing.T) {
	newSandbox(t)
	server := newFakeRCONServer(t)

	out, err := runCLI(t, "rcon", "exec", "/players", "--host", "127.0.0.1", "--port", server.port(), "--password", "pw")
	require.NoError(t, err)
	assert.Equal(t, "echo:/players\n", out)
	assert.Equal(t, "/players", <-server.commands)
	assert.Equal(t, "/c", <-server.commands)
}

func TestRConEvalFromStdin(t *testing.T) {
	newSandbox(t)
	server := newFakeRCONServer(t)

	out, err := runCLIWithStdin(t, "print(1)", "rcon", "eval", "--host", "127.0.0.1", "--port", server.port(), "--password", "pw")
	require.NoError(t, err)
	assert.Equal(t, "echo:/c print(1)\n", out)
	assert.Equal(t, "/c print(1)", <-server.commands)
}

func TestRConConnectionRefused(t *testing.T) {
	newSandbox(t)
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	port := strconv.Itoa(listener.Addr().(*net.TCPAddr).Port)
	require.NoError(t, listener.Close())

	_, err = runCLI(t, "rcon", "exec", "/players", "--host", "127.0.0.1", "--port", port, "--password", "pw")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "RCON connection error")
}
