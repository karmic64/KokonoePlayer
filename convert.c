#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>

#include <zlib.h>



/******************* endianness-independent data reading *******************/

int16_t get16s(uint8_t *p) { return p[0] | (p[1] << 8); }
uint16_t get16u(uint8_t *p) { return p[0] | (p[1] << 8); }

int16_t get32s(uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24); }
uint16_t get32u(uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24); }




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
	
	uint8_t pattern_size; /* minus 1! */
	
	/* time base is supported by directly multiplying any speed settings */
	uint8_t speed1;
	uint8_t speed2;
	/* song-wide arp tick speed is an outdated feature, so i don't support it */
	
	uint8_t channel_arrangement[MAX_CHANNELS];
	
	/* table of indexes to the patterntbl, NOT the original module's orderlist */
	unsigned short orderlist[MAX_CHANNELS][MAX_ORDERS];
} song_t;



/******** pattern **********/

/* we offer notes C-0 to B-7 */
#define AMT_NOTES (12*8)

/* deflemask's max is 4, furnace's max is 8 */
#define MAX_EFFECT_COLUMNS 8

/* both deflemask and furnace */
#define MAX_ROWS 256

typedef struct {
	short code;
	short param;
} effect_t;

#define N_EMPTY (-1)
#define N_OFF (-2)

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
} pattern_t;




/********* sample **********/

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
	int chn3_extd;
	int time_base;
	int speed1;
	int speed2;
	int orders;
	int pattern_size;
	
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
				chn3_extd = 0;
				break;
			case 0x42:
				puts("Extended CHN3 Genesis module.");
				chn3_extd = 1;
				break;
			default:
				printf("Invalid/unsupported system type $%02X.\n",system);
				goto read_module_fail;
		}
		song.channels = chn3_extd ? 13 : 10;
		
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
		
		/**** read the ORIGINAL orderlist. we correct it to module-global pattern ids later ****/
		puts("\nReading orderlist...");
		for (int chn = 0; chn < song.channels; chn++)
		{
			for (int i = 0; i < orders; i++)
			{
				song.orderlist[chn][i] = fr_read8u(&fr);
			}
		}
		
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
						if (fr_read8u(&fr)) arp.type = MACRO_TYPE_ARP_FIXED;
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
						
						fm.reg30[op] = ((dt&7)<<4) | (mul&0x0f);
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
		unsigned wavetables = fr_read8u(&fr);
		for (unsigned i = 0; i < wavetables; i++) fr_skip(&fr, fr_read32u(&fr)*4);
		
		/****** read unpacked patterns *******/
		puts("\nReading patterns...");
		unpacked_pattern_tbl = malloc(song.channels*orders*sizeof(*unpacked_pattern_tbl));
		memset(unpacked_pattern_tbl, -1, song.channels*orders*sizeof(*unpacked_pattern_tbl));
		for (unsigned chn = 0; chn < song.channels; chn++)
		{
			unsigned effect_columns = fr_read8u(&fr);
			if (effect_columns > MAX_EFFECT_COLUMNS)
			{
				printf("Channel %u has too many effect columns (%u)\n", chn,effect_columns);
				goto read_module_fail;
			}
			
			for (int ord = 0; ord < orders; ord++)
			{
				for (int rown = 0; rown < pattern_size; rown++)
				{
					unpacked_row_t *row = &unpacked_pattern_tbl[(chn*orders) + ord][rown];
					row->note = fr_read16s(&fr);
					row->octave = fr_read16s(&fr);
					row->volume = fr_read16s(&fr);
					for (unsigned eff = 0; eff < effect_columns; eff++)
					{
						row->effects[eff].code = fr_read16s(&fr);
						row->effects[eff].param = fr_read16s(&fr);
					}
					row->instrument = fr_read16s(&fr);
				}
			}
		}
		
		/******* read samples *******/
		puts("\nReading samples...");
		unsigned samples = fr_read8u(&fr);
		if (samples > AMT_NOTES)
		{
			printf("Song has too many samples (%u)\n", samples);
			goto read_module_fail;
		}
		printf("Song has %u samples.\n", samples);
		for (unsigned smpi = 0; smpi < samples; smpi++)
		{
			/* rate indexes start from 1! */
			const unsigned rate_tbl[] = {8000,11025,16000,22050,32000};
			/* table ripped from furnace sources lol */
			const double center_rate_tbl[] = {0.1666666666, 0.2, 0.25, 0.333333333, 0.5, 1, 2, 3, 4, 5, 6};
			
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
			smp.length = size;
			smp.loop = -1; /* deflemask samples cannot loop */
			smp.rate = rate_tbl[rate-1];
			smp.center_rate = smp.rate * center_rate_tbl[pitch];
			
			/* convert sample data from signed 16-bit to unsigned 8-bit */
			uint8_t *sample_base = fr_ptr(&fr);
			for (unsigned i = 0; i < size; i++)
			{
				int16_t s = fr_read16s(&fr) * (amp / 50.0);
				sample_base[i] = (s>>8) + 128;
			}
			smp.data_index = add_data(sample_base,size);
			song_sample_map[smpi] = add_sample(&smp);
		}
	}
	else if (!fr_memcmp(&fr, "-Furnace module-",0x10))
	{
		fr_skip(&fr,0x10);
		
		/******** furnace reader ***********/
		signed version = fr_read16s(&fr);
		printf("Furnace module, version %i.\n", version);
		if (version > 65)
			puts("WARNING: Version is >65 - this module may be unsupported!");
		
		puts("NOT DONE YET.");
		goto read_module_fail;
	}
	else
	{
		puts("Can't recognize format.");
		goto read_module_fail;
	}
	free(fbuf);
	fbuf = NULL;
	
	
	/********* ok, we read the module. now compile it **********/
	puts("Module was successfully read.\n");
	printf("Song name: \"%s\"\n", song_name);
	printf("Song author: \"%s\"\n", song_author);
	
	printf("Song size: %u orders, pattern size: %u rows\n", orders, pattern_size);
	song.pattern_size = pattern_size-1;
	song.orders = orders;
	
	printf("Time base %i, speeds %u/%u\n", time_base, speed1, speed2);
	time_base = time_base ? time_base : 1;
	song.speed1 = speed1 * time_base;
	song.speed2 = speed2 * time_base;
	
	
	
	/************ we're done, add the song to the list *************/
	
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
	putchar('\n');
	
	
	return EXIT_SUCCESS;
}
