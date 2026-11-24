//
//  server.c
//  Cacao
//

#include "CacaoWaylandTestServer.h"

#if defined(__linux__)

#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-server.h>
#include <wayland-client.h>
#include "protocol/pointer-gestures-unstable-v1-server-protocol.h"
#include "protocol/wlr-layer-shell-unstable-v1-server-protocol.h"
#include "protocol/appmenu-server-protocol.h"
// xdg-shell's interfaces, under the names CacaoWayland gives them.
#define xdg_wm_base_interface cacao_xdg_wm_base_interface
#define xdg_positioner_interface cacao_xdg_positioner_interface
#define xdg_surface_interface cacao_xdg_surface_interface
#define xdg_toplevel_interface cacao_xdg_toplevel_interface
#define xdg_popup_interface cacao_xdg_popup_interface
#include "protocol/xdg-shell-server-protocol.h"

// The interfaces, from CacaoWayland's protocol code.
extern const struct wl_interface zwp_pointer_gestures_v1_interface;
extern const struct wl_interface zwp_pointer_gesture_pinch_v1_interface;
extern const struct wl_interface zwlr_layer_shell_v1_interface;
extern const struct wl_interface zwlr_layer_surface_v1_interface;
extern const struct wl_interface org_kde_kwin_appmenu_manager_interface;
extern const struct wl_interface org_kde_kwin_appmenu_interface;
extern const struct wl_interface xdg_wm_base_interface;
extern const struct wl_interface xdg_positioner_interface;
extern const struct wl_interface xdg_surface_interface;
extern const struct wl_interface xdg_popup_interface;

/// The screen the test compositor pretends to have.
#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 800

struct CacaoTestServer {
    struct wl_display *display;
    pthread_t thread;
    pthread_mutex_t lock;
    volatile int running;
    struct wl_resource *surface;
    struct wl_resource *pinch;
    double rotations[64];
    int pending;
    struct wl_resource *layer_surface;
    CacaoTestLayerState layer;
    uint32_t pending_width;
    uint32_t pending_height;
    int pending_configure;
    int pending_close;
    struct wl_resource *appmenu;
    CacaoTestAppMenuState appmenu_state;
    struct wl_resource *pointer;
    int pending_press;
    struct wl_resource *popup_surface;
    struct wl_resource *xdg_surface;
    struct wl_resource *xdg_popup;
    CacaoTestPopupState popup;
    int pending_popup_done;
    uint32_t last_press_serial;
};

/// What an xdg_positioner was told.
struct positioner {
    CacaoTestPositioner values;
};

static void destroy_resource(struct wl_client *client, struct wl_resource *resource) {
    wl_resource_destroy(resource);
}

// MARK: Compositor

static void send_layer_configure(CacaoTestServer *server, uint32_t width, uint32_t height);

static void send_popup_configure(CacaoTestServer *server);

static void surface_commit(struct wl_client *client, struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    // The first commit of a popup asks for its place.
    int popup_initial = resource == server->popup_surface && server->xdg_popup && !server->popup.configured;
    pthread_mutex_unlock(&server->lock);
    if (popup_initial) {
        send_popup_configure(server);
        return;
    }
    pthread_mutex_lock(&server->lock);
    // The first commit of a layer surface asks for its size: what it asked
    // for, or the screen's along an axis it left to the compositor.
    int initial = server->layer_surface && !server->layer.configured;
    uint32_t width = server->layer.width ? server->layer.width : SCREEN_WIDTH;
    uint32_t height = server->layer.height ? server->layer.height : SCREEN_HEIGHT;
    if (initial) {
        server->layer.configured = 1;
    }
    pthread_mutex_unlock(&server->lock);
    if (initial) {
        send_layer_configure(server, width, height);
    }
}

static const struct wl_surface_interface surface_implementation = {
    .destroy = destroy_resource,
    .commit = surface_commit,
};

static void compositor_create_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *surface = wl_resource_create(client, &wl_surface_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(surface, &surface_implementation, server, NULL);
    server->surface = surface;
}

static const struct wl_compositor_interface compositor_implementation = {
    .create_surface = compositor_create_surface,
};

static void bind_compositor(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &wl_compositor_interface, version, id);
    wl_resource_set_implementation(resource, &compositor_implementation, data, NULL);
}

// MARK: Seat

static const struct wl_pointer_interface pointer_implementation = {
    .release = destroy_resource,
};

static void pointer_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    if (server && server->pointer == resource) {
        server->pointer = NULL;
    }
}

static void seat_get_pointer(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *pointer = wl_resource_create(client, &wl_pointer_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(pointer, &pointer_implementation, server, pointer_destroyed);
    server->pointer = pointer;
}

static const struct wl_seat_interface seat_implementation = {
    .get_pointer = seat_get_pointer,
    .release = destroy_resource,
};

static void bind_seat(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &wl_seat_interface, version, id);
    wl_resource_set_implementation(resource, &seat_implementation, data, NULL);
    wl_seat_send_capabilities(resource, WL_SEAT_CAPABILITY_POINTER);
    if (version >= WL_SEAT_NAME_SINCE_VERSION) {
        wl_seat_send_name(resource, "test");
    }
}

// MARK: Pointer gestures

static void pinch_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    if (server->pinch == resource) {
        server->pinch = NULL;
    }
}

static const struct zwp_pointer_gesture_pinch_v1_interface pinch_implementation = {
    .destroy = destroy_resource,
};

static void gestures_get_pinch(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *pointer) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *pinch = wl_resource_create(client, &zwp_pointer_gesture_pinch_v1_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(pinch, &pinch_implementation, server, pinch_destroyed);
    server->pinch = pinch;
}

static const struct zwp_pointer_gestures_v1_interface gestures_implementation = {
    .get_pinch_gesture = gestures_get_pinch,
    .release = destroy_resource,
};

static void bind_gestures(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &zwp_pointer_gestures_v1_interface, version, id);
    wl_resource_set_implementation(resource, &gestures_implementation, data, NULL);
}

// MARK: Layer shell

static void layer_surface_set_size(struct wl_client *client, struct wl_resource *resource, uint32_t width, uint32_t height) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.width = width;
    server->layer.height = height;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_set_anchor(struct wl_client *client, struct wl_resource *resource, uint32_t anchor) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.anchors = anchor;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_set_exclusive_zone(struct wl_client *client, struct wl_resource *resource, int32_t zone) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.exclusive_zone = zone;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_set_margin(struct wl_client *client, struct wl_resource *resource,
                                     int32_t top, int32_t right, int32_t bottom, int32_t left) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.margin_top = top;
    server->layer.margin_right = right;
    server->layer.margin_bottom = bottom;
    server->layer.margin_left = left;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_set_keyboard_interactivity(struct wl_client *client, struct wl_resource *resource, uint32_t keyboard) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.keyboard_interactivity = keyboard;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_ack_configure(struct wl_client *client, struct wl_resource *resource, uint32_t serial) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.acked_serial = serial;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_set_layer(struct wl_client *client, struct wl_resource *resource, uint32_t layer) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->layer.layer = layer;
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (server->layer_surface == resource) {
        server->layer_surface = NULL;
        server->layer.exists = 0;
    }
    pthread_mutex_unlock(&server->lock);
}

static void layer_surface_get_popup(struct wl_client *client, struct wl_resource *resource, struct wl_resource *popup) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (popup == server->xdg_popup) {
        server->popup.has_layer_parent = 1;
    }
    pthread_mutex_unlock(&server->lock);
}

static const struct zwlr_layer_surface_v1_interface layer_surface_implementation = {
    .get_popup = layer_surface_get_popup,
    .set_size = layer_surface_set_size,
    .set_anchor = layer_surface_set_anchor,
    .set_exclusive_zone = layer_surface_set_exclusive_zone,
    .set_margin = layer_surface_set_margin,
    .set_keyboard_interactivity = layer_surface_set_keyboard_interactivity,
    .ack_configure = layer_surface_ack_configure,
    .destroy = destroy_resource,
    .set_layer = layer_surface_set_layer,
};

