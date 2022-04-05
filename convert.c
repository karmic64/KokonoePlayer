#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <limits.h>
#include <time.h>
#include <sys/stat.h>

#include <zlib.h>



/******************* endianness-independent data reading *******************/

int16_t get16s(uint8_t *p) { return p[0] | (p[1] << 8); }
uint16_t get16u(uint8_t *p) { return p[0] | (p[1] << 8); }

int32_t get32s(uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24); }
uint32_t get32u(uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24); }




/********* "fake-reader": stream-like "I/O" on a block of memory ***********/

typedef struct {
	void *base; /* starting location */
	void *ptr; /* current location */
	void *end; /* end of data */
}	fake_reader_t;

void fr_init (fake_reader_t *fr, void *ptr, size_t size)
{
	fr->base = ptr;
	fr->ptr = ptr;
	fr->end = ptr + size;
}

void *fr_ptr (fake_reader_t *fr)
{
	return fr->ptr;
}

size_t fr_tell (fake_reader_t *fr)
{
	return fr->ptr - fr->base;
}

void fr_seek (fake_reader_t *fr, size_t pos)
{
	fr->ptr = fr->base + pos;
}

void fr_skip (fake_reader_t *fr, int disp)
{
	fr->ptr += disp;
}

void fr_rewind (fake_reader_t *fr)
{
	fr->ptr = fr->base;
}


int8_t fr_read8s (fake_reader_t *fr)
{
	int8_t v = *(int8_t *)fr->ptr;
	fr_skip(fr,1);
	return v;
}
uint8_t fr_read8u (fake_reader_t *fr)
{
	uint8_t v = *(uint8_t *)fr->ptr;
	fr_skip(fr,1);
	return v;
}

int16_t fr_read16s (fake_reader_t *fr)
{
	int16_t v = get16s(fr->ptr);
	fr_skip(fr,2);
	return v;
}
uint16_t fr_read16u (fake_reader_t *fr)
{
	uint16_t v = get16u(fr->ptr);
	fr_skip(fr,2);
	return v;
}

int32_t fr_read32s (fake_reader_t *fr)
{
	int32_t v = get32s(fr->ptr);
	fr_skip(fr,4);
	return v;
}
uint32_t fr_read32u (fake_reader_t *fr)
{
	uint32_t v = get32u(fr->ptr);
	fr_skip(fr,4);
	return v;
}


/* transforms a DMF-module string (pascal string) into a C string and returns its pointer */
char *fr_read_dmf_str (fake_reader_t *fr)
{
	void *ptr = fr->ptr;
	uint8_t len = *(uint8_t *)ptr;
	memmove(ptr, ptr + 1, len);
	((uint8_t*)ptr)[len] = '\0';
	
	fr_skip(fr, len+1);
	return ptr;
}


void fr_read (fake_reader_t *fr, void *dest, size_t size)
{
	memcpy(dest, fr->ptr, size);
	fr_skip(fr, size);
}


size_t fr_strlen (fake_reader_t *fr)
{
	return strlen(fr->ptr);
}

int fr_memcmp (fake_reader_t *fr, void *data, size_t size)
{
	return memcmp(fr->ptr, data, size);
}


char *fr_read_str (fake_reader_t *fr)
{
	char *ptr = fr->ptr;
	fr_skip(fr, fr_strlen(fr)+1);
	return ptr;
}




/****** histogram *******/

typedef struct {
	unsigned id;
	uintmax_t count;
} histogram_ent_t;

int histogram_cmp_desc(const void *a, const void *b)
{
	uintmax_t ac = ((histogram_ent_t*)a)->count;
	uintmax_t bc = ((histogram_ent_t*)b)->count;
	
	/* this comparison is inverted to sort descending */
	return (ac < bc) - (ac > bc);
}




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


const uint8_t channel_arrangement_fm[] = {
	CHN_FM_1, CHN_FM_2, CHN_FM_3, CHN_FM_4, CHN_FM_5, CHN_FM_6,
};

const uint8_t channel_arrangement_fm_ext[] = {
	CHN_FM_1, CHN_FM_2,
		CHN_FM_3_OP1, CHN_FM_3_OP2, CHN_FM_3_OP3, CHN_FM_3_OP4,
	CHN_FM_4, CHN_FM_5, CHN_FM_6,
};

const uint8_t channel_arrangement_psg[] = {
	CHN_PSG_1, CHN_PSG_2, CHN_PSG_3, CHN_PSG_N,
};


typedef struct {
	uint8_t orders;
	uint8_t channels;
	
	uint16_t pattern_size;
	
	/* time base is supported by directly multiplying any speed settings */
	uint8_t speed1;
	uint8_t speed2;
	/* song-wide arp tick speed is an outdated feature, so i don't support it */
	
	uint8_t channel_arrangement[MAX_CHANNELS];
	
	/* table of indexes to the patterntbl, NOT the original module's orderlist */
	unsigned short orderlist[MAX_CHANNELS][MAX_ORDERS];
	
	/* index to sample_map_tbl */
	unsigned sample_map;
} song_t;



/******** pattern **********/

/* we offer notes C--5 to B-8 */
#define AMT_NOTES (12*(9+5))

/* deflemask's max is 4, furnace's max is 8 */
#define MAX_EFFECT_COLUMNS 8

/* both deflemask and furnace */
#define MAX_ROWS 256


const uint8_t effect_map[] = {
	1,2,0xe1,0xe2,3,0,4,8,9,0xf,0xa,0xb,0xc,
	0xe0,0xe3,0xe4,0xe5,0xea,0xeb,0xec,0xee,
	0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x1a,0x1b,0x1c,0x1d,0x19,
	0x20,
	0xed
};
enum {
	EFF_PORTAUP = 0,
	EFF_PORTADOWN,
	EFF_NOTEUP,
	EFF_NOTEDOWN,
	EFF_TONEPORTA,
	EFF_ARP,
	EFF_VIBRATO,
	EFF_PANNING,
	EFF_SPEED1,
	EFF_SPEED2,
	EFF_VOLSLIDE,
	EFF_PATTBREAK,
	EFF_RETRIG,
	
	EFF_ARPTICK,
	EFF_VIBMODE,
	EFF_VIBDEPTH,
	EFF_FINETUNE,
	EFF_LEGATO,
	EFF_SMPLBANK,
	EFF_CUT,
	EFF_SYNC,
	
	EFF_LFO,
	EFF_FB,
	EFF_TL1,
	EFF_TL2,
	EFF_TL3,
	EFF_TL4,
	EFF_MUL,
	EFF_DAC,
	EFF_AR1,
	EFF_AR2,
	EFF_AR3,
	EFF_AR4,
	EFF_AR,
	
	EFF_NOISE,
	
	AMT_SUPPORTED_EFFECTS,
	
	EFF_DELAY = AMT_SUPPORTED_EFFECTS,
	
	AMT_EFFECTS
};



typedef struct {
	short code;
	short param;
} effect_t;

typedef struct {
	short note;
	short octave;
	
	short instrument;
	short volume;
	
	effect_t effects[MAX_EFFECT_COLUMNS];
} unpacked_row_t;

typedef unpacked_row_t unpacked_pattern_t[MAX_ROWS];


/* this is a "semi-compiled" pattern */
typedef struct {
	unsigned size;
	unsigned data_index;
	
	/*
		value calculated so that the majority of the note values
		in the pattern are in the range [base_note..base_note+$1c]
	*/
	uint8_t base_note;
	
	uint8_t top_durations; /* amount of non-zero entries in the duration histogram */
	histogram_ent_t duration_histogram[MAX_ROWS];
} pattern_t;




/********* sample **********/


/* rate indexes start from 1! */
const unsigned rate_tbl[] = {8000,11025,16000,22050,32000};
/* table ripped from furnace sources */
const double center_rate_tbl[] = {0.1666666666, 0.2, 0.25, 0.333333333, 0.5, 1, 2, 3, 4, 5, 6};

typedef struct {
	unsigned length; /* in samples */
	unsigned loop; /* -1 = no loop */
	
	unsigned rate; /* in hz */
	unsigned center_rate; /* in hz (when the sample is used melodically this is the C-4 rate) */
	
	unsigned data_index; /* we always encode samples as unsigned 8-bit */
}	sample_t;

/* table of indexes to sample_tbl */
typedef unsigned sample_map_t[AMT_NOTES];



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


/*
	Furnace DT map:
	Editor | Instr | Reg
	  -3   |   0   |  7
	  -2   |   1   |  6
	  -1   |   2   |  5
	   0   |   3   |  0
	   1   |   4   |  1
	   2   |   5   |  2
	   3   |   6   |  3
	   4   |   7   |  4
*/
const uint8_t fm_dt_map[] = {7,6,5,0,1,2,3,4};



/********* instrument **********/

/* deflemask's max is 128 */
/* furnace allows creating more than 256, but you can't actually use them */
#define MAX_INSTRUMENTS 256

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

/* both deflemask and furnace */
#define MAX_MACRO_LEN 127

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




/* keeps a count of instrument switches so we can sort by most used */
histogram_ent_t instrument_histogram[0x1000];




/*********************** struct comparison functions *************************/

