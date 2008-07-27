/*
 *  Display_Cibyl.i - C64 graphics display, emulator window handling,
 *                    Cibyl specific stuff. Based on Display_SDL.i
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "C64.h"
#include "SAM.h"
#include "Version.h"

#include <javax/microedition/lcdui/game.h>
#include <javax/microedition/lcdui.h>

#define PALETTE_SIZE 16

// Display surface and canvas
static int palette[PALETTE_SIZE];
static int screen[320*240];
static uint8 __attribute__((aligned((4)))) bitmap[DISPLAY_X * DISPLAY_Y];
static NOPH_GameCanvas_t canvas;
static NOPH_Graphics_t graphics;

#define ROTATED 1

// Keyboard
static bool num_locked = false;

// For LED error blinking
static C64Display *c64_disp;

/*
  C64 keyboard matrix:

    Bit 7   6   5   4   3   2   1   0
  0    CUD  F5  F3  F1  F7 CLR RET DEL
  1    SHL  E   S   Z   4   A   W   3
  2     X   T   F   C   6   D   R   5
  3     V   U   H   B   8   G   Y   7
  4     N   O   K   M   0   J   I   9
  5     ,   @   :   .   -   L   P   +
  6     /   ^   =  SHR HOM  ;   *   �
  7    R/S  Q   C= SPC  2  CTL  <-  1
*/

extern char char_to_key[];

/*
 *  Open window
 */

int init_graphics(void)
{
        canvas = NOPH_GameCanvas_get();
        graphics = NOPH_GameCanvas_getGraphics(canvas);

        NOPH_Canvas_setFullScreenMode(canvas, 1);

	return 1;
}


/*
 *  Display constructor
 */

C64Display::C64Display(C64 *the_c64) : TheC64(the_c64)
{
	// LEDs off
	for (int i=0; i<4; i++)
		led_state[i] = old_led_state[i] = LED_OFF;

	// Start timer for LED error blinking
	c64_disp = this;
}


/*
 *  Display destructor
 */

C64Display::~C64Display()
{
        /* Delete something here? */
}


/*
 *  Prefs may have changed
 */

void C64Display::NewPrefs(Prefs *prefs)
{
}

#if 0
/*
 *  Redraw bitmap
 */
void C64Display::UpdateHalfSize(void)
{
        int x, y;
	/* Update display.
         *
         * This is done in sweeps of 4 to improve Cibyl performance
         */
        for (y = 30; y < DISPLAY_Y; y++)
        {
                for (x = 0; x < DISPLAY_X; x+=sizeof(int))
                {
                        int src_off = y * DISPLAY_X + x;
                        int dst_off = (y-30) * DISPLAY_X + x/2; //((DISPLAY_X-x) * DISPLAY_X)/2 + y;
                        int *_bitmap = (int*)bitmap;
                        int v = _bitmap[ src_off / sizeof(int) ];
                        int b0 = (v & 0x000000ff);
//                        int b1 = (v & 0x0000ff00) >> 8;
                        int b2 = (v & 0x00ff0000) >> 16;
//                        int b3 = (v & 0xff000000) >> 24;

                      screen[ dst_off + 0 ] = palette[ b2 ];
//                      screen[ dst_off + 1 ] = palette[ b2 ];
                        screen[ dst_off + 1 ] = palette[ b0 ];
//                      screen[ dst_off + 3 ] = palette[ b0 ];
                }
        }
        NOPH_Graphics_drawRGB(graphics, (int)screen, 0, DISPLAY_X,
                              0, 0,
                              176, 220, 0);
        NOPH_GameCanvas_flushGraphics(canvas);
}

void C64Display::UpdateFullSize(void)
{
        int x, y;

        for (y = 30; y < DISPLAY_Y; y++)
        {
                for (x = 0; x < DISPLAY_X; x+=sizeof(int))
                {
                        int src_off = y * DISPLAY_X + x;
                        int dst_off = (y-30) * DISPLAY_X + x/2; //((DISPLAY_X-x) * DISPLAY_X)/2 + y;
                        int *_bitmap = (int*)bitmap;
                        int v = _bitmap[ src_off / sizeof(int) ];
                        int b0 = (v & 0x000000ff);
                        int b1 = (v & 0x0000ff00) >> 8;
                        int b2 = (v & 0x00ff0000) >> 16;
                        int b3 = (v & 0xff000000) >> 24;

                      screen[ dst_off + 0 ] = palette[ b3 ];
                      screen[ dst_off + 1 ] = palette[ b2 ];
                      screen[ dst_off + 2 ] = palette[ b1 ];
                      screen[ dst_off + 3 ] = palette[ b0 ];
                }
        }
        NOPH_Graphics_drawRGB(graphics, (int)screen, 0, DISPLAY_X,
                              0, 0,
                              320, 200, 0);
        NOPH_GameCanvas_flushGraphics(canvas);
}
#endif

