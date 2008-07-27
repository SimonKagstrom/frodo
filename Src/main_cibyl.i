/*
 *  main_x.i - Main program, X specific stuff
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */
#include <javax/microedition/lcdui.h>
#include <javax/microedition/io.h>

#include "Version.h"


extern int init_graphics(void);


// Global variables
char Frodo::prefs_path[256] = "";

extern char *cibyl_select_fs_root(void);
extern void cibyl_set_fs_root(char *fsr);
char *cibyl_select_game(char *base_dir);

static char *selected_game;

/*
 *  Create application object and start it
 */

int main(int argc, char **argv)
{
        NOPH_Display_t display = NOPH_Display_getDisplay(NOPH_MIDlet_get());
        NOPH_Displayable_t cur = NOPH_Display_getCurrent(display);
	Frodo *the_app;

	timeval tv;
	gettimeofday(&tv, NULL);
	srand(tv.tv_usec);

	printf("%s by Christian Bauer for Cibyl\n", VERSION_STRING);
        char *fsr = cibyl_select_fs_root();
        selected_game = cibyl_select_game(fsr);

        /* Restore the Cibyl displayable */
        NOPH_Display_setCurrent(display, cur);
	if (!init_graphics())
		return 0;

	the_app = new Frodo();
	the_app->ArgvReceived(argc, argv);
	the_app->ReadyToRun();
	delete the_app;

	return 0;
}


/*
 *  Constructor: Initialize member variables
 */

Frodo::Frodo()
{
	TheC64 = NULL;
}


/*
 *  Process command line arguments
 */

void Frodo::ArgvReceived(int argc, char **argv)
{
  /* Not in Cibyl! */
}


/*
 *  Arguments processed, run emulation
 */

void Frodo::ReadyToRun(void)
{
        strcpy(AppDirPath, "/");

	// Load preferences
        strcpy(prefs_path, "recordstore://.frodo:0");
        //	ThePrefs.Load(prefs_path);

	// Create and start C64
	TheC64 = new C64;

        Prefs *prefs = this->reload_prefs();
        strncpy(prefs->DrivePath[0], selected_game, 80);
        if (strstr(selected_game, "t64"))
          prefs->DriveType[0] = DRVTYPE_T64;
        else
          prefs->DriveType[0] = DRVTYPE_D64;
        printf("Ratt grymt: %s\n", selected_game);
        TheC64->NewPrefs(prefs);

	if (load_rom_files())
                TheC64->Run();
	delete TheC64;
}


Prefs *Frodo::reload_prefs(void)
{
	static Prefs newprefs;
	newprefs.Load(prefs_path);
	return &newprefs;
}
