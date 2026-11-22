/* Echo library for probing Chez's foreign integer types. */
#include <stddef.h>
#include <stdint.h>
size_t echo_size(size_t x) { return x; }
unsigned long long echo_ull(unsigned long long x) { return x; }
size_t size_max(void) { return SIZE_MAX; }
int sizeof_ull(void) { return (int) sizeof(unsigned long long); }
int sizeof_size(void) { return (int) sizeof(size_t); }
