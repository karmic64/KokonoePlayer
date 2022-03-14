#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>






/******* song ********/

/* the worst case is 5 regular FM channels, 4-op channel 3, 4 PSG channels */
#define MAX_CHANNELS 13

enum {
	CHN_FM_1,
	CHN_FM_2,
	CHN_FM_3,
	CHN_FM_4,
	CHN_FM_5,
	CHN_FM_6,
	
	CHN_FM_3_OP1,
	CHN_FM_3_OP2,
	CHN_FM_3_OP3,
	CHN_FM_3_OP4,
	
	CHN_PSG_1,
	CHN_PSG_2,
	CHN_PSG_3,
	CHN_PSG_N,
};

/* deflemask's max is 0x7f, furnace's max is 0x7e */
#define MAX_ORDERS 0x7f


const uint8_t channel_arrangement_std[] = {
	CHN_FM_1, CHN_FM_2, CHN_FM_3, CHN_FM_4, CHN_FM_5, CHN_FM_6,
	CHN_PSG_1, CHN_PSG_2, CHN_PSG_3, CHN_PSG_N,
};

const uint8_t channel_arrangement_ext[] = {
	CHN_FM_1, CHN_FM_2,
		CHN_FM_3_OP1, CHN_FM_3_OP2, CHN_FM_3_OP3, CHN_FM_3_OP4,
	CHN_FM_4, CHN_FM_5, CHN_FM_6,
	CHN_PSG_1, CHN_PSG_2, CHN_PSG_3, CHN_PSG_N,
};


typedef struct {
	uint8_t orders;
	uint8_t channels;
	
	uint8_t channel_arrangement[MAX_CHANNELS];
	
	/* table of indexes to the patterntbl, NOT the original module's orderlist */
	unsigned short orderlist[MAX_CHANNELS][MAX_ORDERS];
} song_t;



/******** pattern **********/

/* we offer notes C-0 to B-7 */
#define AMT_NOTES (12*8)

/* deflemask's max is 4, furnace's max is 8 */
#define MAX_EFFECT_COLS 8

/* both deflemask and furnace */
#define MAX_ROWS 256

typedef struct {
	short code;
	short param;
} effect_t;

#define N_EMPTY (-1)
#define N_OFF (-2)

typedef struct {
	/* we reinterpret the note values as just "semitones above C-0" */
	char note;
	
	/* index to the instrument_tbl, NOT the same as the original module's instrument */
	short instrument;
	char volume;
	
	effect_t effects[MAX_EFFECT_COLS];
} unpacked_row_t;

typedef unpacked_row_t unpacked_pattern_t[MAX_ROWS];


/* this is a "semi-compiled" pattern */
typedef struct {
	unsigned size;
	unsigned data_index;
} pattern_t;




/********* sample **********/

typedef struct {
	unsigned length; /* in samples */
	unsigned loop; /* -1 = no loop */
	
	uint8_t mode; /* bit 7: 1-unsigned/0-signed   bits 0-6: either 8 or 16 */
	
	unsigned rate; /* in hz */
	unsigned center_rate; /* in hz (when the sample is used melodically this is the C-4 rate) */
	
	unsigned data_index;
}	sample_t;

typedef sample_t *sample_map_t[AMT_NOTES];



/********* fm patch ***********/

typedef struct {
	uint8_t reg30[4];
	uint8_t reg40[4];
	uint8_t reg50[4];
	uint8_t reg60[4];
	uint8_t reg70[4];
	uint8_t reg80[4];
	uint8_t reg90[4];
	
	uint8_t regb0;
	uint8_t regb4;
} fm_patch_t;




/********* instrument **********/

enum {
	INSTR_TYPE_PSG,
	INSTR_TYPE_FM,
	INSTR_TYPE_SMPL_PERC,	/* deflemask-style "each note is a different unpitched sample" */
	INSTR_TYPE_SMPL_MELO	/* modtracker-style "one sample, each note repitches the sample" */
};


/* we only count one of the arp macro types in this definition */
#define MAX_MACROS (3+4+(11*4))
enum {
	MACRO_TYPE_VOL,
	MACRO_TYPE_ARP,
	MACRO_TYPE_ARP_FIXED,
	MACRO_TYPE_NOISE,
	