static void layer_shell_get_layer_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id,
                                          struct wl_resource *surface, struct wl_resource *output,
                                          uint32_t layer, const char *name_space) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *layer_surface = wl_resource_create(client, &zwlr_layer_surface_v1_interface,
                                                           wl_resource_get_version(resource), id);
    wl_resource_set_implementation(layer_surface, &layer_surface_implementation, server, layer_surface_destroyed);
    pthread_mutex_lock(&server->lock);
    server->layer_surface = layer_surface;
    memset(&server->layer, 0, sizeof(server->layer));
    server->layer.exists = 1;
    server->layer.layer = layer;
    strncpy(server->layer.name_space, name_space, sizeof(server->layer.name_space) - 1);
    pthread_mutex_unlock(&server->lock);
}

static const struct zwlr_layer_shell_v1_interface layer_shell_implementation = {
    .get_layer_surface = layer_shell_get_layer_surface,
    .destroy = destroy_resource,
};

static void bind_layer_shell(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &zwlr_layer_shell_v1_interface, version, id);
    wl_resource_set_implementation(resource, &layer_shell_implementation, data, NULL);
}

// MARK: App menu

static void appmenu_set_address(struct wl_client *client, struct wl_resource *resource,
                                const char *service_name, const char *object_path) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (server->appmenu == resource) {
        server->appmenu_state.addresses_set += 1;
        strncpy(server->appmenu_state.service_name, service_name, sizeof(server->appmenu_state.service_name) - 1);
        strncpy(server->appmenu_state.object_path, object_path, sizeof(server->appmenu_state.object_path) - 1);
    }
    pthread_mutex_unlock(&server->lock);
}

static void appmenu_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (server->appmenu == resource) {
        server->appmenu = NULL;
        server->appmenu_state.exists = 0;
    }
    pthread_mutex_unlock(&server->lock);
}

static const struct org_kde_kwin_appmenu_interface appmenu_implementation = {
    .set_address = appmenu_set_address,
    .release = destroy_resource,
};

static void appmenu_manager_create(struct wl_client *client, struct wl_resource *resource, uint32_t id,
                                   struct wl_resource *surface) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *appmenu = wl_resource_create(client, &org_kde_kwin_appmenu_interface,
                                                     wl_resource_get_version(resource), id);
    wl_resource_set_implementation(appmenu, &appmenu_implementation, server, appmenu_destroyed);
    pthread_mutex_lock(&server->lock);
    server->appmenu = appmenu;
    memset(&server->appmenu_state, 0, sizeof(server->appmenu_state));
    server->appmenu_state.exists = 1;
    server->appmenu_state.is_for_surface = surface == server->surface;
    pthread_mutex_unlock(&server->lock);
}

static const struct org_kde_kwin_appmenu_manager_interface appmenu_manager_implementation = {
    .create = appmenu_manager_create,
    .release = destroy_resource,
};

static void bind_appmenu_manager(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &org_kde_kwin_appmenu_manager_interface, version, id);
    wl_resource_set_implementation(resource, &appmenu_manager_implementation, data, NULL);
}

// MARK: xdg shell

static void positioner_destroyed(struct wl_resource *resource) {
    free(wl_resource_get_user_data(resource));
}

static void positioner_set_size(struct wl_client *client, struct wl_resource *resource, int32_t width, int32_t height) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.width = width;
    positioner->values.height = height;
}

static void positioner_set_anchor_rect(struct wl_client *client, struct wl_resource *resource, int32_t x, int32_t y, int32_t width, int32_t height) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.anchor_x = x;
    positioner->values.anchor_y = y;
    positioner->values.anchor_width = width;
    positioner->values.anchor_height = height;
}

static void positioner_set_anchor(struct wl_client *client, struct wl_resource *resource, uint32_t anchor) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.anchor = anchor;
}

static void positioner_set_gravity(struct wl_client *client, struct wl_resource *resource, uint32_t gravity) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.gravity = gravity;
}

static void positioner_set_constraint_adjustment(struct wl_client *client, struct wl_resource *resource, uint32_t adjustment) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.constraint_adjustment = adjustment;
}

static void positioner_set_offset(struct wl_client *client, struct wl_resource *resource, int32_t x, int32_t y) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.offset_x = x;
    positioner->values.offset_y = y;
}

