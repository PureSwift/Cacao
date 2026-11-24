//
//  popup.c
//  Cacao
//
//  Popups (menus, pickers, popovers) as surfaces of their own, with the
//  xdg_popup role, so they can extend past the edges of the window or layer
//  surface they belong to. SDL makes xdg_popups too, but only for windows
//  it gave a role itself, and without a grab; these work for a layer
//  surface's popups as well, and take the seat's grab, so the compositor
//  dismisses them when the user clicks elsewhere.
//

#include "CacaoWayland.h"

#if defined(__linux__)

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>

// xdg-shell's interfaces under names of our own, so they can't clash with
// a copy elsewhere in the process, such as SDL's.
#define xdg_wm_base_interface cacao_xdg_wm_base_interface
#define xdg_positioner_interface cacao_xdg_positioner_interface
#define xdg_surface_interface cacao_xdg_surface_interface
#define xdg_toplevel_interface cacao_xdg_toplevel_interface
#define xdg_popup_interface cacao_xdg_popup_interface
#include "protocol/xdg-shell-client-protocol.h"
#include "protocol/xdg-shell-protocol.c"

/// The newest version used: 3 adds repositioning, and reactive positioners.
#define XDG_WM_BASE_VERSION 3

/// The newest seat version used, for its pointer, keyboard and touch
/// events.
#define SEAT_VERSION 5

struct CacaoWaylandPopups {
    struct wl_display *display;
    struct wl_event_queue *queue;
    struct wl_registry *registry;
    struct xdg_wm_base *wm_base;
    uint32_t wm_base_version;
    struct wl_seat *seat;
    struct wl_pointer *pointer;
    struct wl_keyboard *keyboard;
    struct wl_touch *touch;
    /// The serial of the last button, key or touch the seat sent: what a
    /// grab has to name.
    uint32_t input_serial;
};

struct CacaoWaylandPopup {
    CacaoWaylandPopups *popups;
    struct wl_surface *surface;
    struct xdg_surface *xdg_surface;
    struct xdg_popup *xdg_popup;
    CacaoPopupConfigureCallback configure;
    CacaoPopupDoneCallback done;
    void *context;
    /// The last position and size the compositor gave, applied at the
    /// configure event that follows them.
    int32_t x, y, width, height;
    uint32_t reposition_token;
    bool configured;
    bool is_done;
};

// MARK: Seat

static void pointer_enter(void *data, struct wl_pointer *pointer, uint32_t serial, struct wl_surface *surface, wl_fixed_t x, wl_fixed_t y) { }

static void pointer_leave(void *data, struct wl_pointer *pointer, uint32_t serial, struct wl_surface *surface) { }

static void pointer_motion(void *data, struct wl_pointer *pointer, uint32_t time, wl_fixed_t x, wl_fixed_t y) { }

static void pointer_button(void *data, struct wl_pointer *pointer, uint32_t serial, uint32_t time, uint32_t button, uint32_t state) {
    CacaoWaylandPopups *popups = data;
    if (state == WL_POINTER_BUTTON_STATE_PRESSED) {
        popups->input_serial = serial;
    }
}

static void pointer_axis(void *data, struct wl_pointer *pointer, uint32_t time, uint32_t axis, wl_fixed_t value) { }

static void pointer_frame(void *data, struct wl_pointer *pointer) { }

static void pointer_axis_source(void *data, struct wl_pointer *pointer, uint32_t source) { }

static void pointer_axis_stop(void *data, struct wl_pointer *pointer, uint32_t time, uint32_t axis) { }

static void pointer_axis_discrete(void *data, struct wl_pointer *pointer, uint32_t axis, int32_t discrete) { }

static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
    .frame = pointer_frame,
    .axis_source = pointer_axis_source,
    .axis_stop = pointer_axis_stop,
    .axis_discrete = pointer_axis_discrete,
};

static void keyboard_keymap(void *data, struct wl_keyboard *keyboard, uint32_t format, int32_t fd, uint32_t size) {
    close(fd);
}

static void keyboard_enter(void *data, struct wl_keyboard *keyboard, uint32_t serial, struct wl_surface *surface, struct wl_array *keys) { }

static void keyboard_leave(void *data, struct wl_keyboard *keyboard, uint32_t serial, struct wl_surface *surface) { }

static void keyboard_key(void *data, struct wl_keyboard *keyboard, uint32_t serial, uint32_t time, uint32_t key, uint32_t state) {
    CacaoWaylandPopups *popups = data;
    if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
        popups->input_serial = serial;
    }
}

