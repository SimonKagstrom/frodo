/*
 *  C64_Be.i - Put the pieces together, Be specific stuff
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include <KernelKit.h>
#include <device/Joystick.h>

#undef PROFILING


/*
 *  Constructor, system-dependent things
 */

void C64::c64_ctor1(void)
{
	joy[0] = new BJoystick();
	joy[1] = new BJoystick();
}

void C64::c64_ctor2(void)
{
	// Initialize joystick variables
	joy_minx = joy_miny = 32767;
	joy_maxx = joy_maxy = 0;

	// Initialize semaphores (initially acquired)
	pause_sem = create_sem(0, "Frodo Pause Semaphore");
	sound_sync_sem = create_sem(0, "Frodo Sound Sync Semaphore");

	// Preset speedometer start time
	start_time = system_time();
}


/*
 *  Destructor, system-dependent things
 */

void C64::c64_dtor(void)
{
	delete_sem(pause_sem);
	delete_sem(sound_sync_sem);

	delete joy[0];
	delete joy[1];
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

	// Start the CPU thread
	the_thread = spawn_thread(thread_invoc, "Frodo 6510", B_URGENT_DISPLAY_PRIORITY, this);
	thread_running = true;
	quit_thyself = false;
	have_a_break = false;
	resume_thread(the_thread);
}


/*
 *  Stop main emulation thread
 */

void C64::Quit(void)
{
	long ret;

	// Ask the thread to quit itself if it is running
	if (thread_running) {
		if (have_a_break)
			Resume();
		quit_thyself = true;
		wait_for_thread(the_thread, &ret);
		thread_running = false;
	}
}


/*
 *  Pause main emulation thread
 */

void C64::Pause(void)
{
	// Ask the thread to pause and wait for acknowledge
	if (thread_running && !have_a_break) {
		have_a_break = true;
		acquire_sem(pause_sem);
		TheSID->PauseSound();
	}
}


/*
 *  Resume main emulation thread
 */

void C64::Resume(void)
{
	if (thread_running && have_a_break) {
		have_a_break = false;
		release_sem(pause_sem);
		TheSID->ResumeSound();
	}
}


/*
 *  Vertical blank: Poll keyboard and joysticks, update window
 */

void C64::VBlank(bool draw_frame)
{
	bigtime_t elapsed_time;
	long speed_index;

	// To avoid deadlocks on quitting
	if (quit_thyself) return;

	// Pause requested?
	if (have_a_break) {
		release_sem(pause_sem);	// Acknowledge pause
		acquire_sem(pause_sem);	// Wait for resume
	}

	// Poll keyboard
	TheDisplay->PollKeyboard(TheCIA1->KeyMatrix, TheCIA1->RevMatrix, &joykey);

	// Poll joysticks
	TheCIA1->Joystick1 = poll_joystick(0);
	TheCIA1->Joystick2 = poll_joystick(1);

	if (ThePrefs.JoystickSwap) {
		uint8 tmp = TheCIA1->Joystick1;
		TheCIA1->Joystick1 = TheCIA1->Joystick2;
		TheCIA1->Joystick2 = tmp;
	}

	// Joystick keyboard emulation
	if (TheDisplay->NumLock())
		TheCIA1->Joystick1 &= joykey;
	else
		TheCIA1->Joystick2 &= joykey;

	// Count TOD clocks
	TheCIA1->CountTOD();
	TheCIA2->CountTOD();

	// Update window if needed
	if (draw_frame) {
		TheDisplay->Update();

		// Calculate time between VBlanks, display speedometer
		elapsed_time = system_time() - start_time;
		speed_index = 20000 * 100 * ThePrefs.SkipFrames / (elapsed_time + 1);

		// Limit speed to 100% if desired (20ms/frame)
		// If the SID emulation is on and no frames are skipped, synchronize to the SID
		if (ThePrefs.LimitSpeed && speed_index > 100) {
			if (ThePrefs.SIDType == SIDTYPE_DIGITAL && ThePrefs.SkipFrames == 1) {
				long l;
				get_sem_count(sound_sync_sem, &l);
				if (l > 0)	// Avoid C64 lagging behind
					acquire_sem_etc(sound_sync_sem, l+1, 0, 0);
				else
					acquire_sem(sound_sync_sem);
			} else
				snooze(ThePrefs.SkipFrames * 20000 - elapsed_time);
			speed_index = 100;
		}

		start_time = system_time();

		TheDisplay->Speedometer(speed_index);
	}
}


/*
 *  Called by SID after playing 1/50 sec of sound
 */

void C64::SoundSync(void)
{
	release_sem(sound_sync_sem);
}