	MACRO_TYPE_FM_ALG,
	MACRO_TYPE_FM_FB,
	MACRO_TYPE_FM_FMS,
	MACRO_TYPE_FM_AMS,
	
	/* the actual operator number is added to these values */
	MACRO_TYPE_FM_OP_TL = 0x20,
	MACRO_TYPE_FM_OP_AR = 0x24,
	MACRO_TYPE_FM_OP_D1R = 0x28,
	MACRO_TYPE_FM_OP_D2R = 0x2c,
	MACRO_TYPE_FM_OP_RR = 0x30,
	MACRO_TYPE_FM_OP_D1L = 0x34,
	MACRO_TYPE_FM_OP_RS = 0x38,
	MACRO_TYPE_FM_OP_MUL = 0x3c,
	MACRO_TYPE_FM_OP_DT = 0x40,
	MACRO_TYPE_FM_OP_AM = 0x44,
	MACRO_TYPE_FM_OP_SSG_EG = 0x48,
};

#define MAX_MACRO_LEN 256

typedef struct {
	uint8_t type;	
	
	short length;
	short loop;
	short release;
	
	unsigned data_index;
} macro_t;



typedef struct {
	uint8_t type;
	
	uint8_t macros;
	uint16_t macro_ids[MAX_MACROS];
	
	/*
		PSG: unused
		FM: index to fm_patch_tbl
		SMPL_PERC: index to sample_map_tbl
		SMPL_MELO: index to sample_tbl
	*/
	unsigned extra_id;
} instrument_t;





/****************************** global storage ********************************/

/* generic buffer for arbitrary-format data (like patterns/macros/samples) */
unsigned databuf_size = 0;
unsigned databuf_max = 0;
void *databuf = NULL;

/* songs in the module */
unsigned songs = 0;
unsigned song_max = 0;
song_t *song_tbl = NULL;

/* patterns in the module */
unsigned patterns = 0;
unsigned pattern_max = 0;
pattern_t *pattern_tbl = NULL;

/* instruments in the module */
unsigned instruments = 0;
unsigned instrument_max = 0;
instrument_t *instrument_tbl = NULL;

/* macros in the module */
unsigned macros = 0;
unsigned macro_max = 0;
macro_t *macro_tbl = NULL;

/* fm patches in the module */
unsigned fm_patches = 0;
unsigned fm_patch_max = 0;
fm_patch_t *fm_patch_tbl = NULL;

/* samples in the module */
unsigned samples = 0;
unsigned sample_max = 0;
sample_t *sample_tbl = NULL;

/* sample maps in the module */
unsigned sample_maps = 0;
unsigned sample_map_max = 0;
sample_map_t *sample_map_tbl = NULL;




/*********************** struct comparison functions *************************/

int song_cmp(song_t *a, song_t *b)
{
	if (a->orders != b->orders) return 1;
	if (a->channels != b->channels) return 1;
	
	if (memcmp(a->channel_arrangement, b->channel_arrangement, a->channels*sizeof(*a->channel_arrangement))) return 1;
	
	for (unsigned c = 0; c < a->channels; c++)
	{
		if (memcmp(a->orderlist[c], b->orderlist[c], a->orders * sizeof(**a->orderlist))) return 1;
	}
	
	return 0;
}


int pattern_cmp(pattern_t *a, pattern_t *b)
{
	if (a->size != b->size) return 1;
	return memcmp(databuf+(a->data_index), databuf+(b->data_index), a->size);
}


/* "shallow" compare that doesn't take into account looping or rate */
int sample_data_cmp(sample_t *a, sample_t *b)
{
	if (a->length != b->length) return 1;
	if (a->mode != b->mode) return 1;
	return memcmp(databuf+(a->data_index), databuf+(b->data_index), a->length * ((a->mode & 0x7f) / 8));
}


int sample_cmp(sample_t *a, sample_t *b)
{
	if (a->loop != b->loop) return 1;
	if (a->rate != b->rate) return 1;
	if (a->center_rate != b->center_rate) return 1;
	
	return sample_data_cmp(a,b);
}


