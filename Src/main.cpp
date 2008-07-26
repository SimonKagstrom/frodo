/*
 *  main.cpp - Main program
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "sysdeps.h"

#include "main.h"
#include "C64.h"
#include "Display.h"
#include "Prefs.h"
#include "SAM.h"


// Global variables
char AppDirPath[1024];	// Path of application directory


// ROM file names
#ifdef __riscos__
#define BASIC_ROM_FILE	"FrodoRsrc:Basic_ROM"
#define KERNAL_ROM_FILE	"FrodoRsrc:Kernal_ROM"
#define CHAR_ROM_FILE	"FrodoRsrc:Char_ROM"
#define FLOPPY_ROM_FILE	"FrodoRsrc:1541_ROM"
#elif CIBYL
/* Placed as resources */
#define BASIC_ROM_FILE	"/Basic_ROM"
#define KERNAL_ROM_FILE	"/Kernal_ROM"
#define CHAR_ROM_FILE	"/Char_ROM"
#define FLOPPY_ROM_FILE	"/1541_ROM"
#else
#define BASIC_ROM_FILE	"Basic ROM"
#define KERNAL_ROM_FILE	"Kernal ROM"
#define CHAR_ROM_FILE	"Char ROM"
#define FLOPPY_ROM_FILE	"1541 ROM"
#endif


/*
 *  Load C64 ROM files
 */

#ifndef __PSXOS__
bool Frodo::load_rom_files(void)
{
	FILE *file;

	// Load Basic ROM
	if ((file = fopen(BASIC_ROM_FILE, "rb")) != NULL) {
		if (fread(TheC64->Basic, 1, 0x2000, file) != 0x2000) {
			ShowRequester("Can't read 'Basic ROM'.", "Quit");
			return false;
		}
		fclose(file);
	} else {
		ShowRequester("Can't find 'Basic ROM'.", "Quit");
		return false;
	}

	// Load Kernal ROM
	if ((file = fopen(KERNAL_ROM_FILE, "rb")) != NULL) {
		if (fread(TheC64->Kernal, 1, 0x2000, file) != 0x2000) {
			ShowRequester("Can't read 'Kernal ROM'.", "Quit");
			return false;
		}
		fclose(file);
	} else {
		ShowRequester("Can't find 'Kernal ROM'.", "Quit");
		return false;
	}

	// Load Char ROM
	if ((file = fopen(CHAR_ROM_FILE, "rb")) != NULL) {
		if (fread(TheC64->Char, 1, 0x1000, file) != 0x1000) {
			ShowRequester("Can't read 'Char ROM'.", "Quit");
			return false;
		}
		fclose(file);
	} else {
		ShowRequester("Can't find 'Char ROM'.", "Quit");
		return false;
	}

	// Load 1541 ROM
	if ((file = fopen(FLOPPY_ROM_FILE, "rb")) != NULL) {
		if (fread(TheC64->ROM1541, 1, 0x4000, file) != 0x4000) {
			ShowRequester("Can't read '1541 ROM'.", "Quit");
			return false;
		}
		fclose(file);
	} else {
		ShowRequester("Can't find '1541 ROM'.", "Quit");
		return false;
	}

	return true;
}
#endif


#ifdef __BEOS__
#include "main_Be.i"
#endif

#ifdef AMIGA
#include "main_Amiga.i"
#endif


#ifdef CIBYL
#include "main_cibyl.i"
#elif __unix
#include "main_x.i"
#endif

#ifdef __mac__
#include "main_mac.i"
#endif

#ifdef WIN32
#include "main_WIN32.i"
#endif

#ifdef __riscos__
#include "main_Acorn.i"
#endif

#ifdef __PSXOS__
#include "main_PSX.i"
#endif
