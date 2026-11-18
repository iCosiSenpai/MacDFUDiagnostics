#ifndef CHPM_BRIDGE_H
#define CHPM_BRIDGE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    HPM_ACTION_PROBE = 0,
    HPM_ACTION_DFU_AUTO = 1,       // Tries Apple Silicon (0x106) then falls back to Intel T2 (0x105 / 0x80020000)
    HPM_ACTION_DFU_SILICON = 2,    // Forces 0x106 (0x80010000)
    HPM_ACTION_DFU_T2 = 3,         // Forces 0x105 (0x80020000 - PMU Reset + DFU Hold)
    HPM_ACTION_REBOOT = 4,         // Normal reboot: 0x105 (0x80000000)
    HPM_ACTION_SERIAL = 5,         // SBU UART Serial Console: 0x01840306 + DVEn
    HPM_ACTION_DEBUGUSB = 6        // KIS Debug USB: 0x01824606
} HPMActionType;

typedef struct {
    int32_t rid;
    uint32_t port_number;
    uint32_t location_base;        // e.g. 0x01000000 from AppleUSBHostController
    bool is_dfu_capable;           // Declared in uart-hpm-rids or RID==0
    char location_name[64];        // From IORegistry port-location (if present)
    char io_path[256];
} HPMHostPortInfo;

typedef struct {
    uint16_t vendor_id;
    uint16_t product_id;
    uint16_t bcd_device;
    uint8_t device_class;
    uint8_t device_subclass;
    uint8_t device_protocol;
    uint32_t location_id;
    char product_name[128];
    char serial_number[256];
} HPMUSBDeviceInfo;

typedef struct {
    int32_t status_code;           // 0 = success, non-zero = error
    int32_t used_rid;
    bool connected;
    bool is_source;                // true = Source (DFP), false = Sink (UFP)
    bool used_t2_fallback;
    uint32_t vdm_reply_header;
    char hpm_status[16];           // e.g. "APP ", "DBMa"
    char host_platform[64];        // e.g. "J314sAP"
    char message[512];
} HPMExecutionResult;

/// Reads the host Mac's IOPlatformExpertDevice name (e.g., "J314sAP") and computes its 4-byte unlock key.
bool hpm_get_host_platform(char *out_name, size_t name_len, uint32_t *out_unlock_key);

/// Lists all AppleHPM USB-C port controllers on the host Mac (no root required).
size_t hpm_list_host_ports(HPMHostPortInfo *out_ports, size_t max_ports);

/// Lists all connected Apple (0x05ac) USB devices from IORegistry (no root required).
size_t hpm_list_apple_usb_devices(HPMUSBDeviceInfo *out_devs, size_t max_devs);

/// Executes an AppleHPM VDM command on the specified RID (pass target_rid = -1 for automatic RID selection).
/// Requires root privileges (geteuid() == 0) on an Apple Silicon host.
HPMExecutionResult hpm_execute_action(HPMActionType action, int32_t target_rid);

#ifdef __cplusplus
}
#endif

#endif /* CHPM_BRIDGE_H */
