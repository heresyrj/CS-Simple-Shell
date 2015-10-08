
/*
 *
   1>filename
      # Redirect stdout to file "filename."
   1>>filename
      # Redirect and append stdout to file "filename."
   2>filename
      # Redirect stderr to file "filename."
   2>>filename
      # Redirect and append stderr to file "filename."
   &>filename
      # Redirect both stdout and stderr to file "filename."
      # This operator is now functional, as of Bash 4, final release.

   M>N
     # "M" is a file descriptor, which defaults to 1, if not explicitly set.
     # "N" is a filename.
     # File descriptor "M" is redirect to file "N."
   M>&N
     # "M" is a file descriptor, which defaults to 1, if not set.
     # "N" is another file descriptor.
 *
 */

%{

#include <string.h>
#include "y.tab.h"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

%}

%%

\n 	    {
		return NEWLINE;
	    }

[ \t] 	{
		/* Discard spaces and tabs */
     	}
">>&"   { //append stdout and stderr to a file
        return RA;
        }
">&"    { //redirect stdout and stderr to file
        return RD;
        }
">>"    {
        return APPEND;
        }
">" 	{
		return GREAT;
	    }
"<"     {
        return LESS;
        }
"|"     {
        return PIPE;
        }
"&"     {
        return AMPERSAND;
        }


[^ \t\n]+ {
		/* Assume that file names have only alpha chars */
        /* "yytext": get the output of the pattern match   
           "yylval": refer to union struct in .y file   */
		yylval.string_val = strdup(yytext);
		return WORD;
	    }


