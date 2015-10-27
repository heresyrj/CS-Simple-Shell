/**************************PART 1*****************************/
/*Token list*/
%token <string_val> EXIT WORD 
%token NOTOKEN GREAT NEWLINE LESS APPEND PIPE AMPERSAND RD RA 
%union {
  char *string_val;
}

    /* Insert header */
%{
//#define yylex yylex
#include <stdio.h>
#include <string.h>
#include <string.h>
#include <stdlib.h>
#include <regex.h>
#include <stdio.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <signal.h>
#include "command.h"
void yyerror(const char *s);
int yylex();
void expandWildCardIfNecessary(char *arg);
void expandWildCard(char *prefix, char *suffix);
%}

/**************************PART 2*****************************/
%% 

goal : commands;

commands : command | commands command;

command : commands_pipe iomodifier_list background_opt NEWLINE {
  // printf("   Yacc: Execute command\n");
  Command::_currentCommand.execute();
}
| NEWLINE { Command::_currentCommand.prompt(); }
| error NEWLINE { yyerrok; };

commands_pipe : commands_pipe PIPE command_and_args | command_and_args;

command_and_args : command_word arg_list {
  Command::_currentCommand.insertSimpleCommand(Command::_currentSimpleCommand);
};

arg_list : arg_list argument | /* can be empty */
    ;

argument : WORD { expandWildCardIfNecessary($1); };

command_word : WORD {
  // printf("   Yacc: insert command \"%s\"\n", $1);
  Command::_currentSimpleCommand = new SimpleCommand();
  Command::_currentSimpleCommand->insertArgument($1);
};

iomodifier_list : iomodifier_list iomodifier_opt | /* can be empty */
    ;

iomodifier_opt : GREAT WORD {
  // printf("   Yacc: insert output \"%s\"\n", $2);
  Command::_currentCommand._outFile = strdup($2);
  Command::_currentCommand._numOfOutFile++;
}
| APPEND WORD {
  /*" >>  "*/
  // printf("   Yacc: append output \"%s\"\n", $2);
  Command::_currentCommand._outFile = strdup($2);
  Command::_currentCommand._append = 1;
  Command::_currentCommand._numOfOutFile++;
}
| RD WORD {
  /*" >& "*/
  // printf("   Yacc: append stdout & stderr to \"%s\"\n", $2);
  Command::_currentCommand._outFile = strdup($2);
  Command::_currentCommand._errFile = strdup($2);
  Command::_currentCommand._numOfOutFile++;
  Command::_currentCommand._numOfErrFile++;
}
| RA WORD {
  /*" >>& "*/
  // printf("   Yacc: append stdout & stderr to \"%s\"\n", $2);
  Command::_currentCommand._outFile = strdup($2);
  Command::_currentCommand._errFile = strdup($2);
  Command::_currentCommand._append = 1;
  Command::_currentCommand._numOfOutFile++;
  Command::_currentCommand._numOfErrFile++;
}
| LESS WORD {
  // printf("   Yacc: insert input \"%s\"\n", $2);
  Command::_currentCommand._inputFile = strdup($2);
  Command::_currentCommand._numOfInFile++;
};

background_opt : AMPERSAND {
  // printf("   Yacc: run in background YES\n");
  Command::_currentCommand._background = 1;
}
| /* can be empty */
    ;

%%

/**************************PART 3*****************************/
char **array;
int nEntries = 0;
int maxEntries = 20;

void expandWildCardIfNecessary(char *arg) {
  if (strchr(arg, '*') == NULL && strchr(arg, '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument(arg);
  } else {
    expandWildCard(NULL, arg);
  }
}

void expandWildCard(char *prefix, char *suffix)

{
  if (suffix[0] == 0) {
    if (nEntries == 0) {
      array = (char **)malloc(sizeof(char *) * maxEntries);
    }

    if (nEntries == maxEntries) {
      maxEntries *= 2;
      array = (char **)realloc(array, sizeof(char *) * maxEntries);
    }

    array[nEntries] = strdup(prefix);

    nEntries++;

    return;
  }

  char *s = strchr(suffix, '/');
  char component[1024] = "";

  if (s != NULL) {
    int length = s - suffix;

    if (length == 0)
      strcpy(component, "/");

    else
      strncpy(component, suffix, length);

    suffix = s + 1;
  }

  else {
    strcpy(component, suffix);

    suffix = suffix + strlen(suffix);
  }

  char newPrefix[1024] = "";

  if (strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
    if (prefix == NULL) 
      sprintf(newPrefix, "%s", component);
    else if (!strcmp(prefix, "/"))
      sprintf(newPrefix, "%s%s", prefix, component);
    else 
      sprintf(newPrefix, "%s/%s", prefix, component);

    expandWildCard(newPrefix, suffix);
    return;
  }

  else {
    int first = 0;
    int isHidden = 0;

    char * reg = (char*)malloc(2*strlen(component)+10); 
    char * a = component;
    char * r = reg;
    *r = '^'; r++;

    while (*a) {
      if (*a == '*') { *r = '.'; r++; *r = '*';}

      else if (*a == '.') {
        *r = '\\';
        r++;
        *r = '.';
        if (first == 0) isHidden = 1;
      }

      else if (*a == '?')
        *r = '.';
      else
        *r = *a;
      a++;
      r++;
      first++;
    }
    *r = '$'; r++; *r = 0;

    regex_t t;

    int result = regcomp(&t, reg, REG_NOSUB);

    if (result != 0) {
      perror("compile");
      return;
    }

    else {
      char * dr;

      if (prefix == NULL)
        dr = ".";
      else
        dr = prefix;

      DIR *dir = opendir(dr);

      if (dir == NULL) {
        return;
      }

      struct dirent *ent;

      while ((ent = readdir(dir)) != NULL) {
        regmatch_t m;

        result = regexec(&t, ent->d_name, 1, &m, 0);

        if (result == 0) {
          if (ent->d_name[0] == '.') {
            if (isHidden) {
              if (prefix == NULL)
                sprintf(newPrefix, "%s", ent->d_name);
              else if (!strcmp(prefix, "/"))
                sprintf(newPrefix, "%s%s", prefix, ent->d_name);
              else
                sprintf(newPrefix, "%s/%s", prefix, ent->d_name);

              expandWildCard(newPrefix, suffix);
            }

          }
          else {
            if (prefix == NULL)
              sprintf(newPrefix, "%s", ent->d_name);
            else if (!strcmp(prefix, "/"))
              sprintf(newPrefix, "%s%s", prefix, ent->d_name);
            else
              sprintf(newPrefix, "%s/%s", prefix, ent->d_name);

            expandWildCard(newPrefix, suffix);
          }
        }
      }
    }

    free(reg);
  }

  if (suffix[0] == 0) {
    char *temp;
    int iter = nEntries;
    int done;
    int i;

    do {
      done = 1;
      for (i = 0; i < iter - 1; i++) {
        if (strcmp(array[i], array[i + 1]) > 0) {
          temp = array[i];
          array[i] = array[i + 1];
          array[i + 1] = temp;
          done = 0;
        }
      }
      iter--;
    } while (!done);

    for (i = 0; i < nEntries; i++)
      Command::_currentSimpleCommand->insertArgument(array[i]);

    free(array);
    nEntries = 0;
    maxEntries = 20;
  }
}

void yyerror(const char *s) { fprintf(stderr, "%s", s); }

#if 0
main()
    {
        yyparse();
    }
#endif