static void keyboard_modifiers(void *data, struct wl_keyboard *keyboard, uint32_t serial, uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) { }

static void keyboard_repeat_info(void *data, struct wl_keyboard *keyboard, int32_t rate, int32_t delay) { }

static const struct wl_keyboard_listener keyboard_listener = {
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};

static void touch_down(void *data, struct wl_touch *touch, uint32_t serial, uint32_t time, struct wl_surface *surface, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    CacaoWaylandPopups *popups = data;
    popups->input_serial = serial;
}

static void touch_up(void *data, struct wl_touch *touch, uint32_t serial, uint32_t time, int32_t id) { }

static void touch_motion(void *data, struct wl_touch *touch, uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y) { }

static void touch_frame(void *data, struct wl_touch *touch) { }

static void touch_cancel(void *data, struct wl_touch *touch) { }

static const struct wl_touch_listener touch_listener = {
    .down = touch_down,
    .up = touch_up,
    .motion = touch_motion,
    .frame = touch_frame,
    .cancel = touch_cancel,
};

static void seat_capabilities(void *data, struct wl_seat *seat, uint32_t capabilities) {
    CacaoWaylandPopups *popups = data;
    bool has_pointer = capabilities & WL_SEAT_CAPABILITY_POINTER;
    bool has_keyboard = capabilities & WL_SEAT_CAPABILITY_KEYBOARD;
    bool has_touch = capabilities & WL_SEAT_CAPABILITY_TOUCH;
    if (has_pointer && !popups->pointer) {
        popups->pointer = wl_seat_get_pointer(seat);
        wl_pointer_add_listener(popups->pointer, &pointer_listener, popups);
    } else if (!has_pointer && popups->pointer) {
        wl_pointer_destroy(popups->pointer);
        popups->pointer = NULL;
    }
    if (has_keyboard && !popups->keyboard) {
        popups->keyboard = wl_seat_get_keyboard(seat);
        wl_keyboard_add_listener(popups->keyboard, &keyboard_listener, popups);
    } else if (!has_keyboard && popups->keyboard) {
        wl_keyboard_destroy(popups->keyboard);
        popups->keyboard = NULL;
    }
    if (has_touch && !popups->touch) {
        popups->touch = wl_seat_get_touch(seat);
        wl_touch_add_listener(popups->touch, &touch_listener, popups);
    } else if (!has_touch && popups->touch) {
        wl_touch_destroy(popups->touch);
        popups->touch = NULL;
    }
}

static void seat_name(void *data, struct wl_seat *seat, const char *name) { }

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

// MARK: Shell

static void wm_base_ping(void *data, struct xdg_wm_base *wm_base, uint32_t serial) {
    xdg_wm_base_pong(wm_base, serial);
}

static const struct xdg_wm_base_listener wm_base_listener = {
    .ping = wm_base_ping,
};

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    CacaoWaylandPopups *popups = data;
    if (strcmp(interface, xdg_wm_base_interface.name) == 0 && !popups->wm_base) {
        popups->wm_base_version = version < XDG_WM_BASE_VERSION ? version : XDG_WM_BASE_VERSION;
        popups->wm_base = wl_registry_bind(registry, name, &xdg_wm_base_interface, popups->wm_base_version);
        xdg_wm_base_add_listener(popups->wm_base, &wm_base_listener, popups);
    } else if (strcmp(interface, wl_seat_interface.name) == 0 && !popups->seat) {
        popups->seat = wl_registry_bind(registry, name, &wl_seat_interface, version < SEAT_VERSION ? version : SEAT_VERSION);
        wl_seat_add_listener(popups->seat, &seat_listener, popups);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) { }

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// MARK: Popup

static void xdg_surface_configure(void *data, struct xdg_surface *xdg_surface, uint32_t serial) {
    CacaoWaylandPopup *popup = data;
    // Acknowledged first, so the commit that follows the new size applies it.
    xdg_surface_ack_configure(xdg_surface, serial);
    popup->configured = true;
    if (popup->configure) {
        popup->configure(popup->context, popup->x, popup->y, popup->width, popup->height);
    }
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure,
};

static void xdg_popup_configure(void *data, struct xdg_popup *xdg_popup, int32_t x, int32_t y, int32_t width, int32_t height) {
    CacaoWaylandPopup *popup = data;
    popup->x = x;
    popup->y = y;
    popup->width = width;
    popup->height = height;
}

static void xdg_popup_done(void *data, struct xdg_popup *xdg_popup) {
    CacaoWaylandPopup *popup = data;
    if (popup->is_done) {
        return;
    }
    popup->is_done = true;
    if (popup->done) {
        popup->done(popup->context);
    }
}

