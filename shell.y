/**************************PART 1*****************************/
/*Token list*/
%debug
%token <string_val> WORD
%token NOTOKEN GREAT NEWLINE LESS APPEND PIPE AMPERSAND RD RA
%union  { char   *string_val; }


/* Insert header */
%{
//#define yylex yylex
#include <stdio.h>
#include <string.h>
#include "command.h"
void yyerror(const char * s);
int yylex();
%}

/**************************PART 2*****************************/
%%
goal:
        commands
        ;

commands: 
        command
        | commands command
        ;

command:
        commands_pipe iomodifier_list background_opt NEWLINE 
        {
          	//printf("   Yacc: Execute command\n");
            	Command::_currentCommand.execute();
        }
        | NEWLINE { Command::_currentCommand.prompt(); }
        | error NEWLINE { yyerrok; }
        ;

commands_pipe:
		commands_pipe PIPE command_and_args
    	| command_and_args
    	;

command_and_args:
        command_word arg_list
        {
            Command::_currentCommand.
            insertSimpleCommand( Command::_currentSimpleCommand );
        }
        ;

arg_list:
        arg_list argument
        | /* can be empty */
        ;

argument:
	WORD
        {
        	//printf("   Yacc: insert argument \"%s\"\n", $1);
            Command::_currentSimpleCommand->insertArgument($1);
        }
        ;

command_word:
        WORD {
          	//printf("   Yacc: insert command \"%s\"\n", $1);
            Command::_currentSimpleCommand = new SimpleCommand();
            Command::_currentSimpleCommand->insertArgument($1);
        }
        ;

iomodifier_list:
       iomodifier_list iomodifier_opt
       | /* can be empty */
       ;

iomodifier_opt:
        GREAT WORD
        {
		//printf("   Yacc: insert output \"%s\"\n", $2);
           	Command::_currentCommand._outFile = strdup($2);
		    Command::_currentCommand._numOfOutFile++;
        }
        |
        APPEND WORD
        {
          	/*" >>  "*/
          	//printf("   Yacc: append output \"%s\"\n", $2);
           	Command::_currentCommand._outFile = strdup($2);
		    Command::_currentCommand._append = 1;
		    Command::_currentCommand._numOfOutFile++;
        }
        |
        RD WORD
        {
          	/*" >& "*/
          	//printf("   Yacc: append stdout & stderr to \"%s\"\n", $2);
            Command::_currentCommand._outFile = strdup($2);
            Command::_currentCommand._errFile = strdup($2);
		    Command::_currentCommand._numOfOutFile++;
	    	Command::_currentCommand._numOfErrFile++;
        }
        |
        RA WORD
        {
          	/*" >>& "*/
          	//printf("   Yacc: append stdout & stderr to \"%s\"\n", $2);
            Command::_currentCommand._outFile = strdup($2);
           	Command::_currentCommand._errFile = strdup($2);
	    	Command::_currentCommand._append = 1;
	    	Command::_currentCommand._numOfOutFile++;
	    	Command::_currentCommand._numOfErrFile++;
        }
        |
        LESS WORD
    	{
          	//printf("   Yacc: insert input \"%s\"\n", $2);
		    Command::_currentCommand._inputFile = strdup($2);
	    	Command::_currentCommand._numOfInFile++;
        }
        ;

background_opt:
        AMPERSAND
    	{
          	//printf("   Yacc: run in background YES\n");
           	Command::_currentCommand._background = 1;
        }
        | /* can be empty */
        ;

%%

/**************************PART 3*****************************/
void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
	{
		yyparse();
	}
#endif
