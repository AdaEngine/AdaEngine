#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define UNICODE
#define _UNICODE
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <windns.h>
#include <stdlib.h>
#include <stdio.h>
#include "CWindowsPlayer.h"

static INIT_ONCE initialized = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK initialize(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    (void)once; (void)parameter; (void)context;
    WSADATA data;
    return WSAStartup(MAKEWORD(2,2), &data) == 0;
}
static int ready(void) { return InitOnceExecuteOnce(&initialized, initialize, NULL, NULL); }
uintptr_t ada_player_connect(const char *host, uint16_t port) {
    if (!ready() || !host || !port) return UINTPTR_MAX;
    struct addrinfo hints = {0}, *addresses = NULL;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    char service[8]; snprintf(service, sizeof(service), "%u", port);
    if (getaddrinfo(host, service, &hints, &addresses)) return UINTPTR_MAX;
    SOCKET result = INVALID_SOCKET;
    for (struct addrinfo *address = addresses; address; address = address->ai_next) {
        SOCKET connection = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (connection == INVALID_SOCKET) continue;
        u_long nonblocking = 1;
        ioctlsocket(connection, FIONBIO, &nonblocking);
        int connected = connect(connection, address->ai_addr, (int)address->ai_addrlen);
        if (connected == 0 || WSAGetLastError() == WSAEWOULDBLOCK) {
            fd_set writable; FD_ZERO(&writable); FD_SET(connection, &writable);
            struct timeval timeout = {10, 0};
            if (connected == 0 || select(0, NULL, &writable, NULL, &timeout) > 0) {
                int error = 0, size = sizeof(error);
                if (!getsockopt(connection, SOL_SOCKET, SO_ERROR, (char *)&error, &size) && !error) {
                    nonblocking = 0; ioctlsocket(connection, FIONBIO, &nonblocking);
                    result = connection; break;
                }
            }
        }
        closesocket(connection);
    }
    freeaddrinfo(addresses);
    return (uintptr_t)result;
}
uintptr_t ada_player_listen(uint16_t *port) {
    if (!ready()) return UINTPTR_MAX;
    SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listener == INVALID_SOCKET) return UINTPTR_MAX;
    struct sockaddr_in address = {0}; address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY); address.sin_port = htons(*port);
    if (bind(listener, (const struct sockaddr *)&address, sizeof(address)) || listen(listener, 4)) {
        closesocket(listener); return UINTPTR_MAX;
    }
    int size = sizeof(address);
    getsockname(listener, (struct sockaddr *)&address, &size);
    *port = ntohs(address.sin_port);
    return (uintptr_t)listener;
}
uintptr_t ada_player_accept(uintptr_t listener) { return (uintptr_t)accept((SOCKET)listener, NULL, NULL); }
void ada_player_close(uintptr_t socket) {
    if (socket == UINTPTR_MAX) return;
    shutdown((SOCKET)socket, SD_BOTH); closesocket((SOCKET)socket);
}
int ada_player_write(uintptr_t socket, const void *data, size_t size) {
    const char *position = data;
    while (size) {
        int count = send((SOCKET)socket, position, (int)(size > 65536 ? 65536 : size), 0);
        if (count <= 0) return 0;
        position += count; size -= count;
    }
    return 1;
}
int ada_player_read(uintptr_t socket, void *data, size_t size) {
    char *position = data;
    while (size) {
        int count = recv((SOCKET)socket, position, (int)(size > 65536 ? 65536 : size), 0);
        if (count <= 0) return 0;
        position += count; size -= count;
    }
    return 1;
}

// Windows owns asynchronous DNS callbacks. Retain the request until the final
// cancellation callback; each outstanding resolve holds an additional reference.
typedef struct {
    volatile LONG references;
    volatile LONG stopped;
    uintptr_t context;
    ada_player_discovered callback;
    DNS_SERVICE_CANCEL cancel;
} Browser;
static void release_browser(Browser *browser) {
    if (InterlockedDecrement(&browser->references) == 0) free(browser);
}
typedef struct { Browser *browser; PWSTR name; } Resolve;
static void utf8(PCWSTR input, char *output, int size) {
    output[0] = 0;
    if (input) WideCharToMultiByte(CP_UTF8, 0, input, -1, output, size, NULL, NULL);
    output[size-1] = 0;
}
static void CALLBACK resolved(DWORD status, PVOID context, PDNS_SERVICE_INSTANCE instance) {
    Resolve *request = context;
    Browser *browser = request->browser;
    if (!status && instance && !InterlockedCompareExchange(&browser->stopped, 0, 0)) {
        char name[2048], host[2048];
        utf8(instance->pszInstanceName, name, sizeof(name));
        utf8(instance->pszHostName, host, sizeof(host));
        browser->callback(browser->context, name, host, instance->wPort);
    }
    if (instance) DnsServiceFreeInstance(instance);
    free(request->name); free(request); release_browser(browser);
}
static void CALLBACK browsed(DWORD status, PVOID context, PDNS_RECORD records) {
    Browser *browser = context;
    if (!status && !InterlockedCompareExchange(&browser->stopped, 0, 0)) {
        unsigned count = 0;
        for (PDNS_RECORD record = records; record && count++ < 256; record = record->pNext) {
            if (record->wType != DNS_TYPE_PTR || !record->Data.PTR.pNameHost) continue;
            Resolve *resolve = calloc(1, sizeof(Resolve));
            if (!resolve) continue;
            resolve->browser = browser; resolve->name = _wcsdup(record->Data.PTR.pNameHost);
            InterlockedIncrement(&browser->references);
            DNS_SERVICE_RESOLVE_REQUEST request = {0};
            request.Version = DNS_QUERY_REQUEST_VERSION1;
            request.QueryName = resolve->name;
            request.pResolveCompletionCallback = resolved; request.pQueryContext = resolve;
            DWORD result = DnsServiceResolve(&request, NULL);
            if (result != DNS_REQUEST_PENDING) {
                free(resolve->name); free(resolve); release_browser(browser);
            }
        }
    }
    if (records) DnsRecordListFree(records, DnsFreeRecordList);
    if (status == ERROR_CANCELLED) release_browser(browser);
}
void *ada_player_browse(uintptr_t context, ada_player_discovered callback) {
    Browser *browser = calloc(1, sizeof(Browser));
    if (!browser) return NULL;
    browser->references = 1; browser->context = context; browser->callback = callback;
    DNS_SERVICE_BROWSE_REQUEST request = {0};
    request.Version = DNS_QUERY_REQUEST_VERSION1;
    request.QueryName = L"_adaplayer._tcp.local";
    request.pBrowseCallback = browsed; request.pQueryContext = browser;
    DWORD result = DnsServiceBrowse(&request, &browser->cancel);
    if (result != DNS_REQUEST_PENDING) { free(browser); return NULL; }
    return browser;
}
void ada_player_stop_browse(void *context) {
    if (!context) return;
    Browser *browser = context;
    if (!InterlockedExchange(&browser->stopped, 1)) DnsServiceBrowseCancel(&browser->cancel);
}
#endif
