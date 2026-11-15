//
//  CacaoWayland.h
//  Cacao
//
//  Touchpad pinch gestures from a Wayland compositor, with their rotation,
//  which SDL doesn't report. Linux only; elsewhere these do nothing.
//

#ifndef CACAO_WAYLAND_H
#define CACAO_WAYLAND_H

#include <stdbool.h>

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

#endif
