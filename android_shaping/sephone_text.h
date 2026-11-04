/*
 * sephone_text.h - text for simple_shaping on Android: HarfBuzz shapes, FriBidi
 * orders, FreeType and cairo draw. Fonts are files, usually Android's own in
 * /system/fonts. Owner: sephone_text.c. Eiffel side: this folder's classes.
 * One thread: like simple_shaping itself, this is confined to its caller.
 */
#ifndef SEPHONE_TEXT_H
#define SEPHONE_TEXT_H

#include <stdint.h>

/* Bidi (UAX #9). `direction': 0 left to right, 1 right to left, 2 first strong.
   Fills `levels', one per character, and answers the paragraph level. */
int st_bidi(const uint32_t *text, int count, int direction, uint8_t *levels);

/* The script of one character, as a HarfBuzz tag. */
int st_script(uint32_t code);
int st_script_common(void);
int st_script_inherited(void);
int st_script_latin(void);

/* Fonts. `st_font_open' answers NULL if the file cannot be used. */
void *st_font_open(const char *path, int weight, int italic);
int st_file_covers(const char *path, uint32_t code);   /* does the file draw `code'? */
void st_font_close(void *font);
double st_font_ascent(void *font, int pixel_size);
double st_font_descent(void *font, int pixel_size);
void *st_font_cairo_face(void *font);   /* owned by the font */

/* Shaping. `st_shape' answers how many glyphs came out, in visual order, or -1.
   `st_shape_read' copies them out: `clusters' are character offsets in the item. */
int st_shape(void *font, int pixel_size, const uint32_t *text, int text_count,
	int start, int count, int rtl, int script);
void st_shape_read(uint32_t *glyphs, int32_t *clusters, double *advances, double *x_offsets, double *y_offsets);

#endif
