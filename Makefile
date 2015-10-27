
#Use GNU compiler
cc = gcc -g
CC = g++ -g

LEX=lex
YACC=yacc

all: shell cat_grep ctrl-c regular git-commit

lex.yy.o: shell.l
	$(LEX) shell.l
	$(CC) -c lex.yy.c

y.tab.o: shell.y
	$(YACC) -d -v shell.y
	$(CC) -c y.tab.c

command.o: command.cc
	$(CC) -c -g command.cc

shell: y.tab.o lex.yy.o command.o read-line.o tty-raw-mode.o
	$(CC) -o shell lex.yy.o y.tab.o command.o read-line.o tty-raw-mode.o -lfl

cat_grep: cat_grep.cc
	$(CC) -o cat_grep cat_grep.cc

ctrl-c: ctrl-c.cc
	$(CC) -o ctrl-c ctrl-c.cc

regular: regular.cc
	$(CC) -o regular regular.cc

tty-raw-mode.o: tty-raw-mode.c
	gcc -c tty-raw-mode.c

read-line.o: read-line.c
	gcc -c read-line.c

git-commit:
	git add *.h *.cc *.l *.y >> .local.git.out
	git commit -a -m 'Commit Shell' >> .local.git.out | echo


clean:
	rm -f lex.yy.c y.tab.c  y.tab.h shell ctrl-c regular cat_grep *.o

