/*
	PLAYC.C -- asks for a file name and calls DOSSound to play it.
	Done with Borland Turbo C compiler using FP_SEG and FP_OFF.
*/

#include <stdio.h>
#include <dos.h>

union REGS regs;

main()
{
char buffer[512];

printf("\nPlease enter the wave file name: ");
scanf("%s",buffer);

/* DS does not need to be set here */
regs.x.ax = 0x0101;         /* load and play file in the background */
regs.x.dx = FP_OFF(&buffer);
int86(0x64, &regs, &regs);  /* call DOSSound */

} /* End of main */

