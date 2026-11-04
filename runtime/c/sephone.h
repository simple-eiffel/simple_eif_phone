/*
 * sephone.h - the C side of simple_eif_phone (contract with PHONE_NATIVE).
 *
 * Owner: runtime/c/sephone_glue.c (built into every app's .so by eifphone).
 * Prefix: sephone_ (unique across the simple_* fleet; checked 2026-11-03).
 *
 * THREADING: every function here, and every callback the glue registers
 * (onAppCmd, onInputEvent), runs on the android_main thread: native_app_glue
 * processes commands and input inside our poll. The event queue takes no lock.
 * ONE EXCEPTION (Phase 2 RB-3; android_native_app_glue.c:386-392): Android's
 * UI thread writes app->contentRect at any time, under app->mutex. The glue
 * copies contentRect under that mutex into its own snapshot on
 * CONTENT_RECT_CHANGED, and the sephone_metric_content_* getters read only
 * that snapshot.
 *
 * RULE G-1: sephone_wait polls Android ONLY when the event queue is empty.
 * native_app_glue applies one activity command per poll, so the live window
 * pointer always matches the newest DELIVERED window event.
 * DESTROY (RB-8): native_app_glue does not clear app->window on DESTROY
 * (it only sets destroyRequested, g.c:132-135). So once DESTROY has been
 * queued, sephone_window_exists returns 0, matching PHONE_LIFECYCLE, which
 * clears has_window on `destroyed'.
 *
 * SYSTEM BARS: at targetSdk 35+ apps are laid out edge to edge, so
 * contentRect alone reports no bars. The sephone_metric_content_* getters
 * reduce it by the bars read through JNI (getRootWindowInsets); reading
 * content_left refreshes them. The android_main thread stays attached to the VM.
 *
 * WAIT (RB-10): sephone_wait returns 1 only when the queue is non-empty; it
 * loops past wakeups that queued nothing. While Eiffel is between waits,
 * Android's UI thread may be waiting on our poll; keep work between waits
 * short (a frame or so).
 *
 * QUEUE (DR-005, RB-15): 1024 slots. Lifecycle and key events are never
 * dropped. On overflow a touch move is coalesced onto the previous queued
 * move of the same pointer, else the oldest queued move is dropped (counted
 * in sephone_dropped), else the queue grows by 1024 slots. If growing fails,
 * the glue logs a fatal error and finishes the activity (it never silently
 * drops a lifecycle or key event).
 *
 * TIME (RB-1): event times are uptime milliseconds masked to 31 bits,
 * (int)((ns / 1000000) & 0x7FFFFFFF). They are never negative and wrap to 0
 * after 2^31 ms (~24.8 days); compare times by difference.
 *
 * KEYS (RB-5): the glue never queues AKEYCODE_UNKNOWN (0); such key events
 * are passed to the system unconsumed.
 *
 * DELIVERY COUNT (RB-7): sephone_take increments sephone_delivery_count; a
 * timed-out wait takes nothing and leaves it unchanged.
 *
 * Event codes must match PHONE_EVENT_KIND.
 */
#ifndef SEPHONE_H
#define SEPHONE_H

#include <stdint.h>

/* Event codes (mirror of PHONE_EVENT_KIND). */
#define SEPHONE_NONE 0
#define SEPHONE_STARTED 1
#define SEPHONE_RESUMED 2
#define SEPHONE_PAUSED 3
#define SEPHONE_STOPPED 4
#define SEPHONE_DESTROYED 5
#define SEPHONE_WINDOW_READY 6
#define SEPHONE_WINDOW_LOST 7
#define SEPHONE_WINDOW_RESIZED 8
#define SEPHONE_REDRAW_NEEDED 9
#define SEPHONE_FOCUS_GAINED 10
#define SEPHONE_FOCUS_LOST 11
#define SEPHONE_CONFIGURATION_CHANGED 12
#define SEPHONE_LOW_MEMORY 13
#define SEPHONE_CONTENT_RECT_CHANGED 14
#define SEPHONE_TOUCH_DOWN 20
#define SEPHONE_TOUCH_MOVE 21
#define SEPHONE_TOUCH_UP 22
#define SEPHONE_TOUCH_CANCEL 23
#define SEPHONE_KEY_DOWN 30
#define SEPHONE_KEY_UP 31

/* Back-key policy. */
#define SEPHONE_BACK_SYSTEM 0  /* Android also handles Back (finishes the app) */
#define SEPHONE_BACK_APP 1     /* consumed; only the app reacts */

/* Handle: one SIMPLE_EIF_PHONE per process. */
int  sephone_handle_exists(void);
void sephone_handle_claim(void);

/* Events. */
int  sephone_wait(int timeout_ms);  /* -1 forever; 1 = an event is ready, 0 = timeout */
void sephone_take(void);            /* pop the head into the "current" slot */
int  sephone_cur_kind(void);
int  sephone_cur_time(void);
int  sephone_cur_id(void);
int  sephone_cur_x(void);
int  sephone_cur_y(void);
int  sephone_cur_code(void);
int  sephone_dropped(void);
int  sephone_delivery_count(void);  /* events taken so far (RB-7) */
void sephone_test_push(int kind, int id, int x, int y, int code); /* TEST ONLY: queue an event directly */
int  sephone_test_capacity(void);   /* TEST ONLY: current queue slots */

/* Behavior. */
void sephone_set_back_policy(int policy);
int  sephone_back_policy(void);     /* RB-16 */
void sephone_keep_screen_on(int on);
void sephone_finish(void);

/* Window and frame (RGBX_8888 window buffer). */
int  sephone_window_exists(void);
int  sephone_window_width(void);
int  sephone_window_height(void);
int  sephone_frame_lock(void);      /* 1 if locked */
void sephone_frame_unlock(void);    /* unlock and post */
void sephone_frame_fill(int x, int y, int w, int h, int rgb);
void sephone_frame_present_argb(const void *pixels, int width, int height, int stride);
uint32_t sephone_frame_peek(int x, int y); /* TEST ONLY: buffer word at (x,y) while locked */

/* Metrics. */
int  sephone_metric_density(void);  /* dpi; 160 when Android reports 0, 0xfffe or 0xffff, or a value outside 120..640 (RB-14) */
int  sephone_metric_content_left(void);
int  sephone_metric_content_top(void);
int  sephone_metric_content_right(void);
int  sephone_metric_content_bottom(void);
int  sephone_metric_rtl(void);      /* 1 if the layout direction is right-to-left */

/* Storage (UTF-8, owned by Android; do not free). */
const char *sephone_path_internal(void);
const char *sephone_path_external(void); /* may be NULL */

/* Assets. */
int  sephone_asset_size(const char *name);                /* -1 if missing */
int  sephone_asset_read(const char *name, void *buf, int n); /* bytes read, -1 if missing */

/* Log. */
void sephone_log(int level, const char *tag, const char *text); /* level: 3 debug, 4 info, 5 warn, 6 error */

#endif
