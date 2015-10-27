%{
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>

#include "y.tab.h"

static  void yyunput (int c,char *buf_ptr  );

    void myunputc(int c) 
    {
        unput(c);
    }

    extern "C" char * read_line();

    int mygetc(FILE * f) {
    static char *p;
    char ch;

    if (!isatty(0)) {
      // stdin is not a tty. Call real getc
      return getc(f);
    }

    // stdin is a tty. Call our read_line.
    if (p==NULL || *p == 0) {
        char * s = read_line();
        p = s;
    }

    ch = *p;
    p++;
    return ch;
}
#undef getc
#define getc(f) mygetc(f)
%}

%%
\n      {
        return NEWLINE;
        }

[ \t]   {/* Discard spaces and tabs */}

">>&"   { //append stdout and stderr to a file
        return RA;
        }
">&"    { //redirect stdout and stderr to file
        return RD;
        }
">>"    {
        return APPEND;
        }
">"     {
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

\"[^\n\"]*\" {
    /* quoted string */
            yylval.string_val = strdup(yytext+1);
            if (yylval.string_val[yyleng-2] == '"')
            yylval.string_val[yyleng-2] = '\0';
            return WORD;
}

\`[^\n\`]*\` {
        //backticks
        
        //strp off the backticks 
        int len = strlen(yytext);
        char * temp = (++yytext);
        temp = strchr(temp, '`');
        *temp = 0;

        int defaultIn = dup(0);
        int defaultOut = dup(1);

        int childPipe[2];
        int parentPipe[2];
        pipe(childPipe);
        pipe(parentPipe);

        write(childPipe[1], yytext, strlen(yytext));
        write(childPipe[1], "\n", strlen("\n"));
        write(childPipe[1], "exit\n", strlen("exit\n"));
            
        dup2(childPipe[0], 0);
        dup2(parentPipe[1], 1);
        close(childPipe[0]);
        close(parentPipe[1]);
        close(childPipe[1]);

        int ret = fork();
        if (ret == 0) {
            execvp("/proc/self/exe", NULL);
            perror("subshell");
            _exit(0);
        }
        if (ret > 0 && waitpid(ret, 0, 0)) {

            dup2(defaultIn, 0);
            dup2(defaultOut, 1);
            close(defaultIn);
            close(defaultOut);

            int max = 1024;
            char * outputBuffer = (char*)malloc(max);
            int i = 0;
            while (read(parentPipe[0], &outputBuffer[i], 1) != 0) {
                if (i == max) {
                    max *= 2;
                    outputBuffer = (char *)realloc(outputBuffer, max);
                }
                if(outputBuffer[i] == '\n') {
                    outputBuffer[i] = ' ';
                }
                i++;
            }
            close(parentPipe[0]);

            for(i = i - 1; i >=0 ; i--) {
                myunputc(outputBuffer[i]);
            }
            free(outputBuffer);
        }
        if (ret < 0) {
            perror("subshell fork err");
        }

}

[^ \t\n|><&]*\\[^ \t\n]*    {
        /* escape characters */
        char * buffer = (char*) malloc(1024);
        int i = 0; 
        int j = 0;
        int len = strlen(yytext);
        
        while (i < len) 
        {
            if(yytext[i] == 92)
            {
                if(yytext[i+1] == 92){
                    buffer[j] = yytext[i+1];
                    i++; 
                    j++;
                }
            }
            else {
                buffer[j] = yytext[i];
                j++;
            }
            i++;
        }
               
        yylval.string_val = strdup(buffer);
        return WORD;
       
    }

[^ \t\n|><&]+ {
        /* Assume that file names have only alpha chars */
        yylval.string_val = strdup(yytext);
        return WORD;
}
%%
