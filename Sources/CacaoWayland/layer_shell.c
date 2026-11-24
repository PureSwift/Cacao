//
//  layer_shell.c
//  Cacao
//

#include "CacaoWayland.h"

#if defined(__linux__)

#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>

// The protocol's `get_popup` takes an xdg_popup, which Cacao doesn't make:
// an interface of our own name stands in for xdg-shell's, so this library
// needn't carry xdg-shell's code or clash with a copy elsewhere.
__attribute__((visibility("hidden")))
const struct wl_interface cacao_layer_shell_xdg_popup_interface = { "xdg_popup", 1, 0, NULL, 0, NULL };
#define xdg_popup_interface cacao_layer_shell_xdg_popup_interface
#include "protocol/wlr-layer-shell-unstable-v1-client-protocol.h"
#include "protocol/wlr-layer-shell-unstable-v1-protocol.c"
#undef xdg_popup_interface

/// The newest version used: 4 adds on-demand keyboard focus.
#define LAYER_SHELL_VERSION 4

struct CacaoWaylandLayerShell {
    struct wl_display *display;
    struct wl_event_queue *queue;
    struct wl_registry *registry;
    struct zwlr_layer_shell_v1 *shell;
    uint32_t version;
};

struct CacaoWaylandLayerSurface {
    CacaoWaylandLayerShell *shell;
    struct zwlr_layer_surface_v1 *layer_surface;
    CacaoLayerConfigureCallback configure;
    CacaoLayerClosedCallback closed;
    void *context;
    bool configured;
    bool is_closed;
};

// MARK: Layer surface

static void layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *layer_surface,
                                    uint32_t serial, uint32_t width, uint32_t height) {
    CacaoWaylandLayerSurface *surface = data;
    // Acknowledged first, so the commit that follows the new size applies it.
    zwlr_layer_surface_v1_ack_configure(layer_surface, serial);
    surface->configured = true;
    if (surface->configure) {
        surface->configure(surface->context, width, height);
    }
}

static void layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *layer_surface) {
    CacaoWaylandLayerSurface *surface = data;
    surface->is_closed = true;
    if (surface->closed) {
        surface->closed(surface->context);
    }
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

// MARK: Registry

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    CacaoWaylandLayerShell *shell = data;
    if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0 && !shell->shell) {
        shell->version = version < LAYER_SHELL_VERSION ? version : LAYER_SHELL_VERSION;
        shell->shell = wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, shell->version);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) { }

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// MARK: API

CacaoWaylandLayerShell *cacao_wayland_layer_shell_create(void *display) {
    if (!display) {
        return NULL;
    }
    CacaoWaylandLayerShell *shell = calloc(1, sizeof(CacaoWaylandLayerShell));
    shell->display = display;
    shell->queue = wl_display_create_queue(shell->display);
    // The registry, and everything made from it, sends its events to our
    // queue, which SDL doesn't dispatch.
    struct wl_display *wrapper = wl_proxy_create_wrapper(shell->display);
    wl_proxy_set_queue((struct wl_proxy *)wrapper, shell->queue);
    shell->registry = wl_display_get_registry(wrapper);
    wl_proxy_wrapper_destroy(wrapper);
    wl_registry_add_listener(shell->registry, &registry_listener, shell);
    wl_display_roundtrip_queue(shell->display, shell->queue);
    if (!shell->shell) {
        cacao_wayland_layer_shell_destroy(shell);
        return NULL;
    }
    return shell;
}

CacaoWaylandLayerSurface *cacao_wayland_layer_surface_create(
    CacaoWaylandLayerShell *shell,
    void *wl_surface,
    const CacaoLayerSurfaceOptions *options,
    CacaoLayerConfigureCallback configure,
    CacaoLayerClosedCallback closed,
    void *context) {
    if (!shell || !wl_surface || !options) {
        return NULL;
    }
    CacaoWaylandLayerSurface *surface = calloc(1, sizeof(CacaoWaylandLayerSurface));
    surface->shell = shell;
    surface->configure = configure;
    surface->closed = closed;
    surface->context = context;
    surface->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        shell->shell, wl_surface, NULL, (uint32_t)options->layer,
        options->name_space ? options->name_space : "");
    zwlr_layer_surface_v1_add_listener(surface->layer_surface, &layer_surface_listener, surface);
    zwlr_layer_surface_v1_set_size(surface->layer_surface, options->width, options->height);
    zwlr_layer_surface_v1_set_anchor(surface->layer_surface, options->anchors);
    zwlr_layer_surface_v1_set_exclusive_zone(surface->layer_surface, options->exclusive_zone);
    zwlr_layer_surface_v1_set_margin(surface->layer_surface, options->margin_top, options->margin_right,
                                     options->margin_bottom, options->margin_left);
    uint32_t keyboard = (uint32_t)options->keyboard_interactivity;
    if (keyboard == CacaoLayerKeyboardInteractivityOnDemand
        && shell->version < ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_ON_DEMAND_SINCE_VERSION) {
        keyboard = CacaoLayerKeyboardInteractivityNone;
    }
    zwlr_layer_surface_v1_set_keyboard_interactivity(surface->layer_surface, keyboard);
    // A commit with no buffer asks for the first configure.
    wl_surface_commit(wl_surface);
    for (int attempt = 0; attempt < 8 && !surface->configured && !surface->is_closed; attempt++) {
        if (wl_display_roundtrip_queue(shell->display, shell->queue) < 0) {
            break;
        }
    }
    if (!surface->configured || surface->is_closed) {
        cacao_wayland_layer_surface_destroy(surface);
        return NULL;
    }
    return surface;
}

void cacao_wayland_layer_shell_dispatch(CacaoWaylandLayerShell *shell) {
    if (shell) {
        wl_display_dispatch_queue_pending(shell->display, shell->queue);
    }
}

void cacao_wayland_layer_surface_destroy(CacaoWaylandLayerSurface *surface) {
    if (!surface) {
        return;
    }
    if (surface->layer_surface) {
        zwlr_layer_surface_v1_destroy(surface->layer_surface);
    }
    wl_display_flush(surface->shell->display);
    free(surface);
}

void cacao_wayland_layer_shell_destroy(CacaoWaylandLayerShell *shell) {
    if (!shell) {
        return;
    }
    if (shell->shell) {
        if (shell->version >= ZWLR_LAYER_SHELL_V1_DESTROY_SINCE_VERSION) {
            zwlr_layer_shell_v1_destroy(shell->shell);
        } else {
            wl_proxy_destroy((struct wl_proxy *)shell->shell);
        }
    }
    if (shell->registry) wl_registry_destroy(shell->registry);
    wl_display_flush(shell->display);
    wl_event_queue_destroy(shell->queue);
    free(shell);
}

#else

CacaoWaylandLayerShell *cacao_wayland_layer_shell_create(void *display) {
    return NULL;
}

CacaoWaylandLayerSurface *cacao_wayland_layer_surface_create(
    CacaoWaylandLayerShell *shell, void *surface, const CacaoLayerSurfaceOptions *options,
    CacaoLayerConfigureCallback configure, CacaoLayerClosedCallback closed, void *context) {
    return NULL;
}

void cacao_wayland_layer_shell_dispatch(CacaoWaylandLayerShell *shell) { }

void cacao_wayland_layer_surface_destroy(CacaoWaylandLayerSurface *surface) { }

void cacao_wayland_layer_shell_destroy(CacaoWaylandLayerShell *shell) { }

#endif
