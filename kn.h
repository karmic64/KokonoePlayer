
#ifndef KOKONOEPLAYER_H
#define KOKONOEPLAYER_H

/* Refer to the documentation for information on how to use these functions. */

#define KN_LOOP 0x80000000
#define KN_NO_LOOP 0x00000000

void kn_reset();
void kn_init(unsigned, unsigned);
void kn_play();

void kn_volume(unsigned, unsigned);
void kn_seek(unsigned, unsigned);
void kn_pause(unsigned);
void kn_resume(unsigned);
void kn_stop(unsigned);

unsigned kn_sync();

#endif
