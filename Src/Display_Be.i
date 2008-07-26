/*
 *  Display_Be.i - C64 graphics display, emulator window handling,
 *                 Be specific stuff
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *  GameKit stuff by Tinic Urou
 */

#include <AppKit.h>
#include <InterfaceKit.h>
#include <GameKit.h>
#include <string.h>

#include "C64.h"
#include "main.h"


// Window thread messages
const uint32 MSG_REDRAW = 1;


// C64 display and window frame
const BRect DisplayFrame = BRect(0, 0, DISPLAY_X-1, DISPLAY_Y-1);
const BRect WindowFrame = BRect(0, 0, DISPLAY_X-1, DISPLAY_Y-1 + 16);


// Background color
const rgb_color fill_gray = {208, 208, 208, 0};
const rgb_color shine_gray = {232, 232, 232, 0};
const rgb_color shadow_gray = {152, 152, 152, 0};


/*
  C64 keyboard matrix:

    Bit 7   6   5   4   3   2   1   0
  0    CUD  F5  F3  F1  F7 CLR RET DEL
  1    SHL  E   S   Z   4   A   W   3
  2     X   T   F   C   6   D   R   5
  3     V   U   H   B   8   G   Y   7
  4     N   O   K   M   0   J   I   9
  5     ,   @   :   .   -   L   P   +
  6     /   ^   =  SHR HOM  ;   *   £
  7    R/S  Q   C= SPC  2  CTL  <-  1
*/


/*
  Tables for key translation
  Bit 0..2: row/column in C64 keyboard matrix
  Bit 3   : implicit shift
  Bit 5   : joystick emulation (bit 0..4: mask)
*/

const int key_byte[128] = {
	  -1,   7,   0,8+0,   0,8+0,  0, 8+0,
	   0, 8+0,  -1, -1,  -1, -1, -1,  -1,

	   7,   7,   7,  7,   1,  1,  2,   2,
	   3,   3,   4,  4,   5,  5,  0, 8+0,

	   6,   6,  -1, -1,  -1, -1, -1,   7,
	   1,   1,   2,  2,   3,  3,  4,   4,

	   5,   5,   6,  6,   0,  6,  6,0x25,
	0x21,0x29,  -1,  1,   1,  1,  2,   2,

	   3,   3,   4,  4,   5,  5,  6,   0,
	0x24,0x30,0x28,  1,   1,  2,  2,   3,

	   3,   4,   4,  5,   5,  6,  6, 8+0,
	0x26,0x22,0x2a,  0,   7, -1,  7,  -1,

	   7, 8+0,   0,  0,0x30, -1,  7,   7,
	  -1,  -1,  -1, -1,  -1, -1, -1,  -1,

	  -1,  -1,  -1, -1,  -1, -1, -1,  -1,
	  -1,  -1,  -1, -1,  -1, -1, -1,  -1
};

const int key_bit[128] = {
	-1,  7,  4,  4,  5,  5,  6,  6,
	 3,  3, -1, -1, -1, -1, -1, -1,

	 7,  1,  0,  3,  0,  3,  0,  3,
	 0,  3,  0,  3,  0,  3,  0,  0,

	 3,  0, -1, -1, -1, -1, -1,  6,
	 1,  6,  1,  6,  1,  6,  1,  6,

	 1,  6,  1,  6,  0,  0,  5, -1,
	-1, -1, -1,  7,  2,  5,  2,  5,

	 2,  5,  2,  5,  2,  5,  2,  1,
	-1, -1, -1,  7,  4,  7,  4,  7,

	 4,  7,  4,  7,  4,  7,  4,  7,
	-1, -1, -1,  1,  2, -1,  4, -1,

	 5,  2,  7,  2, -1, -1,  5,  5,
	-1, -1, -1, -1, -1, -1, -1, -1,

	-1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1
};


/*
 *  A simple view class for blitting a bitmap on the screen
 */

