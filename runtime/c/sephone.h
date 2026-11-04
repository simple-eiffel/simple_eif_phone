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
 * JAVA SERVICES: read-aloud and the file picker live in EifPhoneActivity.
 * Java answers on its own threads, so its answers go into a mailbox under
 * s_mail_lock, and ALooper_wake rouses sephone_wait. sephone_wait moves them
 * into the event queue on the android_main thread. This is the one place other
 * threads enter the glue, and they touch nothing but the mailbox.
 * Text crosses as UTF-8 bytes.
 *
 * CONTROLS: Android's own controls, for apps built with controls = true.
 * Owner: sephone_controls.c, which also explains the threads. sephone_control
 * queues an order and returns at once; orders never answer, and a control
 * speaks only through SEPHONE_CONTROL_* events. Eiffel chooses control ids.
 * sephone_canvas_* draw on the Eiffel thread, between begin and end; their
 * measures are density-independent pixels.
 *
 * Event codes must match PHONE_EVENT_KIND. Order and control codes must
 * match PHONE_CONTROL_CODES.
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
#define SEPHONE_SPEECH_READY 40
#define SEPHONE_SPEECH_FAILED 41
#define SEPHONE_SPEECH_DONE 42
#define SEPHONE_FILE_PICKED 43
#define SEPHONE_FILE_CANCELLED 44
#define SEPHONE_FILE_FAILED 45
#define SEPHONE_KEYBOARD_TEXT 46
#define SEPHONE_KEYBOARD_BACKSPACE 47
#define SEPHONE_KEYBOARD_ENTER 48
#define SEPHONE_KEYBOARD_CLOSED 49
#define SEPHONE_CONTROL_CLICKED 50
#define SEPHONE_CONTROL_CHANGED 51
#define SEPHONE_CONTROL_ROWS 52
#define SEPHONE_CONTROL_SELECTED 53
#define SEPHONE_CONTROL_PRESSED 54
#define SEPHONE_CONTROL_SWEPT 55
#define SEPHONE_CONTROL_RELEASED 56
#define SEPHONE_CONTROL_CANVAS_READY 57
#define SEPHONE_CONTROL_CANVAS_LOST 58
#define SEPHONE_CONTROL_ANSWERED 59
#define SEPHONE_CONTROL_CALLED 60
#define SEPHONE_CONTROL_FAILED 61
#define SEPHONE_CONTROL_BACK 62
#define SEPHONE_TOUCH_DOWN 20
#define SEPHONE_TOUCH_MOVE 21
#define SEPHONE_TOUCH_UP 22
#define SEPHONE_TOUCH_CANCEL 23
#define SEPHONE_KEY_DOWN 30
#define SEPHONE_KEY_UP 31

/* Kinds of control (mirror of PHONE_CONTROL_CODES). */
#define SEPHONE_CONTROL_LABEL 1
#define SEPHONE_CONTROL_BUTTON 2
#define SEPHONE_CONTROL_TEXT_BOX 3
#define SEPHONE_CONTROL_COLUMN 4
#define SEPHONE_CONTROL_ROW 5
#define SEPHONE_CONTROL_LIST 6
#define SEPHONE_CONTROL_CANVAS 7
#define SEPHONE_CONTROL_SCROLL 8
#define SEPHONE_CONTROL_CHECK_BOX 9
#define SEPHONE_CONTROL_SWITCH 10
#define SEPHONE_CONTROL_SLIDER 11
#define SEPHONE_CONTROL_PROGRESS 12
#define SEPHONE_CONTROL_CHOICE 13
#define SEPHONE_CONTROL_RADIO_GROUP 14
#define SEPHONE_CONTROL_ANY 15
#define SEPHONE_CONTROL_IMAGE 16

/* Orders (mirror of PHONE_CONTROL_CODES). */
#define SEPHONE_OP_NEW 1
#define SEPHONE_OP_ADD 2
#define SEPHONE_OP_REMOVE 3
#define SEPHONE_OP_SHOW 4
#define SEPHONE_OP_TEXT 5
#define SEPHONE_OP_ENABLED 6
#define SEPHONE_OP_VISIBLE 7
#define SEPHONE_OP_TEXT_STYLE 8
#define SEPHONE_OP_SPACING 9
#define SEPHONE_OP_HEIGHT 10
#define SEPHONE_OP_CHECKED 11
#define SEPHONE_OP_VALUE 12
#define SEPHONE_OP_MAXIMUM 13
#define SEPHONE_OP_CHOICE_ADD 14
#define SEPHONE_OP_CHOICE_CLEAR 15
#define SEPHONE_OP_SELECT 16
#define SEPHONE_OP_RADIO_ADD 17
#define SEPHONE_OP_ROW_COUNT 18
#define SEPHONE_OP_ROW 19
#define SEPHONE_OP_ROWS_DONE 20
#define SEPHONE_OP_SINGLE_LINE 21
#define SEPHONE_OP_MASKED 22
#define SEPHONE_OP_HINT 23
#define SEPHONE_OP_FOCUS 24
#define SEPHONE_OP_TOAST 25
#define SEPHONE_OP_DIALOG 26
#define SEPHONE_OP_DATE 27
#define SEPHONE_OP_TIME 28
#define SEPHONE_OP_CALL 29
#define SEPHONE_OP_ASK 30
#define SEPHONE_OP_LISTEN 31
#define SEPHONE_OP_DISCARD 32
#define SEPHONE_OP_BACK 33
#define SEPHONE_OP_IMAGE 34
#define SEPHONE_OP_MENU 35

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
const char *sephone_cur_text(void); /* service events; NULL otherwise. Valid until the next take. */
int  sephone_dropped(void);
int  sephone_delivery_count(void);  /* events taken so far (RB-7) */
void sephone_test_push(int kind, int id, int x, int y, int code); /* TEST ONLY: queue an event directly */
int  sephone_test_capacity(void);   /* TEST ONLY: current queue slots */

/* Behavior. */
int  sephone_helper_present(void);  /* 1 if this app carries EifPhoneActivity */
void sephone_speech_start(void);
void sephone_speak(const char *text, const char *language);
void sephone_speech_stop(void);
void sephone_pick_file(const char *type);
void sephone_keyboard(int show);
void sephone_set_back_policy(int policy);
int  sephone_back_policy(void);     /* RB-16 */
void sephone_keep_screen_on(int on);
void sephone_finish(void);

/* Controls. */
int  sephone_controls_present(void);        /* 1 if this app was built with controls = true */
int  sephone_controls_density_percent(void); /* screen pixels per density-independent pixel, times 100 */
void sephone_control(int op, int id, int a, int b, const char *text);

/* Drawing on a canvas control. */
int  sephone_canvas_begin(int id, int background);   /* 1 if ready to draw */
void sephone_canvas_end(void);
void sephone_canvas_color(int rgb);
void sephone_canvas_rect(double x, double y, double w, double h);
void sephone_canvas_line(double x1, double y1, double x2, double y2, double width);
void sephone_canvas_text(double x, double y, const char *text, double size, int bold);
double sephone_canvas_measure(const char *text, double size, int bold);

/* Window and frame (RGBX_8888 window buffer). */
int  sephone_window_exists(void);
int  sephone_window_width(void);
int  sephone_window_height(void);
int  sephone_frame_lock(void);      /* 1 if locked */
void sephone_frame_unlock(void);    /* unlock and post */
void sephone_frame_fill(int x, int y, int w, int h, int rgb);
void sephone_frame_present_argb(const void *pixels, int width, int height, int stride);
void sephone_frame_present_argb_at(const void *pixels, int width, int height, int stride, int x, int y);
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