static void positioner_set_reactive(struct wl_client *client, struct wl_resource *resource) {
    struct positioner *positioner = wl_resource_get_user_data(resource);
    positioner->values.reactive = 1;
}

static void positioner_set_parent_size(struct wl_client *client, struct wl_resource *resource, int32_t width, int32_t height) { }

static void positioner_set_parent_configure(struct wl_client *client, struct wl_resource *resource, uint32_t serial) { }

static const struct xdg_positioner_interface positioner_implementation = {
    .destroy = destroy_resource,
    .set_size = positioner_set_size,
    .set_anchor_rect = positioner_set_anchor_rect,
    .set_anchor = positioner_set_anchor,
    .set_gravity = positioner_set_gravity,
    .set_constraint_adjustment = positioner_set_constraint_adjustment,
    .set_offset = positioner_set_offset,
    .set_reactive = positioner_set_reactive,
    .set_parent_size = positioner_set_parent_size,
    .set_parent_configure = positioner_set_parent_configure,
};

static void popup_grab(struct wl_client *client, struct wl_resource *resource, struct wl_resource *seat, uint32_t serial) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->popup.grabbed = 1;
    server->popup.grab_serial = serial;
    pthread_mutex_unlock(&server->lock);
}

static void popup_reposition(struct wl_client *client, struct wl_resource *resource, struct wl_resource *positioner, uint32_t token) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct positioner *values = wl_resource_get_user_data(positioner);
    pthread_mutex_lock(&server->lock);
    server->popup.positioner = values->values;
    server->popup.repositions += 1;
    pthread_mutex_unlock(&server->lock);
    xdg_popup_send_repositioned(resource, token);
    send_popup_configure(server);
}

static void popup_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (server->xdg_popup == resource) {
        server->xdg_popup = NULL;
        server->popup.exists = 0;
    }
    pthread_mutex_unlock(&server->lock);
}

static const struct xdg_popup_interface popup_implementation = {
    .destroy = destroy_resource,
    .grab = popup_grab,
    .reposition = popup_reposition,
};

static void xdg_surface_get_toplevel(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    wl_resource_post_error(resource, XDG_WM_BASE_ERROR_ROLE, "the test compositor makes popups only");
}

static void xdg_surface_get_popup(struct wl_client *client, struct wl_resource *resource, uint32_t id,
                                  struct wl_resource *parent, struct wl_resource *positioner) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct positioner *values = wl_resource_get_user_data(positioner);
    struct wl_resource *popup = wl_resource_create(client, &xdg_popup_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(popup, &popup_implementation, server, popup_destroyed);
    pthread_mutex_lock(&server->lock);
    server->xdg_popup = popup;
    memset(&server->popup, 0, sizeof(server->popup));
    server->popup.exists = 1;
    server->popup.has_xdg_parent = parent != NULL;
    server->popup.positioner = values->values;
    pthread_mutex_unlock(&server->lock);
}

static void xdg_surface_set_window_geometry(struct wl_client *client, struct wl_resource *resource, int32_t x, int32_t y, int32_t width, int32_t height) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    // As wlroots does: an xdg_surface needs its role first.
    if (!server->xdg_popup) {
        wl_resource_post_error(resource, XDG_SURFACE_ERROR_NOT_CONSTRUCTED, "xdg_surface must have a role");
        return;
    }
    pthread_mutex_lock(&server->lock);
    server->popup.geometry_x = x;
    server->popup.geometry_y = y;
    server->popup.geometry_width = width;
    server->popup.geometry_height = height;
    pthread_mutex_unlock(&server->lock);
}

static void xdg_surface_ack_configure(struct wl_client *client, struct wl_resource *resource, uint32_t serial) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    server->popup.acked_serial = serial;
    pthread_mutex_unlock(&server->lock);
}

static void xdg_surface_destroyed(struct wl_resource *resource) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    pthread_mutex_lock(&server->lock);
    if (server->xdg_surface == resource) {
        server->xdg_surface = NULL;
        server->popup_surface = NULL;
    }
    pthread_mutex_unlock(&server->lock);
}

