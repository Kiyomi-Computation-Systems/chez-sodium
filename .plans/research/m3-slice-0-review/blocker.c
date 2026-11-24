/* A stand-in for a long libsodium call: blocks on a FIFO until a writer opens it. */
#include <fcntl.h>
#include <unistd.h>

int block_on(const char *path) {
  char buf[64];
  ssize_t n;
  int fd = open(path, O_RDONLY); /* blocks on a FIFO until a writer opens it */
  if (fd < 0) return -1;
  while ((n = read(fd, buf, sizeof buf)) > 0) { }
  close(fd);
  return n < 0 ? -2 : 0;
}