static void xdg_popup_repositioned(void *data, struct xdg_popup *xdg_popup, uint32_t token) { }

static const struct xdg_popup_listener xdg_popup_listener = {
    .configure = xdg_popup_configure,
    .popup_done = xdg_popup_done,
    .repositioned = xdg_popup_repositioned,
};

static struct xdg_positioner *make_positioner(CacaoWaylandPopups *popups, const CacaoPopupPositioner *options) {
    struct xdg_positioner *positioner = xdg_wm_base_create_positioner(popups->wm_base);
    xdg_positioner_set_size(positioner, options->width > 0 ? options->width : 1, options->height > 0 ? options->height : 1);
    xdg_positioner_set_anchor_rect(positioner, options->anchor_x, options->anchor_y,
                                   options->anchor_width > 0 ? options->anchor_width : 1,
                                   options->anchor_height > 0 ? options->anchor_height : 1);
    xdg_positioner_set_anchor(positioner, options->anchor);
    xdg_positioner_set_gravity(positioner, options->gravity);
    xdg_positioner_set_constraint_adjustment(positioner, options->constraint_adjustment);
    xdg_positioner_set_offset(positioner, options->offset_x, options->offset_y);
    if (popups->wm_base_version >= XDG_POSITIONER_SET_REACTIVE_SINCE_VERSION) {
        // Placed again when the parent moves or changes size.
        xdg_positioner_set_reactive(positioner);
    }
    return positioner;
}

// MARK: API

CacaoWaylandPopups *cacao_wayland_popups_create(void *display) {
    if (!display) {
        return NULL;
    }
    CacaoWaylandPopups *popups = calloc(1, sizeof(CacaoWaylandPopups));
    popups->display = display;
    popups->queue = wl_display_create_queue(popups->display);
    // The registry, and everything made from it, sends its events to our
    // queue, which SDL doesn't dispatch.
    struct wl_display *wrapper = wl_proxy_create_wrapper(popups->display);
    wl_proxy_set_queue((struct wl_proxy *)wrapper, popups->queue);
    popups->registry = wl_display_get_registry(wrapper);
    wl_proxy_wrapper_destroy(wrapper);
    wl_registry_add_listener(popups->registry, &registry_listener, popups);
    // The globals, then the seat's capabilities.
    wl_display_roundtrip_queue(popups->display, popups->queue);
    wl_display_roundtrip_queue(popups->display, popups->queue);
    if (!popups->wm_base) {
        cacao_wayland_popups_destroy(popups);
        return NULL;
    }
    return popups;
}

uint32_t cacao_wayland_popups_input_serial(CacaoWaylandPopups *popups) {
    return popups ? popups->input_serial : 0;
}

void cacao_wayland_popups_dispatch(CacaoWaylandPopups *popups) {
    if (popups) {
        wl_display_dispatch_queue_pending(popups->display, popups->queue);
    }
}

CacaoWaylandPopup *cacao_wayland_popup_create(
    CacaoWaylandPopups *popups,
    void *surface,
    const CacaoPopupParent *parent,
    const CacaoPopupPositioner *positioner,
    const CacaoPopupGeometry *geometry,
    bool grab,
    CacaoPopupConfigureCallback configure,
    CacaoPopupDoneCallback done,
    void *context) {
    if (!popups || !surface || !parent || !positioner) {
        return NULL;
    }
    if (!parent->xdg_surface && !parent->layer_surface && !parent->popup) {
        return NULL;
    }
    // Make sure what SDL sent for the parent is on the server: our requests
    // name its objects.
    wl_display_flush(popups->display);
    CacaoWaylandPopup *popup = calloc(1, sizeof(CacaoWaylandPopup));
    popup->popups = popups;
    popup->surface = surface;
    popup->configure = configure;
    popup->done = done;
    popup->context = context;

    // Made from our own shell, so its events come to our queue.
    popup->xdg_surface = xdg_wm_base_get_xdg_surface(popups->wm_base, surface);
    xdg_surface_add_listener(popup->xdg_surface, &xdg_surface_listener, popup);

    struct xdg_positioner *xdg_positioner = make_positioner(popups, positioner);
    struct xdg_surface *parent_surface = parent->popup ? parent->popup->xdg_surface : parent->xdg_surface;
    // A layer surface's popup has no xdg parent: the layer shell gives it one.
    popup->xdg_popup = xdg_surface_get_popup(popup->xdg_surface, parent->layer_surface ? NULL : parent_surface, xdg_positioner);
    xdg_positioner_destroy(xdg_positioner);
    xdg_popup_add_listener(popup->xdg_popup, &xdg_popup_listener, popup);
    // Once it has its role.
    if (geometry && geometry->width > 0 && geometry->height > 0) {
        xdg_surface_set_window_geometry(popup->xdg_surface, geometry->x, geometry->y, geometry->width, geometry->height);
    }
    if (parent->layer_surface) {
        cacao_wayland_layer_surface_attach_popup(parent->layer_surface, popup->xdg_popup);
    }
    if (grab && popups->seat && popups->input_serial != 0) {
        xdg_popup_grab(popup->xdg_popup, popups->seat, popups->input_serial);
    }
    // A commit with no buffer asks for the first configure.
    wl_surface_commit(surface);
    for (int attempt = 0; attempt < 8 && !popup->configured && !popup->is_done; attempt++) {
        if (wl_display_roundtrip_queue(popups->display, popups->queue) < 0) {
            break;
        }
    }
    if (!popup->configured) {
        cacao_wayland_popup_destroy(popup);
        return NULL;
    }
    return popup;
}

