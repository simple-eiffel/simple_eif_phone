/*
 * eif_phone_glue.c - spike 01 Android side.
 * Built with the NDK's android_native_app_glue: android_main runs on its own
 * thread; we start the Eiffel system there and let Eiffel pull events.
 */
#include <android_native_app_glue.h>
#include <android/log.h>
#include <android/native_window.h>
#include <stdint.h>
#include "eif_phone.h"

extern int GE_main(int argc, char **argv);

static struct android_app *ep_app = 0;
static ANativeWindow_Buffer ep_buf;
static int ep_locked = 0;
static int ep_tx = 0, ep_ty = 0;

#define EP_QSIZE 64
static int ep_q[EP_QSIZE];
static int ep_qh = 0, ep_qt = 0;

static void ep_push(int e)
{
	int n = (ep_qt + 1) % EP_QSIZE;
	if (n != ep_qh) { ep_q[ep_qt] = e; ep_qt = n; }
}

static void ep_on_cmd(struct android_app *app, int32_t cmd)
{
	switch (cmd) {
	case APP_CMD_INIT_WINDOW:
		if (app->window) {
			ANativeWindow_setBuffersGeometry(app->window, 0, 0, WINDOW_FORMAT_RGBX_8888);
		}
		ep_push(1);
		break;
	case APP_CMD_WINDOW_REDRAW_NEEDED:
	case APP_CMD_CONFIG_CHANGED:
	case APP_CMD_GAINED_FOCUS:
		ep_push(1);
		break;
	case APP_CMD_TERM_WINDOW:
		ep_push(2);
		break;
	case APP_CMD_DESTROY:
		ep_push(3);
		break;
	default:
		break;
	}
}

static int32_t ep_on_input(struct android_app *app, AInputEvent *ev)
{
	if (AInputEvent_getType(ev) == AINPUT_EVENT_TYPE_MOTION) {
		int a = AMotionEvent_getAction(ev) & AMOTION_EVENT_ACTION_MASK;
		if (a == AMOTION_EVENT_ACTION_DOWN) {
			ep_tx = (int)AMotionEvent_getX(ev, 0);
			ep_ty = (int)AMotionEvent_getY(ev, 0);
			ep_push(4);
		}
		return 1;
	}
	return 0;
}

int ep_next_event(void)
{
	int e;
	while (ep_qh == ep_qt) {
		int events;
		struct android_poll_source *src = 0;
		if (ep_app->destroyRequested) return 3;
		if (ALooper_pollOnce(-1, 0, &events, (void **)&src) >= 0 && src) {
			src->process(ep_app, src);
		}
	}
	e = ep_q[ep_qh];
	ep_qh = (ep_qh + 1) % EP_QSIZE;
	return e;
}

int ep_tap_x(void) { return ep_tx; }
int ep_tap_y(void) { return ep_ty; }

int ep_width(void)
{
	if (ep_locked) return ep_buf.width;
	return ep_app->window ? ANativeWindow_getWidth(ep_app->window) : 0;
}

int ep_height(void)
{
	if (ep_locked) return ep_buf.height;
	return ep_app->window ? ANativeWindow_getHeight(ep_app->window) : 0;
}

int ep_begin_frame(void)
{
	if (ep_locked || !ep_app->window) return 0;
	if (ANativeWindow_lock(ep_app->window, &ep_buf, 0) != 0) return 0;
	ep_locked = 1;
	return 1;
}

void ep_fill(int x, int y, int w, int h, int rgb)
{
	int x1, y1, row, col;
	uint32_t px, *line;
	if (!ep_locked) return;
	x1 = x + w; y1 = y + h;
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	if (x1 > ep_buf.width) x1 = ep_buf.width;
	if (y1 > ep_buf.height) y1 = ep_buf.height;
	/* RGBX_8888 is R,G,B,X in memory: little-endian word 0xXXBBGGRR. */
	px = 0xFF000000u | ((uint32_t)(rgb & 0xFF) << 16) | ((uint32_t)rgb & 0xFF00u) | ((uint32_t)(rgb >> 16) & 0xFFu);
	for (row = y; row < y1; row++) {
		line = (uint32_t *)ep_buf.bits + (size_t)row * ep_buf.stride;
		for (col = x; col < x1; col++) line[col] = px;
	}
}

void ep_end_frame(void)
{
	if (ep_locked) {
		ANativeWindow_unlockAndPost(ep_app->window);
		ep_locked = 0;
	}
}

extern size_t GC_get_heap_size(void);
extern size_t GC_get_gc_no(void);
long long ep_gc_count(void) { return (long long)GC_get_gc_no(); }

long long ep_heap_size(void)
{
	return (long long)GC_get_heap_size();
}

void ep_log(const char *text)
{
	__android_log_write(ANDROID_LOG_INFO, "Eiffel", text);
}

void android_main(struct android_app *app)
{
	char *argv[] = { "eiffel", 0 };
	int events;
	struct android_poll_source *src;

	ep_app = app;
	app->onAppCmd = ep_on_cmd;
	app->onInputEvent = ep_on_input;
	__android_log_write(ANDROID_LOG_INFO, "EifPhone", "android_main: starting Eiffel");
	GE_main(1, argv);
	__android_log_write(ANDROID_LOG_INFO, "EifPhone", "android_main: Eiffel returned");
	/* Eiffel is done: finish the activity and drain until Android destroys it. */
	ANativeActivity_finish(app->activity);
	while (!app->destroyRequested) {
		src = 0;
		if (ALooper_pollOnce(-1, 0, &events, (void **)&src) >= 0 && src) src->process(app, src);
	}
}