int fm_patch_cmp(fm_patch_t *a, fm_patch_t *b)
{
	if (memcmp(a->reg30, b->reg30, 4)) return 1;
	if (memcmp(a->reg40, b->reg40, 4)) return 1;
	if (memcmp(a->reg50, b->reg50, 4)) return 1;
	if (memcmp(a->reg60, b->reg60, 4)) return 1;
	if (memcmp(a->reg70, b->reg70, 4)) return 1;
	if (memcmp(a->reg80, b->reg80, 4)) return 1;
	if (memcmp(a->reg90, b->reg90, 4)) return 1;
	
	if (a->regb0 != b->regb0) return 1;
	if (a->regb4 != b->regb4) return 1;
	
	return 0;
}


int macro_cmp(macro_t *a, macro_t *b)
{
	if (a->type != b->type) return 1;
	if (a->length != b->length) return 1;
	if (a->loop != b->loop) return 1;
	if (a->release != b->release) return 1;
	
	return memcmp(databuf+(a->data_index), databuf+(b->data_index), a->length);
}


int instrument_cmp(instrument_t *a, instrument_t *b)
{
	if (a->type != b->type) return 1;
	if (a->macros != b->macros) return 1;
	if (memcmp(a->macro_ids, b->macro_ids, a->macros * sizeof(*a->macro_ids))) return 1;
	
	switch (a->type)
	{
		case INSTR_TYPE_FM:
			return fm_patch_cmp(&fm_patch_tbl[a->extra_id], &fm_patch_tbl[b->extra_id]);
		case INSTR_TYPE_SMPL_MELO:
			return sample_cmp(&sample_tbl[a->extra_id], &sample_tbl[b->extra_id]);
		case INSTR_TYPE_SMPL_PERC:
			return memcmp(&sample_map_tbl[a->extra_id], &sample_map_tbl[b->extra_id], sizeof(sample_map_t));
		default:
			return 0;
	}
}


int sample_map_cmp(sample_map_t *a, sample_map_t *b)
{
	return memcmp(a,b,sizeof(*a));
}




/***************************** data adder functions **************************/

/* adds data to the data buffer, returns its index */
unsigned add_data(void *data, size_t len)
{
	unsigned index = databuf_size;
	unsigned new_size = databuf_size + len;
	if (new_size > databuf_max)
	{
		if (!databuf_max) databuf_max = 0x10000;
		while (new_size > databuf_max)
			databuf_max *= 2;
		
		databuf = realloc(databuf, databuf_max);
	}
	memcpy(databuf+index, data, len);
	databuf_size = new_size;
	
	return index;
}


/* these functions add data structures to the module, and return their ids. */
/* if a duplicate is found, the old id is returned and it is NOT added. */

#define MAKE_ADD_FUNC(name, cmp_func, type, cnt, max, tbl, initial_max) \
unsigned name(type *ent) \
{ \
	for (unsigned i = 0; i < cnt; i++) \
	{ \
		if (!cmp_func(ent, &tbl[i])) return i; \
	} \
	 \
	if (cnt >= max) \
	{ \
		if (!max) max = initial_max; \
		else max *= 2; \
		 \
		tbl = realloc(tbl, max*sizeof(type)); \
	} \
	memcpy(&tbl[cnt], ent, sizeof(type)); \
	return cnt++; \
}

MAKE_ADD_FUNC(add_song, song_cmp, song_t, songs, song_max, song_tbl, 0x100)
MAKE_ADD_FUNC(add_pattern, pattern_cmp, pattern_t, patterns, pattern_max, pattern_tbl, 0x400)
MAKE_ADD_FUNC(add_sample, sample_cmp, sample_t, samples, sample_max, sample_tbl, 0x100)
MAKE_ADD_FUNC(add_fm_patch, fm_patch_cmp, fm_patch_t, fm_patches, fm_patch_max, fm_patch_tbl, 0x100)
MAKE_ADD_FUNC(add_macro, macro_cmp, macro_t, macros, macro_max, macro_tbl, 0x400)
MAKE_ADD_FUNC(add_instrument, instrument_cmp, instrument_t, instruments, instrument_max, instrument_tbl, 0x200)
MAKE_ADD_FUNC(add_sample_map, sample_map_cmp, sample_map_t, sample_maps, sample_map_max, sample_map_tbl, 0x100)

#undef MAKE_ADD_FUNC




int main(int argc, char *argv[])
{
	
	
	
	
	
}
