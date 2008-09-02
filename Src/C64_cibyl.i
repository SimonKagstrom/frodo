/*
 *  C64_x.i - Put the pieces together, X specific stuff
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *  Unix stuff by Bernd Schmidt/Lutz Vieweg
 */

#include "main.h"
#include <stdint.h>
#include <java/lang.h>

static uint64_t time_start;


/* From dreamcast port */
typedef struct key_seq_item
{
  int kc;
  bool shift;
} key_seq_item_t;

#define MATRIX(a,b) (((a) << 3) | (b))

/* */
static const char *auto_seq[4] =
{
	"\nLOAD \"*\",8,1\nRUN\n",
	"\nLOAD \"*\",9,1\nRUN\n",
	"\nLOAD \"*\",10,1\nRUN\n",
	"\nLOAD \"*\",11,1\nRUN\n",
};

/*
 *  Constructor, system-dependent things
 */

void C64::c64_ctor1(void)
{
}

void C64::c64_ctor2(void)
{
        time_start = NOPH_System_currentTimeMillis();
}


/*
 *  Destructor, system-dependent things
 */

void C64::c64_dtor(void)
{
}


/*
 *  Start main emulation thread
 */

void C64::Run(void)
{
	// Reset chips
	TheCPU->Reset();
	TheSID->Reset();
	TheCIA1->Reset();
	TheCIA2->Reset();
	TheCPU1541->Reset();

	// Patch kernal IEC routines
	orig_kernal_1d84 = Kernal[0x1d84];
	orig_kernal_1d85 = Kernal[0x1d85];
	PatchKernal(ThePrefs.FastReset, ThePrefs.Emul1541Proc);

	quit_thyself = false;
	thread_func();
}


/*
 *  Vertical blank: Poll keyboard and joysticks, update window
 */

int autostart = 0;
int autostart_type = 0;
int autostart_index = 0;
int autostart_keytime = 5;
void C64::VBlank(bool draw_frame)
{
        uint8 joy_state = 0xff;
	// Poll keyboard
	TheDisplay->PollKeyboard(TheCIA1->KeyMatrix, TheCIA1->RevMatrix, &joy_state);

        if (autostart == 1)
        {
		int shifted;
		int kc = get_kc_from_char(auto_seq[autostart_type][autostart_index], &shifted);

                TheDisplay->FakeKeyPress(kc, shifted, TheCIA1->KeyMatrix, TheCIA1->RevMatrix, &joy_state);

                autostart_keytime --;
                if (autostart_keytime == 0)
                {
                        autostart_keytime = 1;
                        autostart_index ++;

                        if (autostart_index == 18)
                        {
                                autostart = 0;
                                autostart_index = 0;
                                autostart_keytime = 5;
                        }
                }
        }

	if (ThePrefs.JoystickSwap) {
		uint8 tmp = TheCIA1->Joystick1;
		TheCIA1->Joystick1 = TheCIA1->Joystick2;
		TheCIA1->Joystick2 = tmp;
	}

	// Joystick keyboard emulation
        TheCIA1->Joystick2 = joy_state;

	// Count TOD clocks
	TheCIA1->CountTOD();
	TheCIA2->CountTOD();

	// Update window if needed
        static uint64_t lastFrame;
	if (draw_frame) {
                TheDisplay->Update();
	}
        // Limit speed to 100% if desired
        if (ThePrefs.LimitSpeed)
        {
                uint64_t now = NOPH_System_currentTimeMillis();

                while ((now - lastFrame) < 20) // 2cs per frame = 50fps (original speed)
                {
                        now = NOPH_System_currentTimeMillis();
                }
                lastFrame = now;
        }
}


/*
 *  Open/close joystick drivers given old and new state of
 *  joystick preferences
 */

void C64::open_close_joysticks(bool oldjoy1, bool oldjoy2, bool newjoy1, bool newjoy2)
{
}


/*
 *  Poll joystick port, return CIA mask
 */

uint8 C64::poll_joystick(int port)
{
        /* FIXME: Implement */
	return 0xff;
}


/*
 * The emulation's main loop
 */

void C64::thread_func(void)
{
	int linecnt = 0;

	while (!quit_thyself) {

		// The order of calls is important here
		int cycles = TheVIC->EmulateLine();
		TheSID->EmulateLine();
#if !PRECISE_CIA_CYCLES
		TheCIA1->EmulateLine(ThePrefs.CIACycles);
		TheCIA2->EmulateLine(ThePrefs.CIACycles);
#endif

		if (ThePrefs.Emul1541Proc) {
			int cycles_1541 = ThePrefs.FloppyCycles;
			TheCPU1541->CountVIATimers(cycles_1541);

			if (!TheCPU1541->Idle) {
				// 1541 processor active, alternately execute
				//  6502 and 6510 instructions until both have
				//  used up their cycles
				while (cycles >= 0 || cycles_1541 >= 0)
					if (cycles > cycles_1541)
						cycles -= TheCPU->EmulateLine(1);
					else
						cycles_1541 -= TheCPU1541->EmulateLine(1);
			} else
				TheCPU->EmulateLine(cycles);
		} else
			// 1541 processor disabled, only emulate 6510
			TheCPU->EmulateLine(cycles);
		linecnt++;
	}
}
