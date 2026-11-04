/*
 * eif_phone.h - spike 01 glue between Gobo-generated Eiffel C and Android.
 * Android's NativeActivity calls android_main (eif_phone_glue.c), which
 * starts the Eiffel system through GE_main. Eiffel then owns the event loop.
 */
#ifndef EIF_PHONE_H
#define EIF_PHONE_H

int  ep_next_event(void);   /* 1 window ready, 2 window lost, 3 destroy, 4 tap */
int  ep_tap_x(void);
int  ep_tap_y(void);
int  ep_width(void);
int  ep_height(void);
int  ep_begin_frame(void);  /* 1 if the screen is locked for drawing */
void ep_fill(int x, int y, int w, int h, int rgb);
void ep_end_frame(void);
void ep_log(const char *text);
long long ep_heap_size(void); /* Boehm GC heap size in bytes */
long long ep_gc_count(void);  /* number of collections so far */

#endif
