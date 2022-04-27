
#ifndef KOKONOEPLAYER_H
#define KOKONOEPLAYER_H

/* Refer to the documentation for information on how to use these functions. */

#define KN_LOOP 0x80000000
#define KN_NO_LOOP 0x00000000

void kn_reset(void * music_base);
void kn_init(void * music_base, unsigned song_id, unsigned song_slot);
void kn_play(void * music_base);

void kn_volume(void * music_base, unsigned volume, unsigned song_slot);
void kn_seek(void * music_base, unsigned order, unsigned song_slot);
void kn_pause(void * music_base, unsigned song_slot);
void kn_resume(void * music_base, unsigned song_slot);
void kn_stop(void * music_base, unsigned song_slot);

unsigned kn_sync(void * music_base);

#endif