int song_cmp(song_t *a, song_t *b)
{
	if (a->orders != b->orders) return 1;
	if (a->channels != b->channels) return 1;
	
	if (a->speed1 != b->speed1) return 1;
	if (a->speed2 != b->speed2) return 1;
	
	if (memcmp(a->channel_arrangement, b->channel_arrangement, a->channels*sizeof(*a->channel_arrangement))) return 1;
	
	for (unsigned c = 0; c < a->channels; c++)
	{
		if (memcmp(a->orderlist[c], b->orderlist[c], a->orders * sizeof(**a->orderlist))) return 1;
	}
	
	if (a->sample_map != b->sample_map) return 1;
	
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
	return memcmp(databuf+(a->data_index), databuf+(b->data_index), a->length);
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
			if (a->extra_id == (unsigned)-1 && b->extra_id == (unsigned)-1) return 1;
			if (a->extra_id == (unsigned)-1 || b->extra_id == (unsigned)-1) return 0;
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




/************************** module reading function ***************************/

int read_module(char *filename)
{
	int return_val = EXIT_FAILURE;	
	
	/* declare variables that the cleanup handler needs to know about */
	FILE *f = NULL;
	uint8_t *fbuf = NULL;
	size_t fbuf_size;
	
	unpacked_pattern_t *unpacked_pattern_tbl = NULL;
	
	/* this table maps unpacked patterns to the pattern_tbl */
	short *global_pattern_map = NULL;
	
	/* if the reading fails, we can safely discard any data this function created. */
	/* so, save the old table lengths so we can restore them in the fail handler */
	unsigned old_databuf_size = databuf_size;
	unsigned old_songs = songs;
	unsigned old_patterns = patterns;
	unsigned old_samples = samples;
	unsigned old_fm_patches = fm_patches;
	unsigned old_macros = macros;
	unsigned old_instruments = instruments;
	unsigned old_sample_maps = sample_maps;
	
	
	/* actually read the module */
	printf("Opening \"%s\"...",filename);
	struct stat st;
	if (stat(filename, &st))
	{
		printf("Couldn't stat: %s\n", strerror(errno));
		goto read_module_fail;
	}
	fbuf_size = st.st_size;
	fbuf = malloc(fbuf_size);
	f = fopen(filename,"rb");
	if (!f)
	{
		printf("Couldn't open for reading: %s\n", strerror(errno));
		goto read_module_fail;
	}
	if (fread(fbuf,1,fbuf_size,f) != fbuf_size)
	{
		printf("Error while reading: %s\n", strerror(errno));
		goto read_module_fail;
	}
	fclose(f);
	f = NULL;
	puts("OK");
	
	
	/* test zlib */
	if (
			!(fbuf[0] > 0x78 || (fbuf[0]&0x0f) != 8)
			&& (((fbuf[0]<<8) | fbuf[1]) % 31 == 0)
			)
	{
		puts("Module is zlib-compressed.");
		
		/* init compression */
		uint8_t *zinput = fbuf;
		fbuf = malloc(0x10000);
		
		z_stream zs;
		memset(&zs, 0, sizeof(zs));
		
		zs.next_in = zinput;
		zs.avail_in = fbuf_size;
		
		zs.next_out = fbuf;
		zs.avail_out = 0x10000;
		fbuf_size = 0x10000;
		
		/* start decompressing */
		int status = inflateInit(&zs);
		if (status < 0)
		{
			printf("Error initializing zlib: %s (status %i)\n", zs.msg, status);
			free(zinput);
			goto read_module_fail;
		}
		while (1)
		{
			status = inflate(&zs, Z_NO_FLUSH);
			if (status == Z_STREAM_END) break;
			
			if (!zs.avail_out || status == Z_BUF_ERROR)
			{
				fbuf_size *= 2;
				fbuf = realloc(fbuf, fbuf_size);
				zs.avail_out = fbuf_size - zs.total_out;
				zs.next_out = fbuf + zs.total_out;
			}
			
			if (status < 0)
			{
				printf("zlib error: %s (status %i)\n", zs.msg, status);
				inflateEnd(&zs);
				free(zinput);
				goto read_module_fail;
			}
		}
		
		
		/* done */
		inflateEnd(&zs);
		free(zinput);
		fbuf_size = zs.total_out;
	}
	
	
	
	/******* declare song variables *********/
	song_t song;
	
	char *song_name;
	char *song_author;
	unsigned time_base;
	unsigned speed1;
	unsigned speed2;
	unsigned orders;
	unsigned pattern_size;
	
	unsigned module_patterns;
	
	/* these tables map patterns/instruments/samples to their global module ids */
	/* a value of -1 indicates that the item is not defined in the song */
	short song_pattern_map[MAX_CHANNELS][MAX_ORDERS];
	short song_instrument_map[MAX_INSTRUMENTS];
	sample_map_t song_sample_map;
	
	memset(song_pattern_map, -1, sizeof(song_pattern_map));
	memset(song_instrument_map, -1, sizeof(song_instrument_map));
	memset(song_sample_map, -1, sizeof(song_sample_map));
	
	
	
	/* try detecting format */
	/*
		the readers should ONLY report errors regarding actually _READING_ the file.
		determining whether or not the values read are valid from a module perspective
		should be saved until AFTER the file is read, because the logic can pretty much
		be shared between both formats.
	*/
	fake_reader_t fr;
	fr_init(&fr, fbuf, fbuf_size);
	if (!fr_memcmp(&fr, ".DelekDefleMask.",0x10))
	{
		fr_skip(&fr,0x10);
		
		/******** deflemask reader **********/
		unsigned version = fr_read8u(&fr);
		printf("DefleMask module, version %u.\n", version);
		if (version != 0x18)
			puts("WARNING: Version is not 24 - this module may be unsupported!");
		
		/**** header ****/
		unsigned system = fr_read8u(&fr);
		switch (system)
		{
			case 0x02:
				puts("Standard Genesis module.");
				memcpy(song.channel_arrangement, channel_arrangement_std, sizeof(channel_arrangement_std));
				song.channels = 10;
				break;
			case 0x42:
				puts("Extended CHN3 Genesis module.");
				memcpy(song.channel_arrangement, channel_arrangement_ext, sizeof(channel_arrangement_ext));
				song.channels = 13;
				break;
			case 0x03:
				puts("SMS module.");
				memcpy(song.channel_arrangement, channel_arrangement_psg, sizeof(channel_arrangement_psg));
				song.channels = 4;
				break;
			default:
				printf("Invalid/unsupported system type $%02X.\n",system);
				goto read_module_fail;
		}
		
		song_name = fr_read_dmf_str(&fr);
		song_author = fr_read_dmf_str(&fr);
		fr_skip(&fr,2); /* skip highlights */
		
		time_base = fr_read8u(&fr);
		speed1 = fr_read8u(&fr);
		speed2 = fr_read8u(&fr);
		fr_skip(&fr,5); /* we don't care about custom speeds */
		
		pattern_size = fr_read32u(&fr);
		orders = fr_read8u(&fr);
		if (!pattern_size || pattern_size > MAX_ROWS)
		{
			printf("Invalid pattern size %u\n", pattern_size);
			goto read_module_fail;
		}
		if (!orders || orders > MAX_ORDERS)
		{
			printf("Invalid amount of orders %u\n", orders);
			goto read_module_fail;
		}
		
		/*
			ok, technically we should be reading the orderlist right now. but deflemask's
			way of saving patterns is absolutely nasty, so we just ignore it.
			
			essentially, in a saved module the orderlist is just for show. the patterns are
			just saved by going through the entire song and saving every pattern in the order
			they are played in the module, keeping duplicates, and worst of all, discarding
			any unused patterns.
		*/
		puts("\nReading orderlist...");
		for (unsigned chn = 0; chn < song.channels; chn++)
		{
			for (unsigned i = 0; i < orders; i++)
			{
				song.orderlist[chn][i] = i;
			}
		}
		fr_skip(&fr, song.channels * orders);
		
		/****** read instruments ******/
		puts("\nReading instruments...");
		unsigned module_instruments = fr_read8u(&fr);
		printf("Module has %u instruments.\n", module_instruments);
		for (unsigned insi = 0; insi < module_instruments; insi++)
		{
			instrument_t ins;
			
			char *ins_name = fr_read_dmf_str(&fr);
			printf("Instrument $%02X: \"%s\", ", insi,ins_name);
			unsigned imode = fr_read8u(&fr);
			switch (imode)
			{
				case 0:
				{
					puts("STD instrument.");
					ins.type = INSTR_TYPE_PSG;
					ins.macros = 0;
					
					uint8_t macro_data[MAX_MACRO_LEN];
					
					/* read volume macro */
					macro_t vol;
					vol.type = MACRO_TYPE_VOL;
					vol.release = -1; /* deflemask macros don't have release */
					
					vol.length = fr_read8u(&fr);
					if (vol.length)
					{
						if (vol.length > MAX_MACRO_LEN)
						{
							printf("Invalid volume macro length %u\n", vol.length);
							goto read_module_fail;
						}
						for (int i = 0; i < vol.length; i++)
						{
							unsigned data = fr_read32u(&fr);
							if (data > 0x0f)
							{
								printf("Invalid volume macro data %u at index %u\n", data, i);
								goto read_module_fail;
							}
							macro_data[i] = data;
						}
						vol.loop = fr_read8s(&fr);
						vol.data_index = add_data(macro_data, vol.length);
						
						ins.macro_ids[ins.macros++] = add_macro(&vol);
					}
					
					/* read arp macro */
					macro_t arp;
					arp.type = MACRO_TYPE_ARP;
					arp.release = -1;
					
					arp.length = fr_read8u(&fr);
					if (arp.length)
					{
						if (arp.length > MAX_MACRO_LEN)
						{
							printf("Invalid arp macro length %u\n", arp.length);
							goto read_module_fail;
						}
						for (int i = 0; i < arp.length; i++)
						{
							int data = fr_read32s(&fr);
							if (data < -128 || data > 127)
							{
								printf("Invalid arp macro data %i at index %u\n", data, i);
								goto read_module_fail;
							}
							macro_data[i] = data;
						}
						arp.loop = fr_read8s(&fr);
						if (fr_read8u(&fr)) 
						{
							arp.type = MACRO_TYPE_ARP_FIXED;
						}
						else
						{
							for (int i = 0; i < arp.length; i++)
								macro_data[i] -= 12;
						}
						arp.data_index = add_data(macro_data, arp.length);
						
						ins.macro_ids[ins.macros++] = add_macro(&arp);
					}
					else
					{
						fr_skip(&fr,1); /* discard arp macro mode */
					}
					
					/* read noise macro */
					macro_t noi;
					noi.type = MACRO_TYPE_NOISE;
					noi.release = -1;
					
					noi.length = fr_read8u(&fr);
					if (noi.length)
					{
						if (noi.length > MAX_MACRO_LEN)
						{
							printf("Invalid noise macro length %u\n", noi.length);
							goto read_module_fail;
						}
						for (int i = 0; i < noi.length; i++)
						{
							unsigned data = fr_read32u(&fr);
							if (data > 0x03)
							{
								printf("Invalid noise macro data %u at index %u\n", data, i);
								goto read_module_fail;
							}
							macro_data[i] = data;
						}
						noi.loop = fr_read8s(&fr);
						noi.data_index = add_data(macro_data, noi.length);
						
						ins.macro_ids[ins.macros++] = add_macro(&noi);
					}
					
					/* discard wavetable macro */
					unsigned wave_length = fr_read8u(&fr);
					if (wave_length) fr_skip(&fr, wave_length*4 + 1);
					
					
					break;
				}
				case 1:
				{
					puts("FM instrument.");
					ins.type = INSTR_TYPE_FM;
					ins.macros = 0; /* deflemask FM instruments don't have macros */
					
					fm_patch_t fm;
					unsigned alg = fr_read8u(&fr);
					unsigned fb = fr_read8u(&fr);
					unsigned fms = fr_read8u(&fr);
					unsigned ams = fr_read8u(&fr);
					
					fm.regb0 = ((fb&7)<<3) | (alg&7);
					fm.regb4 = ((ams&3)<<4) | (fms&7);
					
					for (int op = 0; op < 4; op++)
					{
						unsigned am = fr_read8u(&fr);
						unsigned ar = fr_read8u(&fr);
						unsigned d1r = fr_read8u(&fr);
						unsigned mul = fr_read8u(&fr);
						unsigned rr = fr_read8u(&fr);
						unsigned d1l = fr_read8u(&fr);
						unsigned tl = fr_read8u(&fr);
						fr_read8u(&fr); /* dt2, unused on megadrive */
						unsigned rs = fr_read8u(&fr);
						unsigned dt = fr_read8u(&fr);
						unsigned d2r = fr_read8u(&fr);
						unsigned ssg_eg = fr_read8u(&fr);
						
						fm.reg30[op] = (fm_dt_map[dt&7]<<4) | (mul&0x0f);
						fm.reg40[op] = tl&0x7f;
						fm.reg50[op] = ((rs&3)<<6) | (ar&0x1f);
						fm.reg60[op] = ((am&1)<<7) | (d1r&0x1f);
						fm.reg70[op] = d2r&0x1f;
						fm.reg80[op] = ((d1l&0x0f)<<4) | (rr&0x0f);
						fm.reg90[op] = ((ssg_eg&0x10)>>1) | (ssg_eg&7);
					}
					
					ins.extra_id = add_fm_patch(&fm);
					
					break;
				}
				default:
				{
					printf("Invalid instrument type %u.\n", imode);
					goto read_module_fail;
				}
			}
			
			song_instrument_map[insi] = add_instrument(&ins);
		}
		
		/******* discard wavetables ******/
		unsigned module_wavetables = fr_read8u(&fr);
		for (unsigned i = 0; i < module_wavetables; i++) fr_skip(&fr, fr_read32u(&fr)*4);
		
		/****** read unpacked patterns *******/
		puts("\nReading patterns...");
		module_patterns = song.channels*orders;
		unpacked_pattern_tbl = malloc(module_patterns*sizeof(*unpacked_pattern_tbl));
		memset(unpacked_pattern_tbl, -1, module_patterns*sizeof(*unpacked_pattern_tbl));
		for (unsigned chn = 0; chn < song.channels; chn++)
		{
			unsigned effect_columns = fr_read8u(&fr);
			if (effect_columns > MAX_EFFECT_COLUMNS)
			{
				printf("Channel %u has too many effect columns (%u)\n", chn,effect_columns);
				goto read_module_fail;
			}
			
			for (unsigned chn_pati = 0; chn_pati < orders; chn_pati++)
			{
				/* pattern indexes here will be remapped to indexes to pattern_tbl later */
				song_pattern_map[chn][chn_pati] = chn*orders + chn_pati;
				for (unsigned rown = 0; rown < pattern_size; rown++)
				{
					unpacked_row_t *row = &unpacked_pattern_tbl[(chn*orders) + chn_pati][rown];
					row->note = fr_read16s(&fr);
					row->octave = fr_read16s(&fr);
					row->volume = fr_read16s(&fr);
					for (unsigned eff = 0; eff < effect_columns; eff++)
					{
						int code = fr_read16s(&fr);
						/*
							deflemask has some protracker-style "do both effects at once" effects.
							but since effects are continuous instead of protracker-style, these
							effects are kind of useless. so, remap them to more sensible equivalents.
							
							we only do this for deflemask modules because i'm worried furnace might
							re-allocate them later lol
						*/
						switch (code)
						{
							case 5:
								code = 0x0a;
								break;
							case 6:
								code = 0x0a;
								break;
						}
						row->effects[eff].code = code;
						row->effects[eff].param = fr_read16s(&fr);
					}
					row->instrument = fr_read16s(&fr);
				}
			}
		}
		
		/******* read samples *******/
		puts("\nReading samples...");
		unsigned module_samples = fr_read8u(&fr);
		if (module_samples > AMT_NOTES)
		{
			printf("Song has too many samples (%u)\n", module_samples);
			goto read_module_fail;
		}
		printf("Song has %u samples.\n", module_samples);
		for (unsigned smpi = 0; smpi < module_samples; smpi++)
		{
			unsigned size = fr_read32u(&fr);
			char *name = fr_read_dmf_str(&fr);
			int rate = fr_read8s(&fr);
			int pitch = fr_read8s(&fr);
			int amp = fr_read8s(&fr); /* "editor amp" 0 corresponds to "file amp" 50 */
			int depth = fr_read8s(&fr);
			printf("Sample %u, bank %u: \"%s\", %u samples, rate %i, pitch %i, amp %i, depth %i\n",
				smpi%12, smpi/12, name,size,rate,pitch,amp,depth);
			
			if (rate < 1 || rate > 5)
			{
				puts("Invalid rate.");
				goto read_module_fail;
			}
			if (pitch < 0 || pitch > 11)
			{
				puts("Invalid pitch.");
				goto read_module_fail;
			}
			if (depth != 16)
			{
				puts("Invalid depth.");
				goto read_module_fail;
			}
			
			sample_t smp;
			smp.loop = -1; /* deflemask samples cannot loop */
			smp.rate = rate_tbl[rate-1] * center_rate_tbl[pitch];
			smp.center_rate = smp.rate;
			
			/* convert sample data from signed 16-bit to unsigned 8-bit */
			uint8_t *sample_base = fr_ptr(&fr);
			for (unsigned i = 0; i < size; i++)
			{
				int s = fr_read16s(&fr);
				/*
					for now we DON'T support sample amp, because having all those duplicates
					severely bloats the output file. it might be possible to do software-amp
					on the Z80 instead.
				*/
				/*
				int s = fr_read16s(&fr) * (amp / 50.0);
				if (s < -0x7fff) s = -0x7fff;
				else if (s > 0x7fff) s = 0x7fff;
				*/
				sample_base[i] = (s>>8) + 128;
			}
			
			/* trim out any trailing silence */
			uint8_t last_sample = sample_base[size-1];
			int to_trim = 0;
			for (unsigned i = size-2; i > 0 && sample_base[i] >= last_sample-2 && sample_base[i] <= last_sample+2; i--)
				to_trim++;
			
			size -= to_trim;
			
			smp.length = size;
			smp.data_index = add_data(sample_base,size);
			song_sample_map[smpi] = add_sample(&smp);
		}
	}
	else if (!fr_memcmp(&fr, "-Furnace module-",0x10))
	{
		fr_skip(&fr,0x10);
		
		/******** furnace reader ***********/
		unsigned version = fr_read16u(&fr);
		printf("Furnace module, version %i.\n", version);
		if (version > 65)
			puts("WARNING: Version is >65 - this module may be unsupported!");
		
		fr_skip(&fr,2);
		unsigned info_offs = fr_read32u(&fr);
		fr_seek(&fr,info_offs);
		
		
		/***** read header *****/
		if (fr_memcmp(&fr,"INFO",4))
		{
			puts("Bad info header.");
			goto read_module_fail;
		}
		fr_skip(&fr,4+4);
		time_base = fr_read8u(&fr);
		speed1 = fr_read8u(&fr);
		speed2 = fr_read8u(&fr);
		fr_skip(&fr,5); /* ignore arp tick length/custom song tick rate */
		
		pattern_size = fr_read16u(&fr);
		orders = fr_read16u(&fr);
		if (!pattern_size || pattern_size > MAX_ROWS)
		{
			printf("Invalid pattern size %u\n", pattern_size);
			goto read_module_fail;
		}
		if (!orders || orders > MAX_ORDERS)
		{
			printf("Invalid amount of orders %u\n", orders);
			goto read_module_fail;
		}
		
		fr_skip(&fr,2); /* skip highlights */
		
		unsigned module_instruments = fr_read16u(&fr);
		unsigned module_wavetables = fr_read16u(&fr);
		unsigned module_samples = fr_read16u(&fr);
		module_patterns = fr_read32u(&fr);
		printf("Module has %u instruments.\n", module_instruments);
		printf("Module has %u samples.\n", module_samples);
		printf("Module has %u patterns.\n", module_patterns);
		
		/* systems we support:
			$02: genesis
			$42: ext. genesis
			$83: ym2612
			$a0: ext.ym2612
			$03: sms
		*/
		song.channels = 0;
		unsigned has_fm = 0;
		unsigned has_psg = 0;
		
		for (unsigned i = 0; i < 32; i++)
		{
			uint8_t system = fr_read8u(&fr);
			
			if ((system == 2 || system == 0x42) && (has_fm || has_psg))
			{
				puts("Genesis system encountered, but the module already has FM/PSG.");
				goto read_module_fail;
			}
			else if (system == 2)
			{
				puts("Standard Genesis module.");
				memcpy(song.channel_arrangement+song.channels, channel_arrangement_std, sizeof(channel_arrangement_std));
				song.channels += 10;
				
				has_fm++;
				has_psg++;
			}
			else if (system == 0x42)
			{
				puts("Extended Genesis module.");
				memcpy(song.channel_arrangement+song.channels, channel_arrangement_ext, sizeof(channel_arrangement_ext));
				song.channels += 13;
				
				has_fm++;
				has_psg++;
			}
			else if (system == 0x83)
			{
				if (has_fm)
				{
					puts("Standard YM2612 encountered, but the module already has FM.");
					goto read_module_fail;
				}
				puts("Standard YM2612.");
				memcpy(song.channel_arrangement+song.channels, channel_arrangement_fm, sizeof(channel_arrangement_fm));
				song.channels += 6;
				
				has_fm++;
			}
			else if (system == 0xa0)
			{
				if (has_fm)
				{
					puts("Extended YM2612 encountered, but the module already has FM.");
					goto read_module_fail;
				}
				puts("Extended YM2612.");
				memcpy(song.channel_arrangement+song.channels, channel_arrangement_fm_ext, sizeof(channel_arrangement_fm_ext));
				song.channels += 9;
				
				has_fm++;
			}
			else if (system == 3)
			{
				if (has_psg)
				{
					puts("SMS encountered, but the module already has PSG.");
					goto read_module_fail;
				}
				puts("SMS.");
				memcpy(song.channel_arrangement+song.channels, channel_arrangement_psg, sizeof(channel_arrangement_psg));
				song.channels += 4;
				
				has_psg++;
			}
			else if (system)
			{
				printf("Invalid/unsupported system type $%02X.\n",system);
				goto read_module_fail;
			}
		}
		if (!song.channels)
		{
			puts("Module has NO systems!");
			goto read_module_fail;
		}
		printf("Module has %u channels.\n",song.channels);
		
		fr_skip(&fr, 32+32+(32*4)); /* we don't care about volume/panning/"props" */
		
		/* module metadata/flags */
		song_name = fr_read_str(&fr);
		song_author = fr_read_str(&fr);
		
		fr_skip(&fr, 20+4);
		
		/**** get data pointer offsets ****/
		void *instrument_list = fr_ptr(&fr);
		fr_skip(&fr, (module_instruments+module_wavetables)*4);
		void *sample_list = fr_ptr(&fr);
		fr_skip(&fr, module_samples*4);
		void *pattern_list = fr_ptr(&fr);
		fr_skip(&fr, module_patterns*4);
		
		
		/**** read the ORIGINAL orderlist. we correct it to module-global pattern ids later ****/
		puts("\nReading orderlist...");
		for (unsigned chn = 0; chn < song.channels; chn++)
		{
			for (unsigned i = 0; i < orders; i++)
			{
				song.orderlist[chn][i] = fr_read8u(&fr);
			}
		}
		
		/* effect columns */
		uint8_t *channel_effect_columns = fr_ptr(&fr);
		for (unsigned i = 0; i < song.channels; i++)
		{
			unsigned c = channel_effect_columns[i];
			if (c > MAX_EFFECT_COLUMNS)
			{
				printf("Channel %u has too many effect columns (%u).\n", i,c);
				goto read_module_fail;
			}
		}
		
		/* ok, we can ignore the rest of the header. */
		
		
		/************** read samples *******************/
		puts("\nReading samples...");
		for (unsigned smpi = 0; smpi < module_samples; smpi++)
		{
			fr_seek(&fr, get32u(sample_list+(4*smpi)));
			if (fr_memcmp(&fr, "SMPL",4))
			{
				puts("Bad sample header.");
				goto read_module_fail;
			}
			fr_skip(&fr,8);
			
			
			char *name = fr_read_str(&fr);
			unsigned size = fr_read32u(&fr);
			unsigned rate = fr_read32u(&fr);
			unsigned volume = fr_read16u(&fr);
			unsigned pitch = fr_read16u(&fr);
			unsigned depth = fr_read8u(&fr);
			fr_skip(&fr,1);
			unsigned center_rate = fr_read16u(&fr);
			unsigned loop = fr_read32u(&fr);
			printf("Sample %u, bank %u: \"%s\", %u samples, rate %u, volume %u, pitch %u, depth %u, center rate %u, loop %i\n",
				smpi%12, smpi/12, name, size, rate, volume, pitch, depth, center_rate, (int)loop);
			if (depth != 8 && depth != 16) depth = 16;
			
			sample_t smp;
			smp.rate = rate;
			smp.center_rate = version < 38 ? rate : center_rate;
			if (version < 58)
			{
				if (pitch > 11)
				{
					puts("Invalid pitch.");
					goto read_module_fail;
				}
				smp.rate *= center_rate_tbl[pitch];
				smp.center_rate *= center_rate_tbl[pitch];
			}
			smp.loop = version < 19 ? (unsigned)(-1) : loop;
			
			/* convert sample to unsigned 8-bit */
			uint8_t *sample_base = fr_ptr(&fr);
			for (unsigned i = 0; i < size; i++)
			{
				int s;
				if (depth == 8)
					s = fr_read8s(&fr) * 0x100;
				else
					s = fr_read16s(&fr);
				if (version < 58)
				{
					/*
						for now we DON'T support sample amp, because having all those duplicates
						severely bloats the output file. it might be possible to do software-amp
						on the Z80 instead.
					*/
					/*
					s *= (volume / 50.0);
					if (s < -0x7fff) s = -0x7fff;
					else if (s > 0x7fff) s = 0x7fff;
					*/
				}

				
				sample_base[i] = (s>>8) + 128;
			}
			
			/* trim out any trailing silence */
			if (loop == (unsigned)-1)
			{
				uint8_t last_sample = sample_base[size-1];
				int to_trim = 0;
				for (unsigned i = size-2; i > 0 && sample_base[i] >= last_sample-2 && sample_base[i] <= last_sample+2; i--)
					to_trim++;
				
				size -= to_trim;
			}
			
			
			smp.length = size;
			smp.data_index = add_data(sample_base,size);
			song_sample_map[smpi] = add_sample(&smp);
		}
		
		
		
		
		/************ read instruments *******************/
		puts("\nReading instruments...");
		for (unsigned insi = 0; insi < module_instruments; insi++)
		{
			fr_seek(&fr, get32u(instrument_list+(4*insi)));
			if (fr_memcmp(&fr, "INST",4))
			{
				puts("Bad instrument header.");
				goto read_module_fail;
			}
			fr_skip(&fr,10);
			
			
			unsigned imode = fr_read8u(&fr);
			fr_skip(&fr,1);
			char *name = fr_read_str(&fr);
			
			instrument_t ins;
			printf("Instrument $%02X: \"%s\", ",insi,name);
			switch (imode)
			{
				case 0:
					puts("STD instrument.");
					ins.type = INSTR_TYPE_PSG;
					break;
				case 1:
					puts("FM instrument.");
					ins.type = INSTR_TYPE_FM;
					break;
				case 4:
					puts("sample instrument.");
					ins.type = INSTR_TYPE_SMPL_MELO;
					break;
				default:
					printf("Invalid instrument type %u.\n", imode);
					goto read_module_fail;
			}
			
			
			/* read fm patch info */
			fm_patch_t fm;
			unsigned alg = fr_read8u(&fr);
			unsigned fb = fr_read8u(&fr);
			unsigned fms = fr_read8u(&fr);
			unsigned ams = fr_read8u(&fr);
			fr_skip(&fr,4);
			
			fm.regb0 = ((fb&7)<<3) | (alg&7);
			fm.regb4 = ((ams&3)<<4) | (fms&7);
			
			for (int op = 0; op < 4; op++)
			{
				unsigned am = fr_read8u(&fr);
				unsigned ar = fr_read8u(&fr);
				unsigned d1r = fr_read8u(&fr);
				unsigned mul = fr_read8u(&fr);
				unsigned rr = fr_read8u(&fr);
				unsigned d1l = fr_read8u(&fr);
				unsigned tl = fr_read8u(&fr);
				fr_read8u(&fr); /* dt2, unused on megadrive */
				unsigned rs = fr_read8u(&fr);
				unsigned dt = fr_read8u(&fr);
				unsigned d2r = fr_read8u(&fr);
				unsigned ssg_eg = fr_read8u(&fr);
				fr_skip(&fr,8+12);
				
				fm.reg30[op] = (fm_dt_map[dt&7]<<4) | (mul&0x0f);
				fm.reg40[op] = tl&0x7f;
				fm.reg50[op] = ((rs&3)<<6) | (ar&0x1f);
				fm.reg60[op] = ((am&1)<<7) | (d1r&0x1f);
				fm.reg70[op] = d2r&0x1f;
				fm.reg80[op] = ((d1l&0x0f)<<4) | (rr&0x0f);
				/* furnace stores this like the register, unlike deflemask */
				fm.reg90[op] = ssg_eg&0x0f;
			}
			
			
			/* sample id */
			fr_skip(&fr, 4+24);
			unsigned sample_id = fr_read16u(&fr);
			fr_skip(&fr, 16-2);
			
			
			/************ read macros ************/
			const uint8_t global_macro_type_tbl[] = {
				MACRO_TYPE_VOL, MACRO_TYPE_ARP, MACRO_TYPE_NOISE, -1,
				-1, -1, -1, -1
			};
			const uint8_t fm_macro_type_tbl[] = {
				MACRO_TYPE_FM_ALG, MACRO_TYPE_FM_FB, MACRO_TYPE_FM_FMS, MACRO_TYPE_FM_AMS
			};
			const uint8_t fm_op_macro_type_tbl[] = {
				MACRO_TYPE_FM_OP_AM, MACRO_TYPE_FM_OP_AR, MACRO_TYPE_FM_OP_D1R, MACRO_TYPE_FM_OP_MUL,
				MACRO_TYPE_FM_OP_RR, MACRO_TYPE_FM_OP_D1L, MACRO_TYPE_FM_OP_TL, -4,
				MACRO_TYPE_FM_OP_RS, MACRO_TYPE_FM_OP_DT, MACRO_TYPE_FM_OP_D2R, MACRO_TYPE_FM_OP_SSG_EG
			};
			const char* global_macro_name_tbl[] = {
				"volume","arp","duty/noise","wave","pitch","ex1","ex2","ex3"
			};
			const char* fm_macro_name_tbl[] = {
				"ALG","FB","FMS","AMS"
			};
			const char* fm_op_macro_name_tbl[] = {
				"AM","AR","D1R","MUL","RR","D1L","TL","DT2","RS","DT","D2R","SSG-EG"
			};
			
			macro_t ins_macro_tbl[8+4+(12*4)];
			for (int i = 0; i < (8+4+(12*4)); i++)
			{
				if (i < 8)
					ins_macro_tbl[i].type = global_macro_type_tbl[i];
				else if (i < 8+4)
					ins_macro_tbl[i].type = fm_macro_type_tbl[i-8];
				else
				{
					unsigned op = ((i-8-4) / 12);
					ins_macro_tbl[i].type = fm_op_macro_type_tbl[(i-8-4) % 12] + op;
				}
				ins_macro_tbl[i].length = 0;
				ins_macro_tbl[i].loop = -1;
				ins_macro_tbl[i].release = -1;
			}
			macro_t *global_macro_tbl = &ins_macro_tbl[0];
			macro_t *fm_macro_tbl = &ins_macro_tbl[8];
			macro_t *fm_op_macro_tbl = &ins_macro_tbl[8+4];
			
			/*** global macros ***/
			unsigned global_macros = version >= 17 ? 8 : 4;
			
			for (unsigned i = 0; i < global_macros; i++)
			{
				unsigned l = fr_read32u(&fr);
				if (l > MAX_MACRO_LEN)
				{
					printf("Bad %s macro length %u.\n", global_macro_name_tbl[i],l);
					goto read_module_fail;
				}
				global_macro_tbl[i].length = l;
			}
			
			for (unsigned i = 0; i < global_macros; i++)
			{
				unsigned loop = fr_read32u(&fr);
				unsigned len = global_macro_tbl[i].length;
				if (!len) continue;
				if (loop != (unsigned)-1 && loop >= len) continue;
				global_macro_tbl[i].loop = loop;
			}
			
			if (fr_read8u(&fr)) global_macro_tbl[1].type = MACRO_TYPE_ARP_FIXED;
			fr_skip(&fr,3);
			
			for (unsigned i = 0; i < global_macros; i++)
			{
				unsigned length = global_macro_tbl[i].length;
				if (length)
				{
					uint8_t macro_data[MAX_MACRO_LEN];
					for (unsigned j = 0; j < length; j++)
					{
						macro_data[j] = fr_read32s(&fr);
						if (version < 31 && global_macro_tbl[i].type == MACRO_TYPE_ARP)
							macro_data[j] -= 12;
					}
					global_macro_tbl[i].data_index = add_data(macro_data,length);
				}
			}
			
			/**** fm macros ***/
			if (version >= 29)
			{
				for (unsigned i = 0; i < 4; i++)
				{
					unsigned l = fr_read32u(&fr);
					if (l > MAX_MACRO_LEN)
					{
						printf("Bad FM %s macro length %u.\n", fm_macro_name_tbl[i],l);
						goto read_module_fail;
					}
					fm_macro_tbl[i].length = l;
				}
				
				for (unsigned i = 0; i < 4; i++)
				{
					unsigned loop = fr_read32u(&fr);
					unsigned len = fm_macro_tbl[i].length;
					if (!len) continue;
					if (loop != (unsigned)-1 && loop >= len) continue;
					fm_macro_tbl[i].loop = loop;
				}
				
				fr_skip(&fr,12);
				
				for (unsigned i = 0; i < 4; i++)
				{
					unsigned length = fm_macro_tbl[i].length;
					if (length)
					{
						uint8_t macro_data[MAX_MACRO_LEN];
						for (unsigned j = 0; j < length; j++)
						{
							macro_data[j] = fr_read32s(&fr);
						}
						fm_macro_tbl[i].data_index = add_data(macro_data,length);
					}
				}
				
				
				/***** operator macros *****/
				for (unsigned op = 0; op < 4; op++)
				{
					for (unsigned i = 0; i < 12; i++)
					{
						unsigned l = fr_read32u(&fr);
						if (l > MAX_MACRO_LEN)
						{
							printf("Bad FM op%u %s macro length %u.\n", op+1, fm_op_macro_name_tbl[i],l);
							goto read_module_fail;
						}
						fm_op_macro_tbl[(op*12) + i].length = l;
					}
					
					for (unsigned i = 0; i < 12; i++)
					{
						unsigned loop = fr_read32u(&fr);
						unsigned len = fm_op_macro_tbl[(op*12) + i].length;
						if (!len) continue;
						if (loop != (unsigned)-1 && loop >= len) continue;
						fm_op_macro_tbl[(op*12) + i].loop = loop;
					}
					
					fr_skip(&fr,12);
				}
				
				for (unsigned op = 0; op < 4; op++)
				{
					for (unsigned i = 0; i < 12; i++)
					{
						unsigned l = fm_op_macro_tbl[(op*12) + i].length;
						if (l)
						{
							uint8_t macro_data[MAX_MACRO_LEN];
							for (unsigned j = 0; j < l; j++)
							{
								macro_data[j] = fr_read8u(&fr);
							}
							fm_op_macro_tbl[(op*12) + i].data_index = add_data(macro_data,l);
						}
					}
				}
			}
			
			/***** macro release points ******/
			if (version >= 44)
			{
				for (unsigned i = 0; i < global_macros; i++)
				{
					unsigned r = fr_read32u(&fr);
					unsigned len = global_macro_tbl[i].length;
					if (!len) continue;
					if (r != (unsigned)-1 && r >= len) continue;
					global_macro_tbl[i].release = r;
				}
				
				for (unsigned i = 0; i < 4; i++)
				{
					unsigned r = fr_read32u(&fr);
					unsigned len = fm_macro_tbl[i].length;
					if (!len) continue;
					if (r != (unsigned)-1 && r >= len) continue;
					fm_macro_tbl[i].release = r;
				}
				
				for (unsigned op = 0; op < 4; op++)
				{
					for (unsigned i = 0; i < 12; i++)
					{
						unsigned r = fr_read32u(&fr);
						unsigned len = fm_op_macro_tbl[(op*12) + i].length;
						if (!len) continue;
						if (r != (unsigned)-1 && r >= len) continue;
						fm_op_macro_tbl[(op*12) + i].release = r;
					}
				}
			}
			
			/******* we are FINALLY done reading macros, now add them to the instrument ******/
			ins.macros = 0;
			for (unsigned i = 0; i < 8+4+(12*4); i++)
			{
				macro_t *m = &ins_macro_tbl[i];
				if (m->length == 0 || m->type >= 0x80) continue;
				
				ins.macro_ids[ins.macros++] = add_macro(m);
			}
			
			/****** depending on the instrument type, specify extra id */
			switch (imode)
			{
				case 1:
					ins.extra_id = add_fm_patch(&fm);
					break;
				case 4:
					if (sample_id >= AMT_NOTES)
					{
						printf("Sample ID %u too large.\n",sample_id);
						goto read_module_fail;
					}
					ins.extra_id = song_sample_map[sample_id];
					break;
			}
			
			
			/***** we're done, add the instrument ****/
			song_instrument_map[insi] = add_instrument(&ins);
		}
		
		
		
		
		/************** read patterns ************/
		puts("\nReading patterns...");
		unpacked_pattern_tbl = malloc(module_patterns*sizeof(*unpacked_pattern_tbl));
		memset(unpacked_pattern_tbl,-1,module_patterns*sizeof(*unpacked_pattern_tbl));
		for (unsigned pati = 0; pati < module_patterns; pati++)
		{
			fr_seek(&fr, get32u(pattern_list + (pati*4)));
			if (fr_memcmp(&fr,"PATR",4))
			{
				puts("Bad pattern header.");
				goto read_module_fail;
			}
			fr_skip(&fr,8);
			
			unsigned chn = fr_read16u(&fr);
			unsigned chn_pati = fr_read16u(&fr);
			if (chn >= song.channels)
			{
				printf("Invalid channel number %u.\n",chn);
				goto read_module_fail;
			}
			if (song_pattern_map[chn][chn_pati] != -1)
			{
				printf("Channel %u, pattern %u already has an assigned pattern.\n",chn,chn_pati);
				goto read_module_fail;
			}
			song_pattern_map[chn][chn_pati] = pati;
			fr_skip(&fr,4);
			
			for (unsigned rown = 0; rown < pattern_size; rown++)
			{
				unpacked_row_t *row = &unpacked_pattern_tbl[pati][rown];
				
				row->note = fr_read16s(&fr);
				/* furnace always writes 0 to the upper byte of octave regardless of its sign */
				row->octave = fr_read8s(&fr);
				fr_skip(&fr,1);
				row->instrument = fr_read16s(&fr);
				row->volume = fr_read16s(&fr);
				for (unsigned i = 0; i < channel_effect_columns[chn]; i++)
				{
					row->effects[i].code = fr_read16s(&fr);
					row->effects[i].param = fr_read16s(&fr);
				}
			}
		}
	}
	else
	{
		puts("Can't recognize format.");
		goto read_module_fail;
	}
	
	
	/********* ok, we read the module. now compile it **********/
	puts("Module was successfully read.\n");
	printf("Song name: \"%s\"\n", song_name);
	printf("Song author: \"%s\"\n", song_author);
	free(fbuf);
	fbuf = NULL;
	
	printf("Song size: %u orders, pattern size: %u rows\n", orders, pattern_size);
	song.pattern_size = pattern_size;
	song.orders = orders;
	
	printf("Time base %i, speeds %u/%u\n", time_base, speed1, speed2);
	time_base += 1;
	song.speed1 = speed1 * time_base;
	song.speed2 = speed2 * time_base;
	
	
	/********** go through the orderlist, semi-compile all the patterns, and correct
		the orderlist to reflect the actual pattern ids in the global module. */
	puts("\nCompiling patterns...");
	
	global_pattern_map = malloc(module_patterns * sizeof(*global_pattern_map));
	memset(global_pattern_map, -1, module_patterns * sizeof(*global_pattern_map));
	
	for (unsigned chn = 0; chn < song.channels; chn++)
	{
		for (unsigned ord = 0; ord < song.orders; ord++)
		{
			unsigned chn_pati = song.orderlist[chn][ord];
			unsigned pati = song_pattern_map[chn][chn_pati];
			if (pati == (unsigned)-1)
			{
				printf("Channel %u, order %u, pattern %u does not exist in the module.\n", chn,ord,chn_pati);
				goto read_module_fail;
			}
			
			if (global_pattern_map[pati] == -1)
			{
				/*
					semi-compiled pattern bytecode:
						for each row:
							if row delay:
								$fe $xx: delay $xx ticks
							if any instrument change:
								$fd $xx: instrument $xx set
								$fc $xx $yy: instrument $yyxx set
							if any volume change:
								$fb $xx: volume $xx set
							for each effect, rightmost same effect only, one of:
								$c0-$fa $yy: effect code $xx-$c0, param $yy
							for note column, either one of:
								$a9: off
								$a8: blank
								$00-$a7: note (in semitones from C--5)
							$xx row duration
				*/
				unpacked_row_t *src = unpacked_pattern_tbl[pati];
				
				size_t size = 0;
				uint8_t out[1024];
				
				pattern_t patt;
				
				/* for keeping count of duration/note usage */
				histogram_ent_t note_histogram[AMT_NOTES];
				
				for (unsigned i = 0; i < MAX_ROWS; i++)
				{
					patt.duration_histogram[i].id = i+1;
					patt.duration_histogram[i].count = 0;
				}
				for (unsigned i = 0; i < AMT_NOTES; i++)
				{
					note_histogram[i].id = i;
					note_histogram[i].count = 0;
				}
				
				/* storage of effect parameters (we optimize useless commands out) */
				int prv_ins = -1;
				int ins_changed = 0;
				unsigned prv_dur = -1;
				short prv_eff[AMT_EFFECTS];
				short cur_eff[AMT_EFFECTS];
				memset(prv_eff,-1,sizeof(prv_eff));
				
				/* the conditions for resetting the duration and outputting the row are:
					- new note event
					- instrument change
					- volume change
					- change in parameter of a continuous effect
					- any non-continuous effect
					- end of pattern
				*/
				unsigned duration = 0;
				for (unsigned rown = 0; rown < song.pattern_size; rown++)
				{
					/******* read the current row ********/
					unpacked_row_t *row = &src[rown];
					
					/* note */
					uint8_t note;
					if (row->note == 100)
					{
						note = AMT_NOTES+1;
					}
					else if (!row->note)
					{
						note = AMT_NOTES;
					}
					else
					{
						int fullnote = row->note + (row->octave * 12) + (12*5);
						if (fullnote < 0 || fullnote >= AMT_NOTES)
						{
							printf("Invalid note %i, octave %i, value %i at channel %u, order %u, row %u\n",
								row->note, row->octave, fullnote,
								chn,ord,rown);
							goto read_module_fail;
						}
						note = fullnote;
					}
					
					/* instrument */
					if (row->instrument != -1 && row->instrument != prv_ins)
					{
						if (row->instrument < 0 || row->instrument >= MAX_INSTRUMENTS || song_instrument_map[row->instrument] == -1)
						{
							printf("Invalid instrument %i at channel %u, order %u, row %u\n", row->instrument, chn,ord,rown);
							goto read_module_fail;
						}
						prv_ins = row->instrument;
						ins_changed = 1;
						
						/* fm patch effects are invalidated by instrument changes */
						prv_eff[EFF_TL1] = -1;
						prv_eff[EFF_TL2] = -1;
						prv_eff[EFF_TL3] = -1;
						prv_eff[EFF_TL4] = -1;
						prv_eff[EFF_MUL] = -1;
						prv_eff[EFF_AR] = -1;
						prv_eff[EFF_AR1] = -1;
						prv_eff[EFF_AR2] = -1;
						prv_eff[EFF_AR3] = -1;
						prv_eff[EFF_AR4] = -1;
					}
					/* volume */
					if (row->volume != -1)
					{
						if (row->volume < 0 || row->volume > 0x7f)
						{
							printf("Invalid volume %i at channel %u, order %u, row %u\n", row->volume, chn,ord,rown);
							goto read_module_fail;
						}
					}
					
					/* effects. rightmost takes priority */
					memset(cur_eff,-1,sizeof(cur_eff));
					for (unsigned i = 0; i < MAX_EFFECT_COLUMNS; i++)
					{
						int c = row->effects[i].code;
						int p = row->effects[i].param;
						
						/* turn D00 effects into BFF */
						if (c == 0x0d && !p)
						{
							c = 0x0b;
							p = 0xff;
						}
						
						/*** process effect ***/
						if (c == -1) continue;
						
						/* blank effect params seem equivalent to 0 */
						if (p == -1) p = 0;
						
						uint8_t *outp;
						if (c < 0 || c > 0xff
							|| p < 0 || p > 0xff
							|| (c == 0x0d && p) /* Dxx with nonzero xx is not supported */
							|| (c == 0x0b && p >= song.orders && p != 0xff)
							|| (c == 0x16 && p < 0x10 && p > 0x4f)
							|| (outp = memchr(effect_map, c, sizeof(effect_map)))==0)
						{
							printf("WARNING: Ignoring invalid/unsupported effect $%02X, param $%02X at channel %u, order %u, row %u, col %u\n",
								c,p,
								chn,ord,rown,i);
							continue;
						}
						
						uint8_t out = outp-effect_map;
						
						/* some "instant" effects have no effect if their parameter is 0 */
						if (out == EFF_CUT && !p) continue;
						if (out == EFF_DELAY && !p) continue;
						if (out == EFF_RETRIG && !p) continue;
						
						if (out == EFF_SPEED1 && !p) continue;
						if (out == EFF_SPEED2 && !p) continue;
						
						/* toneportamento has no effect if there is no note */
						if (out == EFF_TONEPORTA && row->note==100) continue;
						
						/* note slides have no effect if the semitones is 0 */
						if ((out == EFF_NOTEUP || out == EFF_NOTEDOWN) && !(p & 0x0f)) continue;
						
						/* some special exceptions: we only want ONE portamento */
						if (out == EFF_PORTAUP || out == EFF_PORTADOWN || out == EFF_TONEPORTA || out == EFF_NOTEUP || out == EFF_NOTEDOWN)
						{
							cur_eff[EFF_PORTAUP] = -1;
							cur_eff[EFF_PORTADOWN] = -1;
							cur_eff[EFF_TONEPORTA] = -1;
							cur_eff[EFF_NOTEUP] = -1;
							cur_eff[EFF_NOTEDOWN] = -1;
						}
						
						/* multiply speeds by time base */
						if (out == EFF_SPEED1 || out == EFF_SPEED2)
							p *= time_base;
						
						/* turn volume slide into signed 8-bit */
						if (out == EFF_VOLSLIDE)
						{
							uint8_t up = p >> 4;
							uint8_t down = p & 0x0f;
							
							/* in furnace down takes priority */
							if (down)
								p = (down ^ 0xff) + 1;
							else
								p = up;
						}
						
						/* invalid vibrato mode values act like 0 */
						if (out == EFF_VIBMODE && p > 2)
							p = 0;
						
						/* turn finetune into signed 8-bit */
						if (out == EFF_FINETUNE)
							p ^= 0x80;
						
						/* represent panning like in the $b4 fm register */
						if (out == EFF_PANNING)
						{
							unsigned l = p & 0xf0;
							unsigned r = p & 0x0f;
							if (!l && !r)
								/* 800 acts like 811 */
								p = 0xc0;
							else
								p = (l ? 0x80 : 0) | (r ? 0x40 : 0);
						}
						
						/* represent LFO like fm reg $22 */
						if (out == EFF_LFO)
						{
							unsigned en = p & 0xf0;
							unsigned f = p & 7;
							
							p = en ? (8 | f) : f;
						}
						
						/* index operator from 0 */
						if (out == EFF_MUL)
						{
							p -= 0x10;
							/* additionally change from op order -> reg order */
							uint8_t op = p & 0xf0;
							if (op == 0x10) p = (p & 0x0f) | 0x20;
							else if (op == 0x20) p = (p & 0x0f) | 0x10;
						}
						
						/* force fm parameters in range */
						if (out == EFF_FB)
							p &= 7;
						if (out >= EFF_TL1 && out <= EFF_TL4)
							p &= 0x7f;
						if (out == EFF_DAC)
							p = (p == 1);
						if (out >= EFF_AR1 && out <= EFF_AR)
							p &= 0x1f;
						
						/* represent noise mode like in macros */
						if (out == EFF_NOISE)
						{
							uint8_t f = p & 0xf0;
							uint8_t n = p & 0x0f;
							
							p = (f ? 2 : 0) | (n ? 1 : 0);
						}
						
						/* legato is just on-or-off */
						if (out == EFF_LEGATO)
							p = (p == 1);
						
						cur_eff[out] = p;
					}
					
					
					/***** output row bytecode ******/
					uint8_t ro[64];
					unsigned ros = 0;
					
					/* special case for delay effect */
					if (cur_eff[EFF_DELAY] != -1)
					{
						ro[ros++] = 0xfe;
						ro[ros++] = cur_eff[EFF_DELAY];
					}
					
					/* instrument */
					if (ins_changed)
					{
						int actual = song_instrument_map[row->instrument];
						instrument_histogram[actual].count++;
						
						if (actual < 0x100)
						{
							ro[ros++] = 0xfc;
							ro[ros++] = actual;
						}
						else
						{
							ro[ros++] = 0xfd;
							ro[ros++] = actual & 0xff;
							ro[ros++] = actual >> 8;
						}
						
						ins_changed = 0;
					}
					
					/* volume */
					if (row->volume != -1)
					{
						ro[ros++] = 0xfb;
						ro[ros++] = row->volume;
					}
					
					/* allow each individual effect to decide if it should be output */
					for (int c = AMT_SUPPORTED_EFFECTS-1; c >= 0; c--)
					{
						if (cur_eff[c] == -1) continue;
						uint8_t p = cur_eff[c];
						uint8_t oc = c + 0xc0;
						
						switch (c)
						{
							/* regular "continuous" effects, only output if the parameter was different */
							case EFF_ARP:
							case EFF_VIBRATO:
							case EFF_VOLSLIDE:
							case EFF_ARPTICK:
							case EFF_VIBMODE:
							case EFF_VIBDEPTH:
							case EFF_FINETUNE:
							case EFF_LEGATO:
							case EFF_SMPLBANK:
							case EFF_DAC:
								if (p != prv_eff[c])
								{
									ro[ros++] = oc;
									ro[ros++] = p;
									
									prv_eff[c] = p;
								}
								break;
							/* standard effect, just unconditionally place it */
							default:
								ro[ros++] = oc;
								ro[ros++] = p;
								break;
						}
					}
					
					/* note */
					ro[ros++] = note;
					if (note < AMT_NOTES)
						note_histogram[note].count++;
					
					/*** ok, now see if we should actually output a new row to the pattern ***/
					int new_row = ros != 1 || ro[0] != AMT_NOTES;
					
					if (new_row || !rown)
					{
						/* if so, output the old duration, but NOT on the first row */
						if (rown)
						{
							out[size++] = duration;
							if (duration != prv_dur)
							{
								/* only count duration CHANGES, because that's the actual bottleneck */
								patt.duration_histogram[duration-1].count++;
								prv_dur = duration;
							}
						}
						
						/* actually write it */
						memcpy(out+size, ro, ros);
						size += ros;
						
						/* reset duration counting */
						duration = 0;
					}
					duration++;
				}
				
				/* write out the last duration */
				out[size++] = duration;
				if (duration != prv_dur)
				{
					/* only count duration CHANGES, because that's the actual bottleneck */
					patt.duration_histogram[duration-1].count++;
					prv_dur = duration;
				}
				
				
				/**** add the pattern data to the pattern object ****/
				patt.size = size;
				patt.data_index = add_data(out,size);
				
				
				/**** find the optimal base note ****/
				uint8_t best_base_note = -1;
				uintmax_t best_base_count = 0;
				for (unsigned b = 0; b < AMT_NOTES-0x1c; b++)
				{
					uintmax_t total = 0;
					for (unsigned i = 0; i <= 0x1c; i++)
						total += note_histogram[b+i].count;
					
					if (total > best_base_count)
					{
						best_base_note = b;
						best_base_count = total;
					}
				}
				patt.base_note = best_base_note;
				
				
				/**** find the 4 most used durations ****/
				qsort(patt.duration_histogram, MAX_ROWS, sizeof(*patt.duration_histogram), histogram_cmp_desc);
				patt.top_durations = 0;
				for (unsigned i = 0; i < MAX_ROWS; i++)
				{
					unsigned c = patt.duration_histogram[i].count;
					if (!c) break;
					patt.top_durations++;
				}
				
				
				/**** add pattern to the table ****/
				global_pattern_map[pati] = add_pattern(&patt);
			}
			
			song.orderlist[chn][ord] = global_pattern_map[pati];
		}
	}
	
	
	
	
	
	/************ we're done, add the song to the list *************/
	song.sample_map = add_sample_map(&song_sample_map);
	
	unsigned proper_song_id = songs;
	if (add_song(&song) != proper_song_id)
	{
		puts("The song was an exact duplicate of another song. Ignoring.");
		goto read_module_fail;
	}
	
	puts("Success.\n");
	
	return_val = 0;
	goto read_module_cleanup;
	
read_module_fail:
	puts("Failed.\n");
	
	databuf_size = old_databuf_size;
	songs = old_songs;
	patterns = old_patterns;
	samples = old_samples;
	fm_patches = old_fm_patches;
	macros = old_macros;
	instruments = old_instruments;
	sample_maps = old_sample_maps;
	
	return_val = 1;
	
read_module_cleanup:
	if (f) fclose(f);
	free(fbuf);
	free(unpacked_pattern_tbl);
	free(global_pattern_map);
	
	for (int i = 0; i < 79; i++) putchar ('-');
	putchar ('\n');
	return return_val;
}





int main(int argc, char *argv[])
{
	if (argc < 2)
	{
		puts(
			"DefleMask/Furnace module converter written by karmic\n"
			"\n"
			"Usage:\n"
			"  convert modulenames..."
		);
		return EXIT_FAILURE;
	}
	
	/******** read modules ***********/
	for (unsigned i = 0; i < 0x1000; i++)
	{
		instrument_histogram[i].id = i;
		instrument_histogram[i].count = 0;
	}
	
	for (int i = 1; i < argc; i++)
		read_module(argv[i]);
	
	if (!songs)
	{
		puts("Module has no songs. Quitting.");
		return EXIT_FAILURE;
	}
	
	printf("Module has %u unique song%c.\n", songs, songs == 1 ? '\0' : 's');
	printf("Module has %u unique pattern%c.\n", patterns, patterns == 1 ? '\0' : 's');
	printf("Module has %u unique instrument%c.\n", instruments, instruments == 1 ? '\0' : 's');
	printf("Module has %u unique macro%c.\n", macros, macros == 1 ? '\0' : 's');
	printf("Module has %u unique FM patch%s.\n", fm_patches, fm_patches == 1 ? "" : "es");
	printf("Module has %u unique sample%c.\n", samples, samples == 1 ? '\0' : 's');
	
	
	
	/******** generate duration table *******/
	typedef struct {
		uint8_t count;
		uint8_t tbl[4];
	} duration_ent_t;
	
	duration_ent_t *duration_tbl = malloc(patterns * sizeof(*duration_tbl));
	histogram_ent_t *duration_histogram = malloc(patterns * sizeof(*duration_histogram));
	unsigned *duration_pattern_map = malloc(patterns * sizeof(*duration_pattern_map));
	
	memset(duration_tbl, 0, patterns * sizeof(*duration_tbl));
	for (unsigned i = 0; i < patterns; i++)
	{
		duration_histogram[i].id = i;
		duration_histogram[i].count = 0;
	}
	memset(duration_pattern_map, -1, patterns * sizeof(*duration_pattern_map));
	
	/*
		go through the patterns' top 4 durations and add them to the duration table.
		if the durations are already "encompassed" by another, it will just be re-assigned
		
		sort by top duration count descending to make the duplicate detection better
	*/
	unsigned durations = 0;
	for (unsigned count = 4; count > 0; count--)
	{
		for (unsigned i = 0; i < patterns; i++)
		{
			uint8_t pc = pattern_tbl[i].top_durations;
			if (pc > 4) pc = 4;
			if (pc != count) continue;
			histogram_ent_t *pt = pattern_tbl[i].duration_histogram;
			
			/* hunt for any matching duration lists already in the table */
			unsigned j = 0;
			for ( ; j < durations; j++)
			{
				uint8_t dc = duration_tbl[j].count;
				uint8_t *dt = duration_tbl[j].tbl;
				
				unsigned matches = 0;
				for (unsigned k = 0; k < pc; k++)
				{
					if (memchr(dt, pt[k].id, dc)) matches++;
				}
				if (matches >= pc) break;
			}
			
			/* if there is no match, add it to the table */
			if (j == durations)
			{
				duration_tbl[j].count = pc;
				for (unsigned i = 0; i < pc; i++)
					duration_tbl[j].tbl[i] = pt[i].id;
				durations++;
			}
			
			duration_pattern_map[i] = j;
			duration_histogram[j].count++;
		}
	}
	
	/* sort duration tables by usage */
	qsort(duration_histogram, durations, sizeof(*duration_histogram), histogram_cmp_desc);
	unsigned *duration_usage_map = malloc(durations * sizeof(*duration_usage_map));
	for (unsigned i = 0; i < durations; i++)
		duration_usage_map[duration_histogram[i].id] = i;
	
	
	
	
	/******** re-sort instruments by use count ********/
	qsort(instrument_histogram, instruments, sizeof(*instrument_histogram), histogram_cmp_desc);
	unsigned instrument_map[0x1000];
	for (unsigned i = 0; i < instruments; i++)
		instrument_map[instrument_histogram[i].id] = i;
	
	
	/******** write output file *********/
	time_t outtime;
	time(&outtime);
	puts("\nWriting output data...");
	FILE *f = fopen("COMPILED-MODULE.asm", "w");
	if (!f)
	{
		printf("Can't open for writing: %s\n",strerror(errno));
		return EXIT_FAILURE;
	}
	
	fprintf(f,
		";\n"
		"; This file was generated on %s"
		";\n"
		"\n", 
			ctime(&outtime));
	
	/* duration table */
	fprintf(f,
		"; Duration table.\n"
		"kn_duration_tbl:");
	for (unsigned i = 0; i < durations && i < 256; i++)
		fprintf(f, " db %u,%u,%u,%u\n",
			duration_tbl[duration_histogram[i].id].tbl[0],
			duration_tbl[duration_histogram[i].id].tbl[1],
			duration_tbl[duration_histogram[i].id].tbl[2],
			duration_tbl[duration_histogram[i].id].tbl[3]);
	fputc('\n', f);
	
	/* song table */
	fprintf(f,
		"; Song headers.\n"
		" align 1\n"
		"kn_song_tbl: dl "
		);
	for (unsigned i = 0; i < songs; i++)
		fprintf(f,"kn_song_%u%c", i, (i < songs-1)?',':'\n');
	
	/* song headers */
	for (unsigned i = 0; i < songs; i++)
	{
		song_t *s = &song_tbl[i];
		
		/*** TODO: make that 0 the song slot id */
		fprintf(f,"kn_song_%u: db 0,%u,%u,%u\n", i, s->pattern_size, s->speed1,s->speed2);
		fprintf(f,
			" dw %u\n"
			" db %u,%u\n"
			" db "
				, s->sample_map
				, s->orders,s->channels);
		for (unsigned j = 0; j < s->channels; j++)
			fprintf(f,"%u%c", s->channel_arrangement[j], (j < (unsigned)s->channels-1)?',':'\n');
		
		fprintf(f," align 1\n");
		for (unsigned j = 0; j < s->channels; j++)
		{
			fprintf(f," dl ");
			for (unsigned k = 0; k < s->orders; k++)
				fprintf(f,"kn_pat_%u%c", s->orderlist[j][k], (k < (unsigned)s->orders-1)?',':'\n');
		}
	}
	fputc('\n', f);
	
	/* patterns */
	fprintf(f,"; Patterns.\n");
	for (unsigned i = 0; i < patterns; i++)
	{
		pattern_t *p = &pattern_tbl[i];
		unsigned duration = duration_usage_map[duration_pattern_map[i]];
		/* if the duration index won't fit in a byte, just find the best substitute */
		if (duration >= 256)
		{
			histogram_ent_t *pt = p->duration_histogram;
			
			unsigned best_duration = 0;
			unsigned best_duration_match = 0;
			
			for (unsigned j = 0; j < 256; j++)
			{
				unsigned match = 0;
				duration_ent_t *d = &duration_tbl[duration_usage_map[j]];
				
				for (unsigned k = 0; k < d->count; k++)
				{
					for (unsigned l = 0; l < MAX_ROWS; l++)
					{
						if (pt[l].id == d->tbl[k])
						{
							match += pt[l].count;
							break;
						}
					}
				}
				
				if (match > best_duration_match)
				{
					best_duration = j;
					best_duration_match = match;
				}
			}
			duration = best_duration;
		}
		
		/* now actually write the data */
		fprintf(f, "kn_pat_%u: db %u,%u\n db ", i, duration,p->base_note);
		
		duration_ent_t *d = &duration_tbl[duration_histogram[duration].id];
		unsigned prv_long_dur = -1;
		
		uint8_t *pd = databuf+(p->data_index);
		unsigned ps = p->size;
		unsigned pi = 0;
		while (pi < ps)
		{
			uint8_t c = pd[pi++];
			
			if (c == 0xfc || c == 0xfd) /* instrument */
			{
				unsigned icode = pd[pi++];
				if (c == 0xfd) icode |= (pd[pi++] << 8);
				icode = instrument_map[icode];
				
				if (icode > 0xff)
					fprintf(f,"$fd,$%02X,$%02X, ",(icode>>8),(icode&0xff));
				else
					fprintf(f,"$fc,$%02X, ",icode);
			}
			else if (c == 0xfb) /* volume */
			{
				fprintf(f,"$fb,$%02X, ", pd[pi++]);
			}
			else if (c >= 0xc0) /* effect */
			{
				fprintf(f,"$%02X,$%02X, ",c,pd[pi++]);
			}
			else /* note */
			{
				/* get duration mask */
				unsigned dur = pd[pi++];
				int di = -1;
				for (unsigned i = 0; i < d->count; i++)
				{
					if (d->tbl[i] == dur)
					{
						di = i * 0x20;
						break;
					}
				}
				if (di == -1)
				{
					if (dur == prv_long_dur)
					{
						di = 0xa0;
					}
					else
					{
						prv_long_dur = dur;
						di = 0x80;
					}
				}
				
				/* get note offset */
				int no = -1;
				if (c == AMT_NOTES) /* blank */
					no = 0x1f;
				else if (c == AMT_NOTES+1) /* noteoff */
					no = 0x1e;
				else
				{
					no = c - p->base_note;
					if (no < 0 || no >= 0x1d)
						no = 0x1d;
				}
				
				/* output */
				fprintf(f,"$%02X,",di | no);
				if (di == 0x80) fprintf(f,"$%02X,",dur);
				if (no == 0x1d) fprintf(f,"$%02X,",c);
				
				
				fputc(' ',f);
			}
		}
		/* delete trailing comma */
		fseek(f,-2,SEEK_CUR);
		fputc('\n',f);
	}
	fputc('\n', f);
	
	/* instruments */
	fprintf(f,
		"; Instruments.\n"
		" align 1\n"
		"kn_instrument_tbl: dl ");
	for (unsigned i = 0; i < instruments; i++)
		fprintf(f,"kn_ins_%u%c", instrument_histogram[i].id, (i < instruments-1)?',':'\n');
	
	unsigned macro_slots = 0;
	for (unsigned i = 0; i < instruments; i++)
	{
		instrument_t *ins = &instrument_tbl[i];
		fprintf(f,
			"kn_ins_%u: db %u,%u\n"
				,i, ins->type, ins->macros);
		if (ins->macros)
		{
			fprintf(f, " dl ");
			for (unsigned j = 0; j < ins->macros; j++)
				fprintf(f,"kn_mac_%u%c", ins->macro_ids[j], (j < (unsigned)ins->macros-1)?',':'\n');
		}
		if (ins->type != INSTR_TYPE_PSG) fprintf(f," dw %u\n", ins->extra_id);
		if (ins->macros > macro_slots) macro_slots = ins->macros;
	}
	fprintf(f,"MACRO_SLOTS = %u\n", macro_slots);
	fputc('\n', f);
	
	/* macros */
	fprintf(f,
		"; Macros.\n");
	for (unsigned i = 0; i < macros; i++)
	{
		macro_t *m = &macro_tbl[i];
		fprintf(f,
			"kn_mac_%u: db %u,%u,%u,%u\n"
			" db ",
				i, m->type,m->length,m->loop,m->release);
		
		uint8_t *md = databuf+(m->data_index);
		for (int j = 0; j < m->length; j++)
			fprintf(f,"%u%c", md[j], (j < m->length-1)?',':'\n');
	}
	fputc('\n', f);
	
	/* fm patches */
	fprintf(f,
		"; FM patches.\n"
		" align 1\n"
		"kn_fm_tbl: "
		);
	if (fm_patches)
	{
		fprintf(f, " dl ");
		for (unsigned i = 0; i < fm_patches; i++)
			fprintf(f,"kn_fm_%u%c", i, (i < fm_patches-1)?',':'\n');
		
		for (unsigned i = 0; i < fm_patches; i++)
		{
			fm_patch_t *p = &fm_patch_tbl[i];
			
			fprintf(f,
				"kn_fm_%u: db ",i);
			
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg30[0],p->reg30[1],p->reg30[2],p->reg30[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg40[0],p->reg40[1],p->reg40[2],p->reg40[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg50[0],p->reg50[1],p->reg50[2],p->reg50[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg60[0],p->reg60[1],p->reg60[2],p->reg60[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg70[0],p->reg70[1],p->reg70[2],p->reg70[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg80[0],p->reg80[1],p->reg80[2],p->reg80[3]);
			fprintf(f,
				"$%02X,$%02X,$%02X,$%02X, ",
				p->reg90[0],p->reg90[1],p->reg90[2],p->reg90[3]);
			
			fprintf(f,
				"$%02X,$%02X\n"
				,p->regb0,p->regb4);
		}
	}
	fputc('\n', f);
	
	/* sample maps */
	fprintf(f,
		" align 1\n"
		"kn_sample_map_tbl:");
	fprintf(f, " dl ");
	for (unsigned i = 0; i < sample_maps; i++)
		fprintf(f,"kn_sample_map_%u%c", i, (i < sample_maps-1)?',':'\n');
	
	for (unsigned i = 0; i < sample_maps; i++)
	{
		sample_map_t *s = &sample_map_tbl[i];
		fprintf(f,"kn_sample_map_%u: dw ",i);
		for (unsigned j = 0; j < AMT_NOTES; j++)
			fprintf(f, "%u%c", (*s)[j], (j < AMT_NOTES-1)?',':'\n');
	}
	fputc('\n', f);
	
	/* samples */
	fprintf(f,
		" align 1\n"
		"kn_sample_tbl:");
	if (samples)
	{
		fprintf(f, " dl ");
		for (unsigned i = 0; i < samples; i++)
			fprintf(f,"kn_smpl_%u%c", i, (i < samples-1)?',':'\n');
		
		for (unsigned i = 0; i < samples; i++)
		{
			sample_t *s = &sample_tbl[i];
			/*
				this value is determined through trial and error and
				will break if the z80 driver is changed
			*/
#define Z80_SAMPLE_RATE (3579545.0 / 101.0)
			unsigned rate = round(((double)s->rate / Z80_SAMPLE_RATE) * 256.0);
			unsigned center_rate = round(((double)s->center_rate / Z80_SAMPLE_RATE) * 256.0);
			
			fprintf(f,
				"kn_smpl_%u: dl %u\n"
				" dw %u,%u\n"
				, i, s->loop, rate,center_rate);
			if (s->length)
			{
				fprintf(f," db ");
				for (unsigned j = 0; j < s->length; j++)
				{
					uint8_t sd = ((uint8_t*)databuf)[s->data_index+j];
					/* 0 is the end marker, 0 should never appear in sample data */
					fprintf(f, "%u,",sd ? sd : 1);
				}
			}
			fprintf(f,
				" 0,0,0,0,0,0,0,0\n"
				" align 1\n");
		}
	}
	
	
	
	
	
	fclose(f);
	puts("Success.");
	
	return EXIT_SUCCESS;
}
