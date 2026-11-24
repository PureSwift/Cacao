//
//  CacaoWaylandTestServer.h
//  Cacao
//
//  A minimal Wayland compositor for tests: a compositor, a seat with a
//  pointer, pointer gestures, sending the pinches a test asks for, and a
//  layer shell, recording what its surface asks for and sending the
//  configures a test asks for, the KDE appmenu protocol, recording the
//  address a surface's menu was given, and xdg-shell popups, recording where
//  they were asked to go and placing them there. Linux only.
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

/// The menu address the client gave its surface with the appmenu protocol.
typedef struct CacaoTestAppMenuState {
    /// Whether the client has an appmenu object.
    int exists;
    /// How many times the address was set.
    int addresses_set;
    char service_name[128];
    char object_path[128];
    /// Whether the object was made for the client's last surface.
    int is_for_surface;
} CacaoTestAppMenuState;

/// What an xdg_positioner was told.
typedef struct CacaoTestPositioner {
    int32_t anchor_x;
    int32_t anchor_y;
    int32_t anchor_width;
    int32_t anchor_height;
    int32_t width;
    int32_t height;
    uint32_t anchor;
    uint32_t gravity;
    uint32_t constraint_adjustment;
    int32_t offset_x;
    int32_t offset_y;
    int reactive;
} CacaoTestPositioner;

/// What the client's last xdg popup asked for, and what the server sent it.
typedef struct CacaoTestPopupState {
    int exists;
    /// Whether it was made with an xdg_surface for its parent.
    int has_xdg_parent;
    /// Whether a layer surface took it as its popup.
    int has_layer_parent;
    /// Where it was asked to go: when it was made, or last repositioned.
    CacaoTestPositioner positioner;
    int repositions;
    int32_t geometry_x;
    int32_t geometry_y;
    int32_t geometry_width;
    int32_t geometry_height;
    int grabbed;
    uint32_t grab_serial;
    /// The serial of the last button press sent while it existed.
    uint32_t press_serial;
    int configured;
    uint32_t configured_serial;
    uint32_t acked_serial;
} CacaoTestPopupState;

/// Globals a test server offers besides a compositor, a seat and pointer
/// gestures, combined.
typedef enum CacaoTestServerFeature {
    CacaoTestServerFeatureLayerShell = 1,
    CacaoTestServerFeatureAppMenu = 2,
    CacaoTestServerFeatureXdgShell = 4
} CacaoTestServerFeature;

/// Starts serving on a socket in `XDG_RUNTIME_DIR`, on its own thread.
CacaoTestServer *cacao_test_server_start(const char *socket_name);

/// Starts serving, with or without a layer shell global.
CacaoTestServer *cacao_test_server_start_with_layer_shell(const char *socket_name, int with_layer_shell);

/// Starts serving, with the globals of the `CacaoTestServerFeature` values
/// given.
CacaoTestServer *cacao_test_server_start_with_features(const char *socket_name, uint32_t features);

/// The address the client's last appmenu object was given.
CacaoTestAppMenuState cacao_test_server_appmenu_state(CacaoTestServer *server);

/// What the client's last layer surface asked for.
CacaoTestLayerState cacao_test_server_layer_state(CacaoTestServer *server);

/// Sends the layer surface a new size.
void cacao_test_server_configure_layer(CacaoTestServer *server, uint32_t width, uint32_t height);

/// Tells the layer surface it was closed.
void cacao_test_server_close_layer(CacaoTestServer *server);

/// What the client's last popup asked for.
CacaoTestPopupState cacao_test_server_popup_state(CacaoTestServer *server);

/// Sends a press of the pointer's left button, whose serial a popup's grab
/// names.
void cacao_test_server_press_button(CacaoTestServer *server);

/// The serial of the last button press sent.
uint32_t cacao_test_server_last_press_serial(CacaoTestServer *server);

/// Tells the popup it was dismissed, as after a click elsewhere.
void cacao_test_server_dismiss_popup(CacaoTestServer *server);

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
