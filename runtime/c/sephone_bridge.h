/*
 * sephone_bridge.h - what sephone_glue.c and sephone_controls.c share.
 * Kept out of sephone.h so that generated Eiffel C never sees jni.h.
 */
#ifndef SEPHONE_BRIDGE_H
#define SEPHONE_BRIDGE_H

#include <jni.h>

jobject sephone_activity(void);     /* the Activity (a global reference) */
JNIEnv *sephone_thread_env(void);   /* JNI handle of the Eiffel thread */

/* Hand an event to the Eiffel thread, from any thread. Takes over `text'. */
void sephone_mail(int kind, int code, int id, int x, int y, char *text);

/* Called once, on the Eiffel thread, before Eiffel starts. `cls' is the activity's class. */
void sephone_controls_setup(JNIEnv *env, jclass cls);

#endif
