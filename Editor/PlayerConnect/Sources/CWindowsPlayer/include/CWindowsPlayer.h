#pragma once
#include <stdint.h>
#include <stddef.h>
uintptr_t ada_player_connect(const char *host, uint16_t port);
uintptr_t ada_player_listen(uint16_t *port);
uintptr_t ada_player_accept(uintptr_t listener);
void ada_player_close(uintptr_t socket);
int ada_player_write(uintptr_t socket, const void *data, size_t size);
int ada_player_read(uintptr_t socket, void *data, size_t size);
typedef void (*ada_player_discovered)(uintptr_t context, const char *name, const char *host, uint16_t port);
void *ada_player_browse(uintptr_t context, ada_player_discovered callback);
void ada_player_stop_browse(void *browser);