class BitmapView : public BView {
public:
	BitmapView(BRect frame, BBitmap *bitmap);
	virtual void Draw(BRect update);
	virtual void KeyDown(const char *bytes, int32 numBytes);
	void ChangeBitmap(BBitmap *bitmap);

private:
	BBitmap *the_bitmap;
};


/*
 *  Class for the main C64 display window
 */

class SpeedoView;
class LEDView;

class C64Window : public BWindow {
public:
	C64Window();

	virtual bool QuitRequested(void);
	virtual void MessageReceived(BMessage *msg);

	BBitmap *TheBitmap[2];
	SpeedoView *Speedometer;
	LEDView *LED[4];

private:
	BitmapView *main_view;
};


/*
 *  Class for the main C64 display using the GameKit
 */

class C64Screen : public BWindowScreen {
public:
	C64Screen(C64Display *display) : BWindowScreen("Frodo", B_8_BIT_640x480, &error), the_display(display)
	{
		Lock();
		BitmapView *main_view = new BitmapView(Bounds(), NULL);
		AddChild(main_view);
		main_view->MakeFocus();
		Connected = false;
		Unlock();
	}

	virtual void ScreenConnected(bool active);
	virtual void DispatchMessage(BMessage *msg, BHandler *handler);
	void DrawLED(int i, int state);
	void DrawSpeedometer(void);
	void FillRect(int x1, int y1, int x2, int y2, int color);

	bool Connected;			// Flag: screen connected
	int Speed;
	char SpeedoStr[16];		// Speedometer value converted to a string

private:
	C64Display *the_display;
	status_t error;
};


/*
 *  Class for speedometer
 */

class SpeedoView : public BView {
public:
	SpeedoView(BRect frame);
	virtual void Draw(BRect update);
	virtual void Pulse(void);
	void SetValue(int percent);

private:
	char speedostr[16];		// Speedometer value converted to a string
	BRect bounds;
};


/*
 *  Class for drive LED
 */

class LEDView : public BView {
public:
	LEDView(BRect frame, const char *label);
	virtual void Draw(BRect update);
	virtual void Pulse(void);
	void DrawLED(void);
	void SetState(int state);

private:
	int current_state;
	const char *the_label;
	BRect bounds;
};


/*
 *  Display constructor: Create window/screen
 */

C64Display::C64Display(C64 *the_c64) : TheC64(the_c64)
{
	// LEDs off
	for (int i=0; i<4; i++)
		led_state[i] = old_led_state[i] = LED_OFF;

	// Open window/screen
	draw_bitmap = 1;
	if (ThePrefs.DisplayType == DISPTYPE_SCREEN) {
		using_screen = true;
		the_screen = new C64Screen(this);
		the_screen->Show();
		while (!the_screen->Connected)
			snooze(20000);
	} else {
		using_screen = false;
		the_window = new C64Window();
		the_window->Show();
	}

	// Prepare key_info buffer
	get_key_info(&old_key_info);
}


/*
 *  Display destructor
 */

C64Display::~C64Display()
{
	if (using_screen) {
		the_screen->Lock();
		the_screen->Quit();
	} else {
		the_window->Lock();
		the_window->Quit();
	}
}


/*
 *  Prefs may have changed
 */

void C64Display::NewPrefs(Prefs *prefs)
{
	if (prefs->DisplayType == DISPTYPE_SCREEN) {
		if (!using_screen) {
			// Switch to full screen display
			using_screen = true;
			the_window->Lock();
			the_window->Quit();
			the_screen = new C64Screen(this);
			the_screen->Show();
			while (!the_screen->Connected)
				snooze(20000);
		}
	} else {
		if (using_screen) {
			// Switch to window display
			using_screen = false;
			the_screen->Lock();
			the_screen->Quit();
			the_window = new C64Window();
			the_window->Show();
		}
	}
}


/*
 *  Redraw bitmap (let the window thread do it)
 */

void C64Display::Update(void)
{
	if (using_screen) {

		// Update LEDs/speedometer
		for (int i=0; i<4; i++)
			the_screen->DrawLED(i, led_state[i]);
		the_screen->DrawSpeedometer();

	} else {

		// Update C64 display
		BMessage msg(MSG_REDRAW);
		msg.AddInt32("bitmap", draw_bitmap);
		the_window->PostMessage(&msg);
		draw_bitmap ^= 1;

		// Update LEDs
		for (int i=0; i<4; i++)
			if (led_state[i] != old_led_state[i]) {
				the_window->LED[i]->SetState(led_state[i]);
				old_led_state[i] = led_state[i];
			}
	}
}


/*
 *  Set value displayed by the speedometer
 */

void C64Display::Speedometer(int speed)
{
	if (using_screen) {
		the_screen->Speed = speed;
		sprintf(the_screen->SpeedoStr, "%3d%%", speed);
	} else
		the_window->Speedometer->SetValue(speed);
}


/*
 *  Return pointer to bitmap data
 */

uint8 *C64Display::BitmapBase(void)
{
	if (using_screen)
		return (uint8 *)the_screen->CardInfo()->frame_buffer;
	else
		return (uint8 *)the_window->TheBitmap[draw_bitmap]->Bits();
}


/*
 *  Return number of bytes per row
 */

int C64Display::BitmapXMod(void)
{
	if (using_screen)
		return the_screen->CardInfo()->bytes_per_row;
	else
		return the_window->TheBitmap[draw_bitmap]->BytesPerRow();
}


/*
 *  Poll the keyboard
 */

void C64Display::PollKeyboard(uint8 *key_matrix, uint8 *rev_matrix, uint8 *joystick)
{
	key_info the_key_info;
	int be_code, be_byte, be_bit, c64_byte, c64_bit;
	bool shifted;

	// Window must be active, command key must be up
	if (using_screen) {
		if (!the_screen->Connected)
			return;
	} else
		if (!the_window->IsActive())
			return;
	if (!(modifiers() & B_COMMAND_KEY)) {

		// Read the state of all keys
		get_key_info(&the_key_info);

		// Did anything change at all?
		if (!memcmp(&old_key_info, &the_key_info, sizeof(key_info)))
			return;

		// Loop to convert BeOS keymap to C64 keymap
		for (be_code=0; be_code<0x68; be_code++) {
			be_byte = be_code >> 3;
			be_bit = 1 << (~be_code & 7);

			// Key state changed?
			if ((the_key_info.key_states[be_byte] & be_bit)
			     != (old_key_info.key_states[be_byte] & be_bit)) {

				c64_byte = key_byte[be_code];
				c64_bit = key_bit[be_code];
				if (c64_byte != -1) {
					if (!(c64_byte & 0x20)) {

						// Normal keys
						shifted = c64_byte & 8;
						c64_byte &= 7;
						if (the_key_info.key_states[be_byte] & be_bit) {

							// Key pressed
							if (shifted) {
								key_matrix[6] &= 0xef;
								rev_matrix[4] &= 0xbf;
							}
							key_matrix[c64_byte] &= ~(1 << c64_bit);
							rev_matrix[c64_bit] &= ~(1 << c64_byte);
						} else {

							// Key released
							if (shifted) {
								key_matrix[6] |= 0x10;
								rev_matrix[4] |= 0x40;
							}
							key_matrix[c64_byte] |= (1 << c64_bit);
							rev_matrix[c64_bit] |= (1 << c64_byte);
						}
					} else {

						// Joystick emulation
						c64_byte &= 0x1f;
						if (the_key_info.key_states[be_byte] & be_bit)
							*joystick &= ~c64_byte;
						else
							*joystick |= c64_byte;
					}
				}
			}
		}

		old_key_info = the_key_info;
	}
}


/*
 *  Check if NumLock is down (for switching the joystick keyboard emulation)
 */

bool C64Display::NumLock(void)
{
	return modifiers() & B_NUM_LOCK;
}


/*
 *  Allocate C64 colors
 */