void C64Display::Update(void)
{
        int x, y;

        for (y = 0; y < 240; y++)
        {
                for (x = 0; x <= 320; x+=sizeof(int))
                {
                	int src_off = (y+20) * DISPLAY_X + (x+14);
                        int dst_off = (320-x) * 240 + y;
                        int *_bitmap = (int*)bitmap;
                        int v = _bitmap[ src_off / sizeof(int) ];
                        int b0 = (v & 0x000000ff);
                        int b1 = (v & 0x0000ff00) >> 8;
                        int b2 = (v & 0x00ff0000) >> 16;
                        int b3 = (v & 0xff000000) >> 24;

                        screen[ dst_off + 0 ]       = palette[ b0 ];
                        screen[ dst_off + 1 * 240 ] = palette[ b1 ];
                        screen[ dst_off + 2 * 240 ] = palette[ b2 ];
                        screen[ dst_off + 3 * 240 ] = palette[ b3 ];
                }
        }
        NOPH_Graphics_drawRGB(graphics, (int)screen, 0, 240,
                              0, 0,
                              240, 320, 0);
        NOPH_GameCanvas_flushGraphics(canvas);
}

/*
 *  Draw speedometer
 */

void C64Display::Speedometer(int speed)
{
}


/*
 *  Return pointer to bitmap data
 */

uint8 *C64Display::BitmapBase(void)
{
	return (uint8 *)bitmap;
}


/*
 *  Return number of bytes per row
 */

int C64Display::BitmapXMod(void)
{
	return DISPLAY_X;
}

void C64Display::FakeKeyPress(int kc, bool shift, uint8 *CIA_key_matrix, uint8 *CIA_rev_matrix, uint8 *joystick)
{
        // Clear matrices
        for (int i = 0; i < 8; i ++)
        {
                CIA_key_matrix[i] = 0xFF;
                CIA_rev_matrix[i] = 0xFF;
        }

        if (shift)
        {
                CIA_key_matrix[6] &= 0xef;
                CIA_rev_matrix[4] &= 0xbf;
        }

        if (kc != -1)
        {
                int c64_byte, c64_bit, shifted;
                c64_byte = kc >> 3;
                c64_bit = kc & 7;
                shifted = kc & 128;
                c64_byte &= 7;
                if (shifted)
                {
                        CIA_key_matrix[6] &= 0xef;
                        CIA_rev_matrix[4] &= 0xbf;
                }
                CIA_key_matrix[c64_byte] &= ~(1 << c64_bit);
                CIA_rev_matrix[c64_bit] &= ~(1 << c64_byte);
        }
}

typedef struct key_seq_item
{
  int kc;
  bool shift;
} key_seq_item_t;
#define MATRIX(a,b) (((a) << 3) | (b))

/*
 *  Poll the keyboard
 */
extern int autostart;
key_seq_item_t game_b_key = {MATRIX(7, 4), false}; /* Space */
extern void cibyl_main_menu(void);
void C64Display::PollKeyboard(uint8 *key_matrix, uint8 *rev_matrix, uint8 *joystick)
{
        int keyState = NOPH_GameCanvas_getKeyStates(canvas);
        int c64_key = 0;

        if (keyState & NOPH_GameCanvas_GAME_A_PRESSED)
        {
        	/* FIXME: Bring up the menu instead */
                printf("Main menu bring up\n");
        	cibyl_main_menu();
                printf("Done\n");
        }
        if (keyState & NOPH_GameCanvas_GAME_B_PRESSED)
        {
        	printf("Game b down\n");
        	this->FakeKeyPress(game_b_key.kc, game_b_key.shift, key_matrix,
        			rev_matrix, NULL);
        }
        else
        {
        	this->FakeKeyPress(-1, game_b_key.shift, rev_matrix,
        			key_matrix, NULL);
        }

        /* Key handling for joystick. For reference: This was the site of
         * a very long-standing nasty bug... Stupid Simon... */
        if (keyState & NOPH_GameCanvas_FIRE_PRESSED)
                *joystick &= ~0x10;
        else
                *joystick |= 0x10;

        /* Assume non-rotated */
        int kc_left  = 0x04;
        int kc_right = 0x08;
        int kc_up    = 0x02;
        int kc_down  = 0x01;

        if (ROTATED)
        {
                kc_left = 0x01;
        	kc_right = 0x02;
        	kc_up = 0x08;
        	kc_down = 0x04;
        }

        if (keyState & NOPH_GameCanvas_LEFT_PRESSED)
                *joystick &= ~kc_left;
        else
                *joystick |= kc_left;
        if (keyState & NOPH_GameCanvas_RIGHT_PRESSED)
                *joystick &= ~kc_right;
        else
                *joystick |= kc_right;
        if (keyState & NOPH_GameCanvas_DOWN_PRESSED)
                *joystick &= ~kc_down;
        else
                *joystick |= kc_down;
        if (keyState & NOPH_GameCanvas_UP_PRESSED)
                *joystick &= ~kc_up;
        else
                *joystick |= kc_up;
}


/*
 *  Check if NumLock is down (for switching the joystick keyboard emulation)
 */

bool C64Display::NumLock(void)
{
	return num_locked;
}


/*
 *  Allocate C64 colors
 */

void C64Display::InitColors(uint8 *colors)
{
	for (int i=0; i<16; i++) {
		int r = (int)palette_red[i];
		int g = (int)palette_green[i];
		int b = (int)palette_blue[i];
                palette[i] = (0xff << 24) | ((r) << 16) | ((g) << 8) | (b);
	}

	for (int i=0; i<256; i++)
		colors[i] = i & 0x0f;
}


/*
 *  Show a requester (error message)
 */

long int ShowRequester(char *a,char *b,char *)
{
	printf("%s: %s\n", a, b);
	return 1;
}
