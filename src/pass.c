#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>

#define MAXPW 128

typedef struct pw {
	char*  password;
	size_t len;
} pw_s;

pw_s* getpasswd() {
	pw_s *p = malloc(sizeof(pw_s));
  p->len = 0;

  struct termios old_t;
  struct termios new_t;

  if (tcgetattr(0, &old_t)) {
    return p;
  }

  memcpy(&new_t, &old_t, sizeof(struct termios));

  new_t.c_cc[VMIN]    = 1;
  new_t.c_cc[VTIME] = 0;
  new_t.c_lflag    &= ~(ICANON | ECHO);


  if (tcsetattr(0, TCSANOW, &new_t)) {
    return p;
  }

  char c;

  p->password = malloc(1 + (sizeof(char) * MAXPW));
  while ((c = fgetc(stdin)) != '\n' && c != EOF && p->len < MAXPW) {
    if(c != 127){ // delete
      p->password[p->len++] = c;
    } else if(p->len > 0) {
      p->password[--p->len] = 0;
    }
  }

  if(tcsetattr(0, TCSANOW, &old_t)) {
    return p;
  }
  
  if(p->len >= MAXPW){
    return p;
  }

  p->password[p->len] = 0;

  return p;
}

void freepwd(pw_s* p) {
  free(p);
}
