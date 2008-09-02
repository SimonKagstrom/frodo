#include <stdint.h>

#define MATRIX(a,b) (((a) << 3) | (b))

#define SHIFT (1<<7)

static uint8_t char_to_kc[] =
{
	/* Some shifted stuff */
	['\"'] = MATRIX(7, 3) | SHIFT,

	/* CUD */
	/* F5 */
	/* F3 */
	/* F1 */
	/* F7 */
	['\n'] = MATRIX(0, 1),
	['\008'] = MATRIX(0, 0),

	['E'] = MATRIX(1, 6),
	['S'] = MATRIX(1, 5),
	['Z'] = MATRIX(1, 4),
	['4'] = MATRIX(1, 3),
	['A'] = MATRIX(1, 2),
	['W'] = MATRIX(1, 1),
	['3'] = MATRIX(1, 0),

	['X'] = MATRIX(2, 7),
	['T'] = MATRIX(2, 6),
	['F'] = MATRIX(2, 5),
	['C'] = MATRIX(2, 4),
	['6'] = MATRIX(2, 3),
	['D'] = MATRIX(2, 2),
	['R'] = MATRIX(2, 1),
	['5'] = MATRIX(2, 0),

	['V'] = MATRIX(3, 7),
	['U'] = MATRIX(3, 6),
	['H'] = MATRIX(3, 5),
	['B'] = MATRIX(3, 4),
	['8'] = MATRIX(3, 3),
	['G'] = MATRIX(3, 2),
	['Y'] = MATRIX(3, 1),
	['7'] = MATRIX(3, 0),

	['N'] = MATRIX(4, 7),
	['O'] = MATRIX(4, 6),
	['K'] = MATRIX(4, 5),
	['M'] = MATRIX(4, 4),
	['0'] = MATRIX(4, 3),
	['J'] = MATRIX(4, 2),
	['I'] = MATRIX(4, 1),
	['9'] = MATRIX(4, 0),

	[','] = MATRIX(5, 7),
	['@'] = MATRIX(5, 6),
	[':'] = MATRIX(5, 5),
	['.'] = MATRIX(5, 4),
	['-'] = MATRIX(5, 3),
	['L'] = MATRIX(5, 2),
	['P'] = MATRIX(5, 1),
	['+'] = MATRIX(5, 0),

	['/'] = MATRIX(6, 7),
	['^'] = MATRIX(6, 6),
	['='] = MATRIX(6, 5),
	/* SHR */
	/* HOM */
	[';'] = MATRIX(6, 2),
	['*'] = MATRIX(6, 1),
	/* ?? */

	/* R/S */
	['Q'] = MATRIX(7, 6),
	/* C= */
	[' '] = MATRIX(7, 4),
	['2'] = MATRIX(7, 3),
	/* CTL */
	/* <- */
	['1'] = MATRIX(7, 0),
};

int get_kc_from_char(char c_in, int *shifted)
{
	uint8_t c = char_to_kc[c_in];
	int out = c & (~SHIFT);

	*shifted = c & SHIFT;
	return out;
}
