//
//  CacaoWayland.h
//  Cacao
//
//  What Cacao asks of a Wayland compositor that SDL doesn't: touchpad pinch
//  gestures with their rotation, layer-shell surfaces, for panels and docks
//  anchored to the edges of a screen, popups as surfaces of their own, and
//  the KDE appmenu protocol, which ties a window to its menu on D-Bus. Linux
//  only; elsewhere these do nothing.
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

/// Makes a layer surface the parent of a popup (a `struct xdg_popup *` made
/// with no parent), before the popup's surface is first committed.
void cacao_wayland_layer_surface_attach_popup(CacaoWaylandLayerSurface *surface, void *xdg_popup);

// MARK: - Popups

/// Where a popup goes, as an `xdg_positioner` says it: a rectangle in the
/// parent's window geometry to anchor to, the popup's size, the anchor
/// point on that rectangle and the direction the popup extends from it
/// (`xdg_positioner`'s `anchor` and `gravity` values), and what the
/// compositor may do when it wouldn't fit on the screen (its
/// `constraint_adjustment` flags: slide, flip, resize). In surface
/// coordinates (points).
typedef struct CacaoPopupPositioner {
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
} CacaoPopupPositioner;

/// The part of a popup's surface that is the popup, inside the transparent
/// margins its shadow draws in: what it's positioned by.
typedef struct CacaoPopupGeometry {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} CacaoPopupGeometry;

typedef struct CacaoWaylandPopups CacaoWaylandPopups;

typedef struct CacaoWaylandPopup CacaoWaylandPopup;

/// What a popup belongs to: one of a window's `struct xdg_surface *`, a
/// layer surface, or another popup.
typedef struct CacaoPopupParent {
    void *xdg_surface;
    CacaoWaylandLayerSurface *layer_surface;
    CacaoWaylandPopup *popup;
} CacaoPopupParent;

/// The compositor placed the popup: its position relative to its parent's
/// window geometry, and its size, in surface coordinates.
typedef void (*CacaoPopupConfigureCallback)(void *context, int32_t x, int32_t y, int32_t width, int32_t height);

/// The compositor dismissed the popup, as when the user clicked outside it.
typedef void (*CacaoPopupDoneCallback)(void *context);

/// Binds `xdg_wm_base` and a seat on a Wayland display (a
/// `struct wl_display *`), with an event queue of their own. The seat's
/// input gives the serial a popup's grab needs. Returns NULL if the
/// compositor offers no xdg shell.
CacaoWaylandPopups *cacao_wayland_popups_create(void *display);

/// The serial of the last button press, key press or touch the seat sent;
/// 0 if none yet.
uint32_t cacao_wayland_popups_input_serial(CacaoWaylandPopups *popups);

/// Calls back for the configure and done events the display has read, for
/// every popup. Each configure is acknowledged before its callback, so the
/// next commit applies it.
void cacao_wayland_popups_dispatch(CacaoWaylandPopups *popups);

/// Gives a surface with no role yet (a `struct wl_surface *`) the popup
/// role, and waits for the compositor's first placement, which it calls
/// back with before returning. With `grab`, the popup takes the seat's
/// grab, for the last input it sent: it gets keyboard focus, and the
/// compositor dismisses it when the user clicks a surface of another
/// client. The surface must have no buffer attached until then. Returns
/// NULL if the compositor didn't place it.
CacaoWaylandPopup *cacao_wayland_popup_create(
    CacaoWaylandPopups *popups,
    void *surface,
    const CacaoPopupParent *parent,
    const CacaoPopupPositioner *positioner,
    const CacaoPopupGeometry *geometry,
    bool grab,
    CacaoPopupConfigureCallback configure,
    CacaoPopupDoneCallback done,
    void *context);

/// Places the popup again, as for a new size; the compositor answers with a
/// configure. Returns false if the compositor can't, as before
/// `xdg_wm_base` version 3: then make the popup again.
bool cacao_wayland_popup_reposition(CacaoWaylandPopup *popup, const CacaoPopupPositioner *positioner, const CacaoPopupGeometry *geometry);

/// Sets the part of the surface that is the popup, for the next commit.
void cacao_wayland_popup_set_geometry(CacaoWaylandPopup *popup, const CacaoPopupGeometry *geometry);

/// Removes the popup role. Destroy a popup's own popups first. The surface
/// itself belongs to its creator.
void cacao_wayland_popup_destroy(CacaoWaylandPopup *popup);

/// Destroy the popups first.
void cacao_wayland_popups_destroy(CacaoWaylandPopups *popups);

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
