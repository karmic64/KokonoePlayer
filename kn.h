
#ifndef KOKONOEPLAYER_H
#define KOKONOEPLAYER_H

/* Refer to the documentation for information on how to use these functions. */

#define KN_LOOP 0x8000
#define KN_NO_LOOP 0x0000

void kn_reset();
void kn_init(unsigned short, unsigned short);
void kn_play();

void kn_volume(unsigned short, unsigned short);
void kn_seek(unsigned short, unsigned short);
void kn_pause(unsigned short);
void kn_resume(unsigned short);
void kn_stop(unsigned short);

unsigned kn_sync();

#endif
