/*
 * CS354: Operating Systems.
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define MAX_BUFFER_LINE 2048

// Buffer where line is stored
int line_length;
int cursor_position;
char line_buffer[MAX_BUFFER_LINE];

// Simple history array
// This history does not change.
// Yours have to be updated.
int history_index = 0;
char **history;
int history_length = 0;
int HIST_MAX = 15;

void read_line_print_usage() {
  char *usage =
      "\n"
      " ctrl-?       Print usage\n"
      " Backspace    Deletes last character\n"
      " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/*
 * Input a line with some basic editing.
 */
char *read_line() {
  // Set terminal in raw mode
  tty_raw_mode();
  // Initialize the parameters
  line_length = 0;
  cursor_position = 0;
  if (history == NULL) {  // whiout the check, up-arrow will give seg fault
    history = (char **)malloc(HIST_MAX * sizeof(char *));
  }

  // Read one line until enter is typed
  while (1) {
    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);

    // for all printable character.
    if (ch >= 32 && ch <= 126) {
      // Do echo
      write(1, &ch, 1);

      // If max number of character reached return.
      if (line_length == MAX_BUFFER_LINE - 2) break;

      // if in the middle of what typed
      if (cursor_position != line_length) {
        char temp;
        int i;

        line_length++;
        //shift the content to the right of cursor
        for (i = line_length; i > cursor_position; i--) {
          line_buffer[i] = line_buffer[i - 1];
        }
        //let the content to be written in the buffer be stored
        line_buffer[cursor_position] = ch;

        //print the chars to the right of cursor
        for (i = cursor_position + 1; i < line_length; i++) {
          ch = line_buffer[i];
          write(1, &ch, 1);
        }
        //put the cursor back to the right position.
        ch = 8;
        for (i = cursor_position + 1; i < line_length; i++) {
          write(1, &ch, 1);
        }

      } else {
        // at the end, just add char to buffer.
        line_buffer[line_length] = ch;
        line_length++;
      }

      cursor_position++;

    } else if (ch == 10) {
      // <Enter> was typed. Return line
      // Print newline
      write(1, &ch, 1);
      if (history_length == HIST_MAX) {
        HIST_MAX *= 2;
        history = (char **)realloc(history, HIST_MAX * sizeof(char *));
      }
      line_buffer[line_length] = 0;
      if (line_buffer[0] != 0) {
        history[history_length] = strdup(line_buffer);
        history_length++;
      }

      break;

    } else if (ch == 1) {
      // CTRL-A : Move to beginning of line
      int i;
      for (i = cursor_position; i > 0; i--) {
        ch = 8;
        write(1, &ch, 1);
        cursor_position--;
      }
    } else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0] = 0;
      break;
    } else if ((ch == 8 || ch == 127) && line_length != 0) {
      // <backspace> was typed. Remove previous character read.
      // Go back one character
      ch = 8;
      write(1, &ch, 1);
      // Write a space to erase the last character read
      ch = ' ';
      write(1, &ch, 1);
      // Go back one character
      ch = 8;
      write(1, &ch, 1);
      // Remove one character from buffer
      line_length--;
      cursor_position--;
    } else if (ch == 27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1;
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);

      // left arrow
      if (ch1 == 91 && ch2 == 68) {
        if (cursor_position > 0) {
          ch = 8;
          write(1, &ch, 1);
          cursor_position--;
        }
      }

      // right arrow
      if (ch1 == 91 && ch2 == 67) {
        if (cursor_position < line_length) {
          // char ch = line_buffer[cursor_position];
          // write(1, &ch, 1);
          write(1, &ch, 1);
          write(1, &ch1, 1);
          write(1, &ch2, 1);
          cursor_position++;
        }
      }

      // Up arrow. Print next line in history.
      if (ch1 == 91 && ch2 == 65 && history_length > 0) {
        // Erase old line
        // Print backspaces
        int i = 0;
        for (i = 0; i < line_length; i++) {
          ch = 8;
          write(1, &ch, 1);
        }

        // Print spaces on top
        for (i = 0; i < line_length; i++) {
          ch = ' ';
          write(1, &ch, 1);
        }

        // Print backspaces
        for (i = 0; i < line_length; i++) {
          ch = 8;
          write(1, &ch, 1);
        }

        // Copy line from history
        strcpy(line_buffer, history[history_index]);
        line_length = strlen(line_buffer);
        history_index = (history_index + 1) % history_length;

        // echo line
        write(1, line_buffer, line_length);
        cursor_position = line_length;
      }

      // down arrow, similar to UP
      if (ch1 == 91 && ch2 == 66) {
        // down arrow. Print next line in history.

        // Erase old line
        // Print backspaces
        int i = 0;
        for (i = line_length - cursor_position; i < line_length; i++) {
          ch = 8;
          write(1, &ch, 1);
        }

        // Print spaces on top
        for (i = 0; i < line_length; i++) {
          ch = ' ';
          write(1, &ch, 1);
        }

        // Print backspaces
        for (i = 0; i < line_length; i++) {
          ch = 8;
          write(1, &ch, 1);
        }

        if (history_index > 0) {
          // Copy line from history
          strcpy(line_buffer, history[history_index]);
          line_length = strlen(line_buffer);
          history_index = (history_index - 1) % history_length;

          // echo line
          write(1, line_buffer, line_length);
          cursor_position = line_length;
        } else {
          // Copy line from history
          strcpy(line_buffer, "");
          line_length = strlen(line_buffer);

          // echo line
          write(1, line_buffer, line_length);
          cursor_position = line_length;
        }
      }
    }
  }

  // Add eol and null char at the end of string
  line_buffer[line_length] = 10;
  line_length++;
  line_buffer[line_length] = 0;

  return line_buffer;
}