static const struct xdg_surface_interface xdg_surface_implementation = {
    .destroy = destroy_resource,
    .get_toplevel = xdg_surface_get_toplevel,
    .get_popup = xdg_surface_get_popup,
    .set_window_geometry = xdg_surface_set_window_geometry,
    .ack_configure = xdg_surface_ack_configure,
};

static void wm_base_create_positioner(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_resource *positioner = wl_resource_create(client, &xdg_positioner_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(positioner, &positioner_implementation, calloc(1, sizeof(struct positioner)), positioner_destroyed);
}

static void wm_base_get_xdg_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface) {
    CacaoTestServer *server = wl_resource_get_user_data(resource);
    struct wl_resource *xdg_surface = wl_resource_create(client, &xdg_surface_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(xdg_surface, &xdg_surface_implementation, server, xdg_surface_destroyed);
    pthread_mutex_lock(&server->lock);
    server->xdg_surface = xdg_surface;
    server->popup_surface = surface;
    pthread_mutex_unlock(&server->lock);
}

static void wm_base_pong(struct wl_client *client, struct wl_resource *resource, uint32_t serial) { }

static const struct xdg_wm_base_interface wm_base_implementation = {
    .destroy = destroy_resource,
    .create_positioner = wm_base_create_positioner,
    .get_xdg_surface = wm_base_get_xdg_surface,
    .pong = wm_base_pong,
};

static void bind_wm_base(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_resource *resource = wl_resource_create(client, &xdg_wm_base_interface, version, id);
    wl_resource_set_implementation(resource, &wm_base_implementation, data, NULL);
}

/// Places the popup where its positioner says, with no screen edge in the
/// way: on the server's thread.
static void send_popup_configure(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    struct wl_resource *popup = server->xdg_popup;
    struct wl_resource *xdg_surface = server->xdg_surface;
    CacaoTestPositioner p = server->popup.positioner;
    pthread_mutex_unlock(&server->lock);
    if (!popup || !xdg_surface) return;
    int32_t x = p.anchor_x, y = p.anchor_y;
    switch (p.anchor) {
    case XDG_POSITIONER_ANCHOR_BOTTOM_LEFT: y += p.anchor_height; break;
    case XDG_POSITIONER_ANCHOR_TOP_RIGHT: x += p.anchor_width; break;
    case XDG_POSITIONER_ANCHOR_BOTTOM_RIGHT: x += p.anchor_width; y += p.anchor_height; break;
    default: break;
    }
    x += p.offset_x;
    y += p.offset_y;
    uint32_t serial = wl_display_next_serial(server->display);
    pthread_mutex_lock(&server->lock);
    server->popup.configured = 1;
    server->popup.configured_serial = serial;
    pthread_mutex_unlock(&server->lock);
    xdg_popup_send_configure(popup, x, y, p.width, p.height);
    xdg_surface_send_configure(xdg_surface, serial);
}

/// On the server's thread.
static void send_layer_configure(CacaoTestServer *server, uint32_t width, uint32_t height) {
    if (!server->layer_surface) return;
    uint32_t serial = wl_display_next_serial(server->display);
    pthread_mutex_lock(&server->lock);
    server->layer.configured_serial = serial;
    pthread_mutex_unlock(&server->lock);
    zwlr_layer_surface_v1_send_configure(server->layer_surface, serial, width, height);
}

// MARK: Running

/// Sends the pinch a test asked for, if any.
static void send_pending(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    int count = server->pending;
    server->pending = 0;
    pthread_mutex_unlock(&server->lock);
    if (count == 0 || !server->pinch || !server->surface) {
        return;
    }
    uint32_t serial = wl_display_next_serial(server->display);
    zwp_pointer_gesture_pinch_v1_send_begin(server->pinch, serial, 0, server->surface, 2);
    for (int index = 0; index < count && index < 64; index++) {
        zwp_pointer_gesture_pinch_v1_send_update(server->pinch, 10 * (index + 1), 0, 0,
                                                 wl_fixed_from_double(1 + 0.1 * (index + 1)),
                                                 wl_fixed_from_double(server->rotations[index]));
    }
    zwp_pointer_gesture_pinch_v1_send_end(server->pinch, wl_display_next_serial(server->display), 1000, 0);
}

/// Sends the configure or close a test asked for, if any.
static void send_pending_layer(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    int configure = server->pending_configure;
    int close = server->pending_close;
    uint32_t width = server->pending_width;
    uint32_t height = server->pending_height;
    server->pending_configure = 0;
    server->pending_close = 0;
    pthread_mutex_unlock(&server->lock);
    if (configure) {
        send_layer_configure(server, width, height);
    }
    if (close && server->layer_surface) {
        zwlr_layer_surface_v1_send_closed(server->layer_surface);
    }
}

/// Sends the button press or popup dismissal a test asked for, if any.
static void send_pending_popup(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    int press = server->pending_press;
    int done = server->pending_popup_done;
    server->pending_press = 0;
    server->pending_popup_done = 0;
    pthread_mutex_unlock(&server->lock);
    if (press && server->pointer) {
        uint32_t serial = wl_display_next_serial(server->display);
        pthread_mutex_lock(&server->lock);
        server->popup.press_serial = serial;
        server->last_press_serial = serial;
        pthread_mutex_unlock(&server->lock);
        wl_pointer_send_button(server->pointer, serial, 100, 0x110, WL_POINTER_BUTTON_STATE_PRESSED);
    }
    if (done && server->xdg_popup) {
        xdg_popup_send_popup_done(server->xdg_popup);
    }
}

static void *run(void *data) {
    CacaoTestServer *server = data;
    struct wl_event_loop *loop = wl_display_get_event_loop(server->display);
    while (server->running) {
        wl_event_loop_dispatch(loop, 10);
        send_pending(server);
        send_pending_layer(server);
        send_pending_popup(server);
        wl_display_flush_clients(server->display);
    }
    return NULL;
}

CacaoTestServer *cacao_test_server_start(const char *socket_name) {
    return cacao_test_server_start_with_layer_shell(socket_name, 0);
}

CacaoTestServer *cacao_test_server_start_with_layer_shell(const char *socket_name, int with_layer_shell) {
    return cacao_test_server_start_with_features(socket_name, with_layer_shell ? CacaoTestServerFeatureLayerShell : 0);
}

CacaoTestServer *cacao_test_server_start_with_features(const char *socket_name, uint32_t features) {
    CacaoTestServer *server = calloc(1, sizeof(CacaoTestServer));
    server->display = wl_display_create();
    if (wl_display_add_socket(server->display, socket_name) != 0) {
        wl_display_destroy(server->display);
        free(server);
        return NULL;
    }
    wl_global_create(server->display, &wl_compositor_interface, 4, server, bind_compositor);
    wl_global_create(server->display, &wl_seat_interface, 5, server, bind_seat);
    wl_global_create(server->display, &zwp_pointer_gestures_v1_interface, 1, server, bind_gestures);
    if (features & CacaoTestServerFeatureLayerShell) {
        wl_global_create(server->display, &zwlr_layer_shell_v1_interface, 4, server, bind_layer_shell);
    }
    if (features & CacaoTestServerFeatureAppMenu) {
        wl_global_create(server->display, &org_kde_kwin_appmenu_manager_interface, 2, server, bind_appmenu_manager);
    }
    if (features & CacaoTestServerFeatureXdgShell) {
        wl_global_create(server->display, &xdg_wm_base_interface, 3, server, bind_wm_base);
    }
    pthread_mutex_init(&server->lock, NULL);
    server->running = 1;
    pthread_create(&server->thread, NULL, run, server);
    return server;
}

void cacao_test_server_pinch(CacaoTestServer *server, const double *rotations, int count) {
    pthread_mutex_lock(&server->lock);
    count = count < 64 ? count : 64;
    memcpy(server->rotations, rotations, sizeof(double) * count);
    server->pending = count;
    pthread_mutex_unlock(&server->lock);
}

CacaoTestAppMenuState cacao_test_server_appmenu_state(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    CacaoTestAppMenuState state = server->appmenu_state;
    pthread_mutex_unlock(&server->lock);
    return state;
}

CacaoTestLayerState cacao_test_server_layer_state(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    CacaoTestLayerState state = server->layer;
    pthread_mutex_unlock(&server->lock);
    return state;
}

void cacao_test_server_configure_layer(CacaoTestServer *server, uint32_t width, uint32_t height) {
    pthread_mutex_lock(&server->lock);
    server->pending_width = width;
    server->pending_height = height;
    server->pending_configure = 1;
    pthread_mutex_unlock(&server->lock);
}

void cacao_test_server_close_layer(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    server->pending_close = 1;
    pthread_mutex_unlock(&server->lock);
}

CacaoTestPopupState cacao_test_server_popup_state(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    CacaoTestPopupState state = server->popup;
    pthread_mutex_unlock(&server->lock);
    return state;
}

void cacao_test_server_press_button(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    server->pending_press = 1;
    pthread_mutex_unlock(&server->lock);
}

uint32_t cacao_test_server_last_press_serial(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    uint32_t serial = server->last_press_serial;
    pthread_mutex_unlock(&server->lock);
    return serial;
}

void cacao_test_server_dismiss_popup(CacaoTestServer *server) {
    pthread_mutex_lock(&server->lock);
    server->pending_popup_done = 1;
    pthread_mutex_unlock(&server->lock);
}

void cacao_test_server_stop(CacaoTestServer *server) {
    if (!server) return;
    server->running = 0;
    pthread_join(server->thread, NULL);
    wl_display_destroy_clients(server->display);
    wl_display_destroy(server->display);
    pthread_mutex_destroy(&server->lock);
    free(server);
}

// MARK: Client

struct client_globals {
    struct wl_compositor *compositor;
};

static void client_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    struct client_globals *globals = data;
    if (strcmp(interface, wl_compositor_interface.name) == 0) {
        globals->compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    }
}

