//
//  appmenu.c
//  Cacao
//
//  The KDE appmenu protocol: ties a window's surface to the D-Bus service
//  and object path of its com.canonical.dbusmenu menu, so the compositor
//  can tell the menu bar whose menu to show.
//

#include "CacaoWayland.h"

#if defined(__linux__)

#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "protocol/appmenu-client-protocol.h"
#include "protocol/appmenu-protocol.c"

/// The newest version used: 2 adds the manager's release.
#define APPMENU_VERSION 2

struct CacaoWaylandAppMenuManager {
    struct wl_display *display;
    struct wl_event_queue *queue;
    struct wl_registry *registry;
    struct org_kde_kwin_appmenu_manager *manager;
    uint32_t version;
};

struct CacaoWaylandAppMenu {
    CacaoWaylandAppMenuManager *manager;
    struct org_kde_kwin_appmenu *appmenu;
};

// MARK: Registry

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    CacaoWaylandAppMenuManager *manager = data;
    if (strcmp(interface, org_kde_kwin_appmenu_manager_interface.name) == 0 && !manager->manager) {
        manager->version = version < APPMENU_VERSION ? version : APPMENU_VERSION;
        manager->manager = wl_registry_bind(registry, name, &org_kde_kwin_appmenu_manager_interface, manager->version);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) { }

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// MARK: API

CacaoWaylandAppMenuManager *cacao_wayland_appmenu_manager_create(void *display) {
    if (!display) {
        return NULL;
    }
    CacaoWaylandAppMenuManager *manager = calloc(1, sizeof(CacaoWaylandAppMenuManager));
    manager->display = display;
    // The protocol has no events, but the registry's go to a queue of our
    // own, which SDL doesn't dispatch.
    manager->queue = wl_display_create_queue(manager->display);
    struct wl_display *wrapper = wl_proxy_create_wrapper(manager->display);
    wl_proxy_set_queue((struct wl_proxy *)wrapper, manager->queue);
    manager->registry = wl_display_get_registry(wrapper);
    wl_proxy_wrapper_destroy(wrapper);
    wl_registry_add_listener(manager->registry, &registry_listener, manager);
    wl_display_roundtrip_queue(manager->display, manager->queue);
    if (!manager->manager) {
        cacao_wayland_appmenu_manager_destroy(manager);
        return NULL;
    }
    return manager;
}

CacaoWaylandAppMenu *cacao_wayland_appmenu_create(CacaoWaylandAppMenuManager *manager, void *surface,
                                                  const char *service, const char *path) {
    if (!manager || !surface || !service || !path) {
        return NULL;
    }
    CacaoWaylandAppMenu *menu = calloc(1, sizeof(CacaoWaylandAppMenu));
    menu->manager = manager;
    menu->appmenu = org_kde_kwin_appmenu_manager_create(manager->manager, surface);
    org_kde_kwin_appmenu_set_address(menu->appmenu, service, path);
    wl_display_flush(manager->display);
    return menu;
}

void cacao_wayland_appmenu_set_address(CacaoWaylandAppMenu *menu, const char *service, const char *path) {
    if (!menu || !service || !path) {
        return;
    }
    org_kde_kwin_appmenu_set_address(menu->appmenu, service, path);
    wl_display_flush(menu->manager->display);
}

void cacao_wayland_appmenu_destroy(CacaoWaylandAppMenu *menu) {
    if (!menu) {
        return;
    }
    org_kde_kwin_appmenu_release(menu->appmenu);
    wl_display_flush(menu->manager->display);
    free(menu);
}

void cacao_wayland_appmenu_manager_destroy(CacaoWaylandAppMenuManager *manager) {
    if (!manager) {
        return;
    }
    if (manager->manager) {
        if (manager->version >= ORG_KDE_KWIN_APPMENU_MANAGER_RELEASE_SINCE_VERSION) {
            org_kde_kwin_appmenu_manager_release(manager->manager);
        } else {
            org_kde_kwin_appmenu_manager_destroy(manager->manager);
        }
    }
    if (manager->registry) wl_registry_destroy(manager->registry);
    wl_display_flush(manager->display);
    wl_event_queue_destroy(manager->queue);
    free(manager);
}

#else

CacaoWaylandAppMenuManager *cacao_wayland_appmenu_manager_create(void *display) {
    return NULL;
}

CacaoWaylandAppMenu *cacao_wayland_appmenu_create(CacaoWaylandAppMenuManager *manager, void *surface,
                                                  const char *service, const char *path) {
    return NULL;
}

void cacao_wayland_appmenu_set_address(CacaoWaylandAppMenu *menu, const char *service, const char *path) { }

void cacao_wayland_appmenu_destroy(CacaoWaylandAppMenu *menu) { }

void cacao_wayland_appmenu_manager_destroy(CacaoWaylandAppMenuManager *manager) { }

#endif
