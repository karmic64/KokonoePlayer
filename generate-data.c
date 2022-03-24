#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#define PSG_CLOCK 3579545.0

#define AMT_NOTES ((5+9)*12)
#define A4_NOTE ((12*(5+5))-3)

int main()
{
	FILE *f = fopen("GENERATED-DATA.asm","w");
	
	/* generate psg period table */
	fprintf(f,"psg_period_tbl: dw ");
	for (int note = 0; note < AMT_NOTES; note++)
	{
		double freq = 440.0 * pow(2.0, (note-A4_NOTE)/12.0);
		unsigned period = round(((1.0 / freq) * PSG_CLOCK) / 2.0 / 2.0 / 2.0 / 16.0);
		
		fprintf(f,"%u%c", period>0xffff?0xffff:period, note < AMT_NOTES-1 ? ',' : '\n');
	}
	
	/* generate psg volume scaling table */
	fprintf(f,"psg_volume_tbl: db ");
	for (int v = 0; v < 256; v++)
	{
		unsigned v1 = v & 0x0f;
		unsigned v2 = v >> 4;
		
		unsigned ov = (unsigned)round(v1 * (v2 / 15.0)) ^ 0x0f;
		fprintf(f,"%u%c", ov, v < 256-1 ? ',' : '\n');
	}
	
	
	fclose(f);
}