void C64Display::InitColors(uint8 *colors)
{
	BScreen scr(using_screen ? (BWindow *)the_screen : the_window);
	for (int i=0; i<256; i++)
		colors[i] = scr.IndexForColor(palette_red[i & 0x0f], palette_green[i & 0x0f], palette_blue[i & 0x0f]);
}


/*
 *  Pause display (GameKit only)
 */

void C64Display::Pause(void)
{
	if (using_screen)
		the_screen->Hide();
}


/*
 *  Resume display (GameKit only)
 */

void C64Display::Resume(void)
{
	if (using_screen)
		the_screen->Show();
}


/*
 *  Window constructor
 */

C64Window::C64Window() : BWindow(WindowFrame, "Frodo", B_TITLED_WINDOW, B_NOT_RESIZABLE | B_NOT_ZOOMABLE)
{
	// Move window to right position
	Lock();
	MoveTo(80, 60);

	// Set up menus
	BMenuBar *bar = new BMenuBar(Bounds(), "");
	BMenu *menu = new BMenu("Frodo");
	menu->AddItem(new BMenuItem("About Frodo" B_UTF8_ELLIPSIS, new BMessage(B_ABOUT_REQUESTED)));
	menu->AddItem(new BSeparatorItem);
	menu->AddItem(new BMenuItem("Preferences" B_UTF8_ELLIPSIS, new BMessage(MSG_PREFS), 'P'));
	menu->AddItem(new BSeparatorItem);
	menu->AddItem(new BMenuItem("Reset C64", new BMessage(MSG_RESET)));
	menu->AddItem(new BMenuItem("Insert next disk", new BMessage(MSG_NEXTDISK), 'D'));
	menu->AddItem(new BMenuItem("SAM" B_UTF8_ELLIPSIS, new BMessage(MSG_SAM), 'M'));
	menu->AddItem(new BSeparatorItem);
	menu->AddItem(new BMenuItem("Load snapshot" B_UTF8_ELLIPSIS, new BMessage(MSG_OPEN_SNAPSHOT), 'O'));
	menu->AddItem(new BMenuItem("Save snapshot" B_UTF8_ELLIPSIS, new BMessage(MSG_SAVE_SNAPSHOT), 'S'));
	menu->AddItem(new BSeparatorItem);
	menu->AddItem(new BMenuItem("Quit Frodo", new BMessage(B_QUIT_REQUESTED), 'Q'));
	menu->SetTargetForItems(be_app);
	bar->AddItem(menu);
	AddChild(bar);
	SetKeyMenuBar(bar);
	int mbar_height = bar->Frame().bottom + 1;

	// Resize window to fit menu bar
	ResizeBy(0, mbar_height);

	// Allocate bitmaps
	TheBitmap[0] = new BBitmap(DisplayFrame, B_COLOR_8_BIT);
	TheBitmap[1] = new BBitmap(DisplayFrame, B_COLOR_8_BIT);

	// Create top view
	BRect b = Bounds();
	BView *top = new BView(BRect(0, mbar_height, b.right, b.bottom), "top", B_FOLLOW_NONE, 0);
	AddChild(top);

	// Create bitmap view
	main_view = new BitmapView(DisplayFrame, TheBitmap[0]);
	top->AddChild(main_view);
	main_view->MakeFocus();

	// Create speedometer
	Speedometer = new SpeedoView(BRect(0, DISPLAY_Y, DISPLAY_X/5-1, DISPLAY_Y+15));
	top->AddChild(Speedometer);

	// Create drive LEDs
	LED[0] = new LEDView(BRect(DISPLAY_X/5, DISPLAY_Y, DISPLAY_X*2/5-1, DISPLAY_Y+15), "Drive 8");
	top->AddChild(LED[0]);
	LED[1] = new LEDView(BRect(DISPLAY_X*2/5, DISPLAY_Y, DISPLAY_X*3/5-1, DISPLAY_Y+15), "Drive 9");
	top->AddChild(LED[1]);
	LED[2] = new LEDView(BRect(DISPLAY_X*3/5, DISPLAY_Y, DISPLAY_X*4/5-1, DISPLAY_Y+15), "Drive 10");
	top->AddChild(LED[2]);
	LED[3] = new LEDView(BRect(DISPLAY_X*4/5, DISPLAY_Y, DISPLAY_X-1, DISPLAY_Y+15), "Drive 11");
	top->AddChild(LED[3]);

	// Set pulse rate to 0.4 seconds for blinking drive LEDs
	SetPulseRate(400000);
	Unlock();
}


/*
 *  Closing the window quits Frodo
 */

bool C64Window::QuitRequested(void)
{
	be_app->PostMessage(B_QUIT_REQUESTED);
	return false;
}


/*
 *  Handles redraw messages
 */

void C64Window::MessageReceived(BMessage *msg)
{
	BMessage *msg2;

	switch (msg->what) {
		case MSG_REDRAW:  // Redraw bitmap
			MessageQueue()->Lock();
			while ((msg2 = MessageQueue()->FindMessage(MSG_REDRAW, 0)) != NULL)
				MessageQueue()->RemoveMessage(msg2);
			MessageQueue()->Unlock();
			main_view->ChangeBitmap(TheBitmap[msg->FindInt32("bitmap")]);
			Lock();
			main_view->Draw(DisplayFrame);
			Unlock();
			break;

		default:
			BWindow::MessageReceived(msg);
	}
}


/*
 *  Workspace activated/deactivated
 */

void C64Screen::ScreenConnected(bool active)
{
	if (active) {
		FillRect(0, 0, 639, 479, 0);	// Clear screen
		the_display->TheC64->Resume();
		Connected = true;
	} else {
		the_display->TheC64->Pause();
		Connected = false;
	}
	BWindowScreen::ScreenConnected(active);
}


/*
 *  Simulate menu commands
 */

void C64Screen::DispatchMessage(BMessage *msg, BHandler *handler)
{
	switch (msg->what) {
		case B_KEY_DOWN: {
			uint32 mods = msg->FindInt32("modifiers");
			if (mods & B_COMMAND_KEY) {
				uint32 key = msg->FindInt32("raw_char");
				switch (key) {
					case 'p':
						be_app->PostMessage(MSG_PREFS);
						break;
					case 'd':
						be_app->PostMessage(MSG_NEXTDISK);
						break;
					case 'm':
						be_app->PostMessage(MSG_SAM);
						break;
				}
			}
			BWindowScreen::DispatchMessage(msg, handler);
			break;
		}

		default:
			BWindowScreen::DispatchMessage(msg, handler);
	}
}


/*
 *  Draw drive LEDs
 */

void C64Screen::DrawLED(int i, int state)
{
	switch (state) {
		case LED_ON:
			FillRect(10+i*20, DISPLAY_Y-20, 20+i*20, DISPLAY_Y-12, 54);
			break;
		case LED_ERROR_ON:
			FillRect(10+i*20, DISPLAY_Y-20, 20+i*20, DISPLAY_Y-12, 44);
			break;
	}
}


/*
 *  Draw speedometer
 */

static const int8 Digits[11][8] = {	// Digit images
	{0x3c, 0x66, 0x6e, 0x76, 0x66, 0x66, 0x3c, 0x00},
	{0x18, 0x18, 0x38, 0x18, 0x18, 0x18, 0x7e, 0x00},
	{0x3c, 0x66, 0x06, 0x0c, 0x30, 0x60, 0x7e, 0x00},
	{0x3c, 0x66, 0x06, 0x1c, 0x06, 0x66, 0x3c, 0x00},
	{0x06, 0x0e, 0x1e, 0x66, 0x7f, 0x06, 0x06, 0x00},
	{0x7e, 0x60, 0x7c, 0x06, 0x06, 0x66, 0x3c, 0x00},
	{0x3c, 0x66, 0x60, 0x7c, 0x66, 0x66, 0x3c, 0x00},
	{0x7e, 0x66, 0x0c, 0x18, 0x18, 0x18, 0x18, 0x00},
	{0x3c, 0x66, 0x66, 0x3c, 0x66, 0x66, 0x3c, 0x00},
	{0x3c, 0x66, 0x66, 0x3e, 0x06, 0x66, 0x3c, 0x00},
	{0x62, 0x66, 0x0c, 0x18, 0x30, 0x66, 0x46, 0x00},
};

void C64Screen::DrawSpeedometer()
{
	// Don't display speedometer if we're running at about 100%
	if (Speed >= 99 && Speed <= 101)
		return;

	char *s = SpeedoStr;
	char c;
	long xmod = CardInfo()->bytes_per_row;
	uint8 *p = (uint8 *)CardInfo()->frame_buffer + DISPLAY_X - 8*8 + (DISPLAY_Y-20) * xmod;
	while (c = *s++) {
		if (c == ' ')
			continue;
		if (c == '%')
			c = 10;
		else
			c -= '0';
		uint8 *q = p;
		for (int y=0; y<8; y++) {
			uint8 data = Digits[c][y];
			for (int x=0; x<8; x++) {
				if (data & (1 << (7-x)))
					q[x] = 255;
				else
					q[x] = 0;
			}
			q += xmod;
		}
		p += 8;
	}
}


/*
 *  Fill rectangle
 */

void C64Screen::FillRect(int x1, int y1, int x2, int y2, int color)
{
	long xmod = CardInfo()->bytes_per_row;
	uint8 *p = (uint8 *)CardInfo()->frame_buffer + y1 * xmod + x1;
	int n = x2 - x1 + 1;
	for(int y=y1; y<=y2; y++) {
		memset_nc(p, color, n);
		p += xmod;
	}
}


/*
 *  Bitmap view constructor
 */

BitmapView::BitmapView(BRect frame, BBitmap *bitmap) : BView(frame, "", B_FOLLOW_NONE, B_WILL_DRAW)
{
	ChangeBitmap(bitmap);
}


/*
 *  Blit the bitmap
 */

void BitmapView::Draw(BRect update)
{
	if (the_bitmap != NULL)
		DrawBitmapAsync(the_bitmap, update, update);
}


/*
 *  Receive special key-down events (main C64 keyboard handling is done in PollKeyboard)
 */

void BitmapView::KeyDown(const char *bytes, int32 numBytes)
{
	if (bytes[0] == B_FUNCTION_KEY || bytes[0] == '+' || bytes[0] == '-' || bytes[0] == '*' || bytes[0] == '/') {
		BMessage *msg = Window()->CurrentMessage();
		long key;
		if (msg->FindInt32("key", &key) == B_NO_ERROR) {
			switch (key) {

				case B_F11_KEY:	// F11: NMI (Restore)
					be_app->PostMessage(MSG_NMI);
					break;

				case B_F12_KEY:	// F12: Reset
					be_app->PostMessage(MSG_RESET);
					break;

				case 0x3a:		// '+' on keypad: Increase SkipFrames
					ThePrefs.SkipFrames++;
					break;

				case 0x25:		// '-' on keypad: Decrease SkipFrames
					if (ThePrefs.SkipFrames > 1)
						ThePrefs.SkipFrames--;
					break;

				case 0x24:		// '*' on keypad: Toggle speed limiter
					ThePrefs.LimitSpeed = !ThePrefs.LimitSpeed;
					break;

				case 0x23:		// '/' on keypad: Toggle processor-level 1541 emulation
					be_app->PostMessage(MSG_TOGGLE_1541);
					break;
			}
		}
	}
}


/*
 *  Change view bitmap
 */

void BitmapView::ChangeBitmap(BBitmap *bitmap)
{
	the_bitmap = bitmap;
}


/*
 *  Speedometer constructor
 */