/*
 *  Open/close joystick drivers given old and new state of
 *  joystick preferences
 */

void C64::open_close_joysticks(bool oldjoy1, bool oldjoy2, bool newjoy1, bool newjoy2)
{
	if (oldjoy1 != newjoy1) {
		joy_minx = joy_miny = 32767;	// Reset calibration
		joy_maxx = joy_maxy = 0;
		if (newjoy1)
			joy[0]->Open("joystick2");
		else
			joy[0]->Close();
	}

	if (oldjoy2 != newjoy2) {
		joy_minx = joy_miny = 32767;	// Reset calibration
		joy_maxx = joy_maxy = 0;
		if (newjoy2)
			joy[1]->Open("joystick1");
		else
			joy[1]->Close();
	}
}


/*
 *  Poll joystick port, return CIA mask
 */

uint8 C64::poll_joystick(int port)
{
	uint8 j = 0xff;

	if (joy[port]->Update() != B_ERROR) {
		if (joy[port]->horizontal > joy_maxx)
			joy_maxx = joy[port]->horizontal;
		if (joy[port]->horizontal < joy_minx)
			joy_minx = joy[port]->horizontal;
		if (joy[port]->vertical > joy_maxy)
			joy_maxy = joy[port]->vertical;
		if (joy[port]->vertical < joy_miny)
			joy_miny = joy[port]->vertical;

		if (!joy[port]->button1)
			j &= 0xef;							// Button

		if (joy_maxx-joy_minx < 100 || joy_maxy-joy_miny < 100)
			return j;

		if (joy[port]->horizontal < (joy_minx + (joy_maxx-joy_minx)/3))
			j &= 0xf7;							// Right
		else if (joy[port]->horizontal > (joy_minx + 2*(joy_maxx-joy_minx)/3))
			j &= 0xfb;							// Left

		if (joy[port]->vertical < (joy_miny + (joy_maxy-joy_miny)/3))
			j &= 0xfd;							// Down
		else if (joy[port]->vertical > (joy_miny + 2*(joy_maxy-joy_miny)/3))
			j &= 0xfe;							// Up
	}
	return j;
}


/*
 * The emulation's main loop
 */

long C64::thread_invoc(void *obj)
{
	((C64 *)obj)->thread_func();
	return 0;
}

void C64::thread_func(void)
{
#ifdef PROFILING
static bigtime_t vic_time_acc = 0;
static bigtime_t sid_time_acc = 0;
static bigtime_t cia_time_acc = 0;
static bigtime_t cpu_time_acc = 0;
#endif
#ifdef FRODO_SC
	while (!quit_thyself) {
		// The order of calls is important here
		if (TheVIC->EmulateCycle())
			TheSID->EmulateLine();
		TheCIA1->CheckIRQs();
		TheCIA2->CheckIRQs();
		TheCIA1->EmulateCycle();
		TheCIA2->EmulateCycle();
		TheCPU->EmulateCycle();

		if (ThePrefs.Emul1541Proc) {
			TheCPU1541->CountVIATimers(1);
			if (!TheCPU1541->Idle)
				TheCPU1541->EmulateCycle();
		}
		CycleCounter++;
#else
	while (!quit_thyself) {
		// The order of calls is important here
#ifdef PROFILING
bigtime_t start_time = system_time();
#endif
		int cycles = TheVIC->EmulateLine();
#ifdef PROFILING
bigtime_t vic_time = system_time();
#endif
		TheSID->EmulateLine();
#ifdef PROFILING
bigtime_t sid_time = system_time();
#endif
#if !PRECISE_CIA_CYCLES
		TheCIA1->EmulateLine(ThePrefs.CIACycles);
		TheCIA2->EmulateLine(ThePrefs.CIACycles);
#endif
#ifdef PROFILING
bigtime_t cia_time = system_time();
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
#ifdef PROFILING
bigtime_t cpu_time = system_time();
vic_time_acc += vic_time - start_time;
sid_time_acc += sid_time - vic_time;
cia_time_acc += cia_time - sid_time;
cpu_time_acc += cpu_time - cia_time;
#endif

#endif
	}

#ifdef PROFILING
bigtime_t total_time = vic_time_acc + sid_time_acc + cia_time_acc + cpu_time_acc;
printf("VIC: %Ld\n", vic_time_acc * 100 / total_time);
printf("SID: %Ld\n", sid_time_acc * 100 / total_time);
printf("CIA: %Ld\n", cia_time_acc * 100 / total_time);
printf("CPU: %Ld\n", cpu_time_acc * 100 / total_time);
#endif
}
