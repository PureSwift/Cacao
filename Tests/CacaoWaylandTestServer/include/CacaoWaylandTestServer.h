//
//  CacaoWaylandTestServer.h
//  Cacao
//
//  A minimal Wayland compositor for tests: a compositor, a seat with a
//  pointer, and pointer gestures, sending the pinches a test asks for.
//  Linux only.
//

#ifndef CACAO_WAYLAND_TEST_SERVER_H
#define CACAO_WAYLAND_TEST_SERVER_H

typedef struct CacaoTestServer CacaoTestServer;

/// Starts serving on a socket in `XDG_RUNTIME_DIR`, on its own thread.
CacaoTestServer *cacao_test_server_start(const char *socket_name);

/// Sends a pinch over the client's last surface: its beginning, an update
/// for each rotation (in degrees clockwise), and its end.
void cacao_test_server_pinch(CacaoTestServer *server, const double *rotations, int count);

void cacao_test_server_stop(CacaoTestServer *server);

/// Connects a client, returning its `struct wl_display *`.
void *cacao_test_client_connect(const char *socket_name);

/// Makes a surface on the client's display, returning its `struct wl_surface *`.
void *cacao_test_client_create_surface(void *display);

/// Waits for the server to answer everything sent so far.
void cacao_test_client_roundtrip(void *display);

void cacao_test_client_disconnect(void *display);

#endif