static void client_global_remove(void *data, struct wl_registry *registry, uint32_t name) { }

static const struct wl_registry_listener client_registry_listener = {
    .global = client_global,
    .global_remove = client_global_remove,
};

void *cacao_test_client_connect(const char *socket_name) {
    return wl_display_connect(socket_name);
}

void *cacao_test_client_create_surface(void *display) {
    struct client_globals globals = { 0 };
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &client_registry_listener, &globals);
    wl_display_roundtrip(display);
    wl_registry_destroy(registry);
    if (!globals.compositor) return NULL;
    return wl_compositor_create_surface(globals.compositor);
}

void cacao_test_client_roundtrip(void *display) {
    wl_display_roundtrip(display);
}

void cacao_test_client_disconnect(void *display) {
    wl_display_disconnect(display);
}

#else

CacaoTestServer *cacao_test_server_start(const char *socket_name) { return 0; }
CacaoTestServer *cacao_test_server_start_with_layer_shell(const char *socket_name, int with_layer_shell) { return 0; }
CacaoTestServer *cacao_test_server_start_with_features(const char *socket_name, uint32_t features) { return 0; }
CacaoTestAppMenuState cacao_test_server_appmenu_state(CacaoTestServer *server) { CacaoTestAppMenuState state = { 0 }; return state; }
CacaoTestLayerState cacao_test_server_layer_state(CacaoTestServer *server) { CacaoTestLayerState state = { 0 }; return state; }
void cacao_test_server_configure_layer(CacaoTestServer *server, uint32_t width, uint32_t height) { }
void cacao_test_server_close_layer(CacaoTestServer *server) { }
CacaoTestPopupState cacao_test_server_popup_state(CacaoTestServer *server) { CacaoTestPopupState state = { 0 }; return state; }
void cacao_test_server_press_button(CacaoTestServer *server) { }
uint32_t cacao_test_server_last_press_serial(CacaoTestServer *server) { return 0; }
void cacao_test_server_dismiss_popup(CacaoTestServer *server) { }
void cacao_test_server_pinch(CacaoTestServer *server, const double *rotations, int count) { }
void cacao_test_server_stop(CacaoTestServer *server) { }
void *cacao_test_client_connect(const char *socket_name) { return 0; }
void *cacao_test_client_create_surface(void *display) { return 0; }
void cacao_test_client_roundtrip(void *display) { }
void cacao_test_client_disconnect(void *display) { }

#endif
