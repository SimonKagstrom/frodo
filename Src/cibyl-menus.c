/*********************************************************************
 *
 * Copyright (C) 2008,  Simon Kagstrom
 *
 * Filename:      cibyl-menus.c
 * Author:        Simon Kagstrom <simon.kagstrom@gmail.com>
 * Description:   Cibyl menu item impl.
 *
 * $Id:$
 *
 ********************************************************************/
#include <javax/microedition/lcdui.h>
#include <javax/microedition/io.h>
#include <java/util.h>
#include "command_mgr.h"

static NOPH_List_t fs_list;
static char roots[5][40];
static char *fs_root = NULL;

static void select_fs_callback(void *unused)
{
  int nr = NOPH_List_getSelectedIndex(fs_list);

  fs_root = roots[nr];
}

const char *cibyl_select_fs_root(void)
{
	NOPH_Display_t display = NOPH_Display_getDisplay(NOPH_MIDlet_get());
	NOPH_Displayable_t cur = NOPH_Display_getCurrent(display);
	NOPH_CommandMgr_t cm = NOPH_CommandMgr_getInstance();
	NOPH_Enumeration_t en = NOPH_FileSystemRegistry_listRoots();
	FILE *conf;
	int i = 0;

	fs_root = NULL;

	fs_list = NOPH_List_new("Select fs root", NOPH_Choice_IMPLICIT);

	while (NOPH_Enumeration_hasMoreElements(en))
	{
		NOPH_Object_t o = NOPH_Enumeration_nextElement(en);

		NOPH_String_toCharPtr(o, roots[i], 40);
		NOPH_List_append(fs_list, roots[i], 0);
		NOPH_delete(o);
		i++;
	}
	NOPH_delete(en);
	NOPH_Display_setCurrent(display, fs_list);
	NOPH_CommandMgr_setList(cm, fs_list, select_fs_callback, NULL);

	while(fs_root == NULL)
	{
		NOPH_Thread_sleep(250);
	}
#if 0
	conf = fopen("recordstore://sarien-conf:1", "w");
	if (conf)
	{
		char buf[40];

		strncpy(buf, fs_root, 40);
		fwrite(buf, 1, 40, conf);
		fclose(conf);
	}
#endif
	NOPH_Display_setCurrent(display, cur);
	NOPH_delete(fs_list);

        return fs_root;
}

void cibyl_set_fs_root(char *fsr)
{
        fs_root = fsr;
}


static NOPH_List_t game_list;
static char *selected_game = NULL;
static char **all_games = NULL;

/* Is this ugly? Yes. Horribly! */
static void select_game_callback(void *unused)
{
        int nr = NOPH_List_getSelectedIndex(game_list);

        selected_game = all_games[nr];
}

static char *get_current_directory(void)
{
        static char root[40];
        snprintf(root, 40, "file:///%sfrodo", fs_root);
        return root;
}

static char *get_game_directory(const char *game)
{
        static char root[80];
        snprintf(root, 80, "file:///%sfrodo/%s", fs_root, game);
        return root;
}


static char **read_directory(char *base_dir)
{
        DIR *d = opendir(base_dir);
        char **out;
        int cur = 0;
        struct dirent *de;
        int last = 32;

        if (!d)
                return NULL;

        out = (char**)malloc(32 * sizeof(char*));
        out[cur] = NULL;

        for (de = readdir(d);
             de;
             de = readdir(d))
        {
                /* We actually only allow d64 for now */
                if (strstr(de->d_name, ".d64") ||
                    strstr(de->d_name, ".t64"))
                {
                        char *p;
                        p = strdup(de->d_name);
                        out[cur++] = p;
                        out[cur] = NULL;
                        if (cur > last)
                        {
                                last += 32;
                                out = (char**)realloc(out,
                                                      last * sizeof(char*));
                        }
                }
        }
        closedir(d);

        return out;
}

char *cibyl_select_game(char *base_dir)
{
        NOPH_Display_t display = NOPH_Display_getDisplay(NOPH_MIDlet_get());
        NOPH_Displayable_t cur = NOPH_Display_getCurrent(display);
        NOPH_CommandMgr_t cm = NOPH_CommandMgr_getInstance();
        char **p;

        all_games = read_directory(get_current_directory());
        if (!all_games)
                return NULL;

        game_list = NOPH_List_new("Select game", NOPH_Choice_IMPLICIT);

        for (p = all_games; *p; p++)
        {
                NOPH_List_append(game_list, *p, 0);
        }
        NOPH_Display_setCurrent(display, game_list);

        printf("Setting list\n");

        NOPH_CommandMgr_setList(cm, game_list, select_game_callback, NULL);

        while(selected_game == NULL)
        {
                NOPH_Thread_sleep(250);
        }
        free(all_games);

        NOPH_Display_setCurrent(display, cur);
        NOPH_delete(game_list);

        return get_game_directory(selected_game);
}
