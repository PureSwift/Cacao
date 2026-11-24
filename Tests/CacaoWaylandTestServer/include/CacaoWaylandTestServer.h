//
//  CacaoWaylandTestServer.h
//  Cacao
//
//  A minimal Wayland compositor for tests: a compositor, a seat with a
//  pointer, pointer gestures, sending the pinches a test asks for, and a
//  layer shell, recording what its surface asks for and sending the
//  configures a test asks for. Linux only.
//

#ifndef CACAO_WAYLAND_TEST_SERVER_H
#define CACAO_WAYLAND_TEST_SERVER_H

#include <stdint.h>

typedef struct CacaoTestServer CacaoTestServer;

/// What the client's layer surface asked for, and what the server sent it.
typedef struct CacaoTestLayerState {
    int exists;
    uint32_t layer;
    uint32_t anchors;
    int32_t exclusive_zone;
    int32_t margin_top;
    int32_t margin_right;
    int32_t margin_bottom;
    int32_t margin_left;
    uint32_t width;
    uint32_t height;
    uint32_t keyboard_interactivity;
    char name_space[64];
    /// Whether the first configure was sent.
    int configured;
    /// The serial of the last configure sent, and of the last one the
    /// client acknowledged.
    uint32_t configured_serial;
    uint32_t acked_serial;
} CacaoTestLayerState;

/// Starts serving on a socket in `XDG_RUNTIME_DIR`, on its own thread.
CacaoTestServer *cacao_test_server_start(const char *socket_name);

/// Starts serving, with or without a layer shell global.
CacaoTestServer *cacao_test_server_start_with_layer_shell(const char *socket_name, int with_layer_shell);

/// What the client's last layer surface asked for.
CacaoTestLayerState cacao_test_server_layer_state(CacaoTestServer *server);

/// Sends the layer surface a new size.
void cacao_test_server_configure_layer(CacaoTestServer *server, uint32_t width, uint32_t height);

/// Tells the layer surface it was closed.
void cacao_test_server_close_layer(CacaoTestServer *server);

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