bool cacao_wayland_popup_reposition(CacaoWaylandPopup *popup, const CacaoPopupPositioner *positioner, const CacaoPopupGeometry *geometry) {
    if (!popup || !positioner || popup->is_done
        || popup->popups->wm_base_version < XDG_POPUP_REPOSITION_SINCE_VERSION) {
        return false;
    }
    if (geometry && geometry->width > 0 && geometry->height > 0) {
        xdg_surface_set_window_geometry(popup->xdg_surface, geometry->x, geometry->y, geometry->width, geometry->height);
    }
    struct xdg_positioner *xdg_positioner = make_positioner(popup->popups, positioner);
    xdg_popup_reposition(popup->xdg_popup, xdg_positioner, ++popup->reposition_token);
    xdg_positioner_destroy(xdg_positioner);
    wl_display_flush(popup->popups->display);
    return true;
}

void cacao_wayland_popup_set_geometry(CacaoWaylandPopup *popup, const CacaoPopupGeometry *geometry) {
    if (!popup || !geometry || geometry->width <= 0 || geometry->height <= 0) {
        return;
    }
    xdg_surface_set_window_geometry(popup->xdg_surface, geometry->x, geometry->y, geometry->width, geometry->height);
}

void cacao_wayland_popup_destroy(CacaoWaylandPopup *popup) {
    if (!popup) {
        return;
    }
    if (popup->xdg_popup) xdg_popup_destroy(popup->xdg_popup);
    if (popup->xdg_surface) xdg_surface_destroy(popup->xdg_surface);
    wl_display_flush(popup->popups->display);
    free(popup);
}

void cacao_wayland_popups_destroy(CacaoWaylandPopups *popups) {
    if (!popups) {
        return;
    }
    if (popups->pointer) wl_pointer_destroy(popups->pointer);
    if (popups->keyboard) wl_keyboard_destroy(popups->keyboard);
    if (popups->touch) wl_touch_destroy(popups->touch);
    if (popups->seat) wl_seat_destroy(popups->seat);
    if (popups->wm_base) xdg_wm_base_destroy(popups->wm_base);
    if (popups->registry) wl_registry_destroy(popups->registry);
    wl_display_flush(popups->display);
    wl_event_queue_destroy(popups->queue);
    free(popups);
}

#else

CacaoWaylandPopups *cacao_wayland_popups_create(void *display) {
    return NULL;
}

uint32_t cacao_wayland_popups_input_serial(CacaoWaylandPopups *popups) {
    return 0;
}

void cacao_wayland_popups_dispatch(CacaoWaylandPopups *popups) { }

CacaoWaylandPopup *cacao_wayland_popup_create(
    CacaoWaylandPopups *popups, void *surface, const CacaoPopupParent *parent,
    const CacaoPopupPositioner *positioner, const CacaoPopupGeometry *geometry, bool grab,
    CacaoPopupConfigureCallback configure, CacaoPopupDoneCallback done, void *context) {
    return NULL;
}

bool cacao_wayland_popup_reposition(CacaoWaylandPopup *popup, const CacaoPopupPositioner *positioner, const CacaoPopupGeometry *geometry) {
    return false;
}

void cacao_wayland_popup_set_geometry(CacaoWaylandPopup *popup, const CacaoPopupGeometry *geometry) { }

void cacao_wayland_popup_destroy(CacaoWaylandPopup *popup) { }

void cacao_wayland_popups_destroy(CacaoWaylandPopups *popups) { }

#endif
