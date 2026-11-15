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

// The interfaces, from CacaoWayland's protocol code.
extern const struct wl_interface zwp_pointer_gestures_v1_interface;
extern const struct wl_interface zwp_pointer_gesture_pinch_v1_interface;

struct CacaoTestServer {
    struct wl_display *display;
    pthread_t thread;
    pthread_mutex_t lock;
    volatile int running;
    struct wl_resource *surface;
    struct wl_resource *pinch;
    double rotations[64];
    int pending;
};

static void destroy_resource(struct wl_client *client, struct wl_resource *resource) {
    wl_resource_destroy(resource);
}

// MARK: Compositor

static const struct wl_surface_interface surface_implementation = {
    .destroy = destroy_resource,
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

static void seat_get_pointer(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_resource *pointer = wl_resource_create(client, &wl_pointer_interface, wl_resource_get_version(resource), id);
    wl_resource_set_implementation(pointer, &pointer_implementation, NULL, NULL);
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

static void *run(void *data) {
    CacaoTestServer *server = data;
    struct wl_event_loop *loop = wl_display_get_event_loop(server->display);
    while (server->running) {
        wl_event_loop_dispatch(loop, 10);
        send_pending(server);
        wl_display_flush_clients(server->display);
    }
    return NULL;
}

CacaoTestServer *cacao_test_server_start(const char *socket_name) {
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
void cacao_test_server_pinch(CacaoTestServer *server, const double *rotations, int count) { }
void cacao_test_server_stop(CacaoTestServer *server) { }
void *cacao_test_client_connect(const char *socket_name) { return 0; }
void *cacao_test_client_create_surface(void *display) { return 0; }
void cacao_test_client_roundtrip(void *display) { }
void cacao_test_client_disconnect(void *display) { }

#endif
