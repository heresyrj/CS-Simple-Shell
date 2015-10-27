
//
// Example of how to ignore ctrl-c
//

#include <stdio.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>

#include <termios.h>
#include <unistd.h>

void setup_term(void) {
    struct termios t;
    tcgetattr(0, &t);
    t.c_lflag &= ~ECHOCTL;
    tcsetattr(0, TCSANOW, &t);
}

extern "C" void disp( int sig )
{
	//fprintf( stderr, "\n      Ouch!\n");
	printf("\n");

}

int
main()
{
	setup_term();
	printf( "Type ctrl-c or \"exit\"\n");
	sigset( SIGINT, disp);
	for (;;) {
		
		char s[ 20 ];
		printf( "prompt>");
		fflush( stdout );
		gets( s );

		if ( !strcmp( s, "exit" ) ) {
			printf( "Bye!\n");
			exit( 1 );
		}
	}

	return 0;
}


