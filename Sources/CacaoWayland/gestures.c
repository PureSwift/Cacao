//
//  gestures.c
//  Cacao
//

#include "CacaoWayland.h"

#if defined(__linux__)

#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "protocol/pointer-gestures-unstable-v1-client-protocol.h"
#include "protocol/pointer-gestures-unstable-v1-protocol.c"

struct CacaoWaylandGestures {
    struct wl_display *display;
    struct wl_event_queue *queue;
    struct wl_registry *registry;
    struct wl_seat *seat;
    struct wl_pointer *pointer;
    struct zwp_pointer_gestures_v1 *manager;
    struct zwp_pointer_gesture_pinch_v1 *pinch;
    struct wl_surface *surface;
    CacaoPinchCallback callback;
    void *context;
};

// MARK: Pinch

static void pinch_begin(void *data, struct zwp_pointer_gesture_pinch_v1 *pinch, uint32_t serial, uint32_t time,
                        struct wl_surface *surface, uint32_t fingers) {
    CacaoWaylandGestures *gestures = data;
    gestures->surface = surface;
    gestures->callback(gestures->context, CacaoPinchPhaseBegan, surface, 0, 1);
}

static void pinch_update(void *data, struct zwp_pointer_gesture_pinch_v1 *pinch, uint32_t time,
                         wl_fixed_t dx, wl_fixed_t dy, wl_fixed_t scale, wl_fixed_t rotation) {
    CacaoWaylandGestures *gestures = data;
    gestures->callback(gestures->context, CacaoPinchPhaseChanged, gestures->surface,
                       wl_fixed_to_double(rotation), wl_fixed_to_double(scale));
}

static void pinch_end(void *data, struct zwp_pointer_gesture_pinch_v1 *pinch, uint32_t serial, uint32_t time,
                      int32_t cancelled) {
    CacaoWaylandGestures *gestures = data;
    gestures->callback(gestures->context, cancelled ? CacaoPinchPhaseCancelled : CacaoPinchPhaseEnded,
                       gestures->surface, 0, 1);
    gestures->surface = NULL;
}

static const struct zwp_pointer_gesture_pinch_v1_listener pinch_listener = {
    .begin = pinch_begin,
    .update = pinch_update,
    .end = pinch_end,
};

/// Asks for pinches once there's both a pointer and the gestures global.
static void start_pinch(CacaoWaylandGestures *gestures) {
    if (gestures->pinch || !gestures->pointer || !gestures->manager) {
        return;
    }
    gestures->pinch = zwp_pointer_gestures_v1_get_pinch_gesture(gestures->manager, gestures->pointer);
    zwp_pointer_gesture_pinch_v1_add_listener(gestures->pinch, &pinch_listener, gestures);
}

// MARK: Seat

static void seat_capabilities(void *data, struct wl_seat *seat, uint32_t capabilities) {
    CacaoWaylandGestures *gestures = data;
    if ((capabilities & WL_SEAT_CAPABILITY_POINTER) && !gestures->pointer) {
        // A pointer object of our own: the seat sends every pointer object
        // its events, so SDL's own keeps working.
        gestures->pointer = wl_seat_get_pointer(seat);
        start_pinch(gestures);
    }
}

static void seat_name(void *data, struct wl_seat *seat, const char *name) { }

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

// MARK: Registry

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    CacaoWaylandGestures *gestures = data;
    if (strcmp(interface, wl_seat_interface.name) == 0 && !gestures->seat) {
        gestures->seat = wl_registry_bind(registry, name, &wl_seat_interface, version < 5 ? version : 5);
        wl_seat_add_listener(gestures->seat, &seat_listener, gestures);
    } else if (strcmp(interface, zwp_pointer_gestures_v1_interface.name) == 0 && !gestures->manager) {
        gestures->manager = wl_registry_bind(registry, name, &zwp_pointer_gestures_v1_interface, 1);
        start_pinch(gestures);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) { }

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// MARK: API

CacaoWaylandGestures *cacao_wayland_gestures_create(void *display, CacaoPinchCallback callback, void *context) {
    if (!display || !callback) {
        return NULL;
    }
    CacaoWaylandGestures *gestures = calloc(1, sizeof(CacaoWaylandGestures));
    gestures->display = display;
    gestures->callback = callback;
    gestures->context = context;
    gestures->queue = wl_display_create_queue(gestures->display);
    // The registry, and everything made from it, sends its events to our
    // queue, which SDL doesn't dispatch.
    struct wl_display *wrapper = wl_proxy_create_wrapper(gestures->display);
    wl_proxy_set_queue((struct wl_proxy *)wrapper, gestures->queue);
    gestures->registry = wl_display_get_registry(wrapper);
    wl_proxy_wrapper_destroy(wrapper);
    wl_registry_add_listener(gestures->registry, &registry_listener, gestures);
    // Globals, then the seat's capabilities.
    wl_display_roundtrip_queue(gestures->display, gestures->queue);
    wl_display_roundtrip_queue(gestures->display, gestures->queue);
    if (!gestures->pinch) {
        cacao_wayland_gestures_destroy(gestures);
        return NULL;
    }
    return gestures;
}

void cacao_wayland_gestures_dispatch(CacaoWaylandGestures *gestures) {
    if (gestures) {
        wl_display_dispatch_queue_pending(gestures->display, gestures->queue);
    }
}

void cacao_wayland_gestures_destroy(CacaoWaylandGestures *gestures) {
    if (!gestures) {
        return;
    }
    if (gestures->pinch) zwp_pointer_gesture_pinch_v1_destroy(gestures->pinch);
    if (gestures->manager) zwp_pointer_gestures_v1_destroy(gestures->manager);
    if (gestures->pointer) wl_pointer_destroy(gestures->pointer);
    if (gestures->seat) wl_seat_destroy(gestures->seat);
    if (gestures->registry) wl_registry_destroy(gestures->registry);
    wl_display_flush(gestures->display);
    wl_event_queue_destroy(gestures->queue);
    free(gestures);
}

#else

CacaoWaylandGestures *cacao_wayland_gestures_create(void *display, CacaoPinchCallback callback, void *context) {
    return NULL;
}

void cacao_wayland_gestures_dispatch(CacaoWaylandGestures *gestures) { }

void cacao_wayland_gestures_destroy(CacaoWaylandGestures *gestures) { }

#endif