SpeedoView::SpeedoView(BRect frame) : BView(frame, "", B_FOLLOW_NONE, B_WILL_DRAW | B_PULSE_NEEDED)
{
	speedostr[0] = 0;
	bounds = Bounds();
	SetViewColor(fill_gray);
	SetFont(be_plain_font);
}


/*
 *  Draw speedometer
 */

void SpeedoView::Draw(BRect update)
{
	// Draw bevelled border
	SetHighColor(shine_gray);
	StrokeLine(BPoint(0, bounds.bottom), BPoint(0, 0));
	StrokeLine(BPoint(bounds.right, 0));
	SetHighColor(shadow_gray);
	StrokeLine(BPoint(bounds.right, bounds.bottom), BPoint(bounds.right, 1));

	// Draw text
	SetHighColor(0, 0, 0);
	DrawString(speedostr, BPoint(24, 12));
}


/*
 *  Update speedometer at regular intervals
 */

void SpeedoView::Pulse(void)
{
	Invalidate(BRect(1, 1, bounds.right-1, 15));
}


/*
 *  Set new speedometer value
 */

void SpeedoView::SetValue(int speed)
{
	sprintf(speedostr, "%d%%", speed);
}


/*
 *  LED view constructor
 */

LEDView::LEDView(BRect frame, const char *label) : BView(frame, "", B_FOLLOW_NONE, B_WILL_DRAW | B_PULSE_NEEDED)
{
	current_state = 0;
	the_label = label;
	bounds = Bounds();
	SetViewColor(fill_gray);
	SetFont(be_plain_font);
}


/*
 *  Draw drive LED
 */

void LEDView::Draw(BRect update)
{
	// Draw bevelled border
	SetHighColor(shine_gray);
	StrokeLine(BPoint(0, bounds.bottom), BPoint(0, 0));
	StrokeLine(BPoint(bounds.right, 0));
	SetHighColor(shadow_gray);
	StrokeLine(BPoint(bounds.right, bounds.bottom), BPoint(bounds.right, 1));

	// Draw label
	SetHighColor(0, 0, 0);
	SetLowColor(fill_gray);
	DrawString(the_label, BPoint(8, 12));

	// Draw LED
	SetHighColor(shadow_gray);
	StrokeLine(BPoint(bounds.right-24, 12), BPoint(bounds.right-24, 4));
	StrokeLine(BPoint(bounds.right-8, 4));
	SetHighColor(shine_gray);
	StrokeLine(BPoint(bounds.right-23, 12), BPoint(bounds.right-8, 12));
	StrokeLine(BPoint(bounds.right-8, 5));
	DrawLED();
}


/*
 *  Redraw just the LED
 */

void LEDView::DrawLED(void)
{
	Window()->Lock();
	switch (current_state) {
		case LED_OFF:
		case LED_ERROR_OFF:
			SetHighColor(32, 32, 32);
			break;
		case LED_ON:
			SetHighColor(0, 240, 0);
			break;
		case LED_ERROR_ON:
			SetHighColor(240, 0, 0);
			break;
	}
	FillRect(BRect(bounds.right-23, 5, bounds.right-9, 11));
	Window()->Unlock();
}


/*
 *  Set LED state
 */

void LEDView::SetState(int state)
{
	if (state != current_state) {
		current_state = state;
		DrawLED();
	}
}


/*
 *  Toggle red error LED
 */

void LEDView::Pulse(void)
{
	switch (current_state) {
		case LED_ERROR_ON:
			current_state = LED_ERROR_OFF;
			DrawLED();
			break;
		case LED_ERROR_OFF:
			current_state = LED_ERROR_ON;
			DrawLED();
			break;
	}
}


/*
 *  Show a requester
 */

long ShowRequester(char *str, char *button1, char *button2)
{
	BAlert *the_alert;
	
	the_alert = new BAlert("", str, button1, button2, NULL, B_WIDTH_AS_USUAL, B_STOP_ALERT);
	return the_alert->Go();
}
