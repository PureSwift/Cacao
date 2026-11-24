//
//  CacaoWayland.h
//  Cacao
//
//  What Cacao asks of a Wayland compositor that SDL doesn't: touchpad pinch
//  gestures with their rotation, layer-shell surfaces, for panels and docks
//  anchored to the edges of a screen, and the KDE appmenu protocol, which
//  ties a window to its menu on D-Bus. Linux only; elsewhere these do
//  nothing.
//

#ifndef CACAO_WAYLAND_H
#define CACAO_WAYLAND_H

#include <stdbool.h>
#include <stdint.h>

// MARK: - Pinch gestures

typedef enum CacaoPinchPhase {
    CacaoPinchPhaseBegan,
    CacaoPinchPhaseChanged,
    CacaoPinchPhaseEnded,
    CacaoPinchPhaseCancelled
} CacaoPinchPhase;

/// Called for each pinch event: the surface the pinch is over, the rotation
/// since the last event in degrees clockwise, and the scale since it began.
typedef void (*CacaoPinchCallback)(void *context, CacaoPinchPhase phase, void *surface, double rotation, double scale);

typedef struct CacaoWaylandGestures CacaoWaylandGestures;

/// Listens for pinch gestures on a Wayland display (a `struct wl_display *`),
/// on its own event queue. Returns NULL if the compositor offers no pointer
/// gestures or the seat has no pointer.
CacaoWaylandGestures *cacao_wayland_gestures_create(void *display, CacaoPinchCallback callback, void *context);

/// Calls back for the gesture events the display has read.
void cacao_wayland_gestures_dispatch(CacaoWaylandGestures *gestures);

void cacao_wayland_gestures_destroy(CacaoWaylandGestures *gestures);

// MARK: - Layer shell

/// The layers of `wlr-layer-shell`, from the bottom of the stack up.
/// Windows are drawn between the bottom and top layers.
typedef enum CacaoLayer {
    CacaoLayerBackground = 0,
    CacaoLayerBottom = 1,
    CacaoLayerTop = 2,
    CacaoLayerOverlay = 3
} CacaoLayer;

/// The edges of the screen a layer surface is anchored to, combined.
typedef enum CacaoLayerAnchor {
    CacaoLayerAnchorTop = 1,
    CacaoLayerAnchorBottom = 2,
    CacaoLayerAnchorLeft = 4,
    CacaoLayerAnchorRight = 8
} CacaoLayerAnchor;

/// Whether a layer surface takes keyboard focus.
typedef enum CacaoLayerKeyboardInteractivity {
    /// Never.
    CacaoLayerKeyboardInteractivityNone = 0,
    /// Always, while it's on the top or overlay layer.
    CacaoLayerKeyboardInteractivityExclusive = 1,
    /// When clicked, like a window. Compositors with an older protocol give
    /// it none.
    CacaoLayerKeyboardInteractivityOnDemand = 2
} CacaoLayerKeyboardInteractivity;

/// Where a layer surface goes and how it behaves. Sizes and distances are
/// in surface coordinates (points).
typedef struct CacaoLayerSurfaceOptions {
    CacaoLayer layer;
    /// `CacaoLayerAnchor` values, combined.
    uint32_t anchors;
    /// How much of the anchored edge to keep other surfaces and windows
    /// out of; 0 for none, or -1 to cover what others keep.
    int32_t exclusive_zone;
    int32_t margin_top;
    int32_t margin_right;
    int32_t margin_bottom;
    int32_t margin_left;
    /// The size to ask for; 0 along an axis anchored at both ends asks for
    /// all of it.
    uint32_t width;
    uint32_t height;
    CacaoLayerKeyboardInteractivity keyboard_interactivity;
    /// What the surface is for, such as "dock", for the compositor's rules.
    const char *name_space;
} CacaoLayerSurfaceOptions;

/// The compositor gave the surface a size, in surface coordinates. A width
/// or height of 0 leaves it to the client.
typedef void (*CacaoLayerConfigureCallback)(void *context, uint32_t width, uint32_t height);

/// The compositor took the surface away, as when its screen went away.
typedef void (*CacaoLayerClosedCallback)(void *context);

typedef struct CacaoWaylandLayerShell CacaoWaylandLayerShell;

typedef struct CacaoWaylandLayerSurface CacaoWaylandLayerSurface;

/// Binds the layer shell on a Wayland display (a `struct wl_display *`),
/// with an event queue of its own. Returns NULL if the compositor offers
/// no layer shell.
CacaoWaylandLayerShell *cacao_wayland_layer_shell_create(void *display);

/// Gives a surface with no role yet (a `struct wl_surface *`) the layer
/// role, on the screen the compositor chooses, and waits for the compositor's
/// first size, which it calls back with before returning. The surface must
/// have no buffer attached until then. Returns NULL if the compositor
/// closed the surface instead.
CacaoWaylandLayerSurface *cacao_wayland_layer_surface_create(
    CacaoWaylandLayerShell *shell,
    void *surface,
    const CacaoLayerSurfaceOptions *options,
    CacaoLayerConfigureCallback configure,
    CacaoLayerClosedCallback closed,
    void *context);

/// Calls back for the configure and close events the display has read, for
/// every surface of the shell. Each configure is acknowledged before its
/// callback, so the next commit applies it.
void cacao_wayland_layer_shell_dispatch(CacaoWaylandLayerShell *shell);

/// Removes the layer role. The surface itself belongs to its creator.
void cacao_wayland_layer_surface_destroy(CacaoWaylandLayerSurface *surface);

/// Destroy the shell's surfaces first.
void cacao_wayland_layer_shell_destroy(CacaoWaylandLayerShell *shell);

// MARK: - App menus

typedef struct CacaoWaylandAppMenuManager CacaoWaylandAppMenuManager;

typedef struct CacaoWaylandAppMenu CacaoWaylandAppMenu;

/// Binds the KDE appmenu manager (`org_kde_kwin_appmenu_manager`) on a
/// Wayland display (a `struct wl_display *`). Returns NULL if the
/// compositor doesn't offer it: then nothing shows windows' menus from it.
CacaoWaylandAppMenuManager *cacao_wayland_appmenu_manager_create(void *display);

/// Ties a window's surface (a `struct wl_surface *`) to the
/// `com.canonical.dbusmenu` object at a D-Bus service and object path,
/// which should be on the bus already.
CacaoWaylandAppMenu *cacao_wayland_appmenu_create(CacaoWaylandAppMenuManager *manager, void *surface,
                                                  const char *service, const char *path);

/// Moves the surface's menu to another service or path.
void cacao_wayland_appmenu_set_address(CacaoWaylandAppMenu *menu, const char *service, const char *path);

/// Unties the surface from its menu, before the surface is destroyed.
void cacao_wayland_appmenu_destroy(CacaoWaylandAppMenu *menu);

/// Destroy the manager's menus first.
void cacao_wayland_appmenu_manager_destroy(CacaoWaylandAppMenuManager *manager);

#endif
