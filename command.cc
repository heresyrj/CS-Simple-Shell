#include <stdio.h>
#include <stdlib.h>
#include <cstdlib>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <regex.h>
#include <string.h>
#include <signal.h>

#include "command.h"

SimpleCommand::SimpleCommand()
{
	// Creat available space for 5 arguments
	_numberOfAvailableArguments = 5;
	_numberOfArguments = 0;
	_arguments = (char **) malloc( _numberOfAvailableArguments * sizeof( char * ) );
}

void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numberOfAvailableArguments == _numberOfArguments  + 1 ) {
		// Double the available space
		_numberOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				  _numberOfAvailableArguments * sizeof( char * ) );
	}

	_arguments[ _numberOfArguments ] = argument;

	// Add NULL argument at the end
	_arguments[ _numberOfArguments + 1] = NULL;

	_numberOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numberOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
	_numOfOutFile = 0;
	_numOfInFile = 0;
	_numOfErrFile = 0;
}

void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) {
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
			 _numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}

	_simpleCommands[ _numberOfSimpleCommands ] = simpleCommand;
	_numberOfSimpleCommands++;
}

void
Command:: clear()
{
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numberOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}

		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inputFile ) {
		free( _inputFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
	_numOfOutFile = 0;
	_numOfInFile = 0;
	_numOfErrFile = 0;
}

void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");

	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numberOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inputFile?_inputFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );

}

void
Command::execute()
{
	/*PART 1*/
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0 ) {
		clear();
		prompt();
		return;
	}
	//check if the modifier for the input and output files are legit
	int in_out_ops_error = (_numOfInFile > 1)|| (_numOfOutFile > 1) || (_numOfErrFile > 1);
	//printf("in_out_ops_error: %d\n", in_out_ops_error);
    if (in_out_ops_error) {
		printf("Ambiguous output redirect\n");
		clear();
		prompt();
		return;
	}

	// Print contents of Command data structure
	// print(); ---> for step1 of the project


	/*PART 2*/
	//save the fd for defaults
	int defaultIn = dup(0);
	int defaultOut = dup(1);
	int defaultErr = dup(2);
	//declare in/out/err files
	int in = 0;
	int out = 0;
	int err = 0;
	int retOfFork;

	//set up the Input for the first command
	if(_inputFile) {
		in = open(_inputFile, O_RDONLY, 0664);
		if(in < 0)
		{
			perror("Open Input File");
			exit(1);
		}
	} else {
		in = dup(defaultIn);
	}

	//set up errfile redirection handler
    //only the error that caused by the last command in the pipeline will
    //be rediereted to the new file.
    //all others use defualt stderr

 	//check if _errFile is specified for the only and first command
    if (_errFile){
        if (_append) {
 	        err = open(_errFile, O_WRONLY|O_CREAT|O_APPEND, 0664);
 	       if (err < 0) {
 		       perror("Error_Append");
 		       exit(1);
	        }
   	    } else {
 		     err = open(_errFile, O_WRONLY|O_CREAT|O_TRUNC, 0664);
 			 if (err < 0) {
 			      perror("Error_Trunc");
 			      exit(1);
 		      }
 		 }
 	} else {
        err = dup(defaultErr);
    }
	/*PART 3*/
	//handle command pipes by iterate through the simple commands
	for(int i = 0; i < _numberOfSimpleCommands; i++)
	{
		dup2(in, 0);
        dup2(err, 2);
        close(in);
        close(err);

        //set output for this particular command
		//case 1: this is the LAST command
		if( i == _numberOfSimpleCommands - 1) {
			//check if _outputFile is specified
			if(_outFile != 0) {
				//case 1: append to file
				if (_append) {
				    out = open(_outFile, O_CREAT|O_WRONLY|O_APPEND, 0664);
                }
				//case 2: clear old and start from new
				else {
				    out = open(_outFile, O_CREAT|O_WRONLY|O_TRUNC, 0664);
                }
			} else {
				out = dup(defaultOut);
			}

            //check if _errFile is specified
            if (_errFile){
 		        if (_append) {
 			        err = open(_errFile, O_WRONLY|O_CREAT|O_APPEND, 0664);
 			        if (err < 0) {
 				        perror("Error_Append");
 				        exit(1);
 			        }
 	    	    } else {
 			        err = open(_errFile, O_WRONLY|O_CREAT|O_TRUNC, 0664);
 			        if (err < 0) {
 				        perror("Error_Trunc");
 				        exit(1);
 			        }
 		        }
 	        }
        } else {//case 2: NOT LAST command. use pipe to communicate

			int pipeFds[2];
			pipe(pipeFds);
		    out = pipeFds[1];//For this command to write to
			in = pipeFds[0];//For the next command to read from
		}

		//redirect the output&err for this command
        dup2(out, 1);
        close(out);


		//finish I/O setup, prepare to execute
		retOfFork = fork ();
		if(retOfFork == 0) {//in the child
			execvp(_simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments);
			perror("execvp");
			_exit(1);
		}
	}

	/*PART 4*/
	//restore the fd table
	dup2(defaultIn, 0);
 	dup2(defaultOut, 1);
 	dup2(defaultErr, 2);

	close(defaultIn);
 	close(defaultOut);
 	close(defaultErr);

	/*PART 5*/
	//chech if required to run in the backgroud
	if(!_background) {
		waitpid(retOfFork, NULL, 0);
	}


	//PART 4
	// Clear to prepare for next command
	clear();

	// Print new prompt
	prompt();
}

// Shell implementation

void
Command::prompt()
{
	if (isatty(0))
    {
		printf("myshell>");
		fflush(stdout);
	}

}

Command Command::_currentCommand;/*Object created*/
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);
extern int yydebug;

int main()
{
    Command::_currentCommand.prompt();
    yyparse();
    Command::_currentCommand.clear();

}

