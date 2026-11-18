#include "CHPMBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// AppleHPMLib COM/IOCFPlugIn UUIDs (from AsahiLinux/macvdmtool & ThunderboltPatcher)
#define kAppleHPMLibType \
    CFUUIDGetConstantUUIDWithBytes(NULL, 0x12, 0xA1, 0xDC, 0xCF, 0xCF, 0x7A, 0x47, 0x75, \
                                   0xBE, 0xE5, 0x9C, 0x43, 0x19, 0xF4, 0xCD, 0x2B)

#define kAppleHPMLibInterface \
    CFUUIDGetConstantUUIDWithBytes(NULL, 0xC1, 0x3A, 0xCD, 0xD9, 0x20, 0x9E, 0x4B, 0x01, \
                                   0xB7, 0xBE, 0xE0, 0x5C, 0xD8, 0x83, 0xC7, 0xB1)

typedef struct AppleHPMLibStruct {
    IUNKNOWN_C_GUTS;
    uint16_t field_20;
    uint16_t field_22;
    IOReturn (*Read)(void *thisPointer, uint64_t chipAddr, uint8_t dataAddr,
                     void *buffer, uint64_t bufferLen, uint32_t flags, uint64_t *readLen);
    IOReturn (*Write)(void *thisPointer, uint64_t chipAddr, uint8_t dataAddr,
                      const void *buffer, uint64_t bufferLen, uint32_t flags);
    IOReturn (*Command)(void *thisPointer, uint64_t chipAddr, uint32_t cmd, uint32_t flags);
    IOReturn (*field_40)(void);
    IOReturn (*field_48)(void);
    IOReturn (*field_50)(void);
} AppleHPMLib;

static uint32_t fourcc_be(const char s[4]) {
    return ((uint32_t)(uint8_t)s[0] << 24) |
           ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8)  |
           ((uint32_t)(uint8_t)s[3]);
}

static bool cf_to_u32(CFTypeRef ref, uint32_t *out_val) {
    if (!ref) return false;
    CFTypeID tid = CFGetTypeID(ref);
    if (tid == CFNumberGetTypeID()) {
        int64_t val = 0;
        if (CFNumberGetValue((CFNumberRef)ref, kCFNumberSInt64Type, &val)) {
            *out_val = (uint32_t)val;
            return true;
        }
    } else if (tid == CFDataGetTypeID()) {
        CFIndex len = CFDataGetLength((CFDataRef)ref);
        const uint8_t *ptr = CFDataGetBytePtr((CFDataRef)ref);
        if (len >= 4 && ptr) {
            *out_val = (uint32_t)ptr[0] |
                       ((uint32_t)ptr[1] << 8) |
                       ((uint32_t)ptr[2] << 16) |
                       ((uint32_t)ptr[3] << 24);
            return true;
        }
    }
    return false;
}

static bool cf_to_string(CFTypeRef ref, char *buf, size_t buf_len) {
    if (!ref || buf_len == 0) return false;
    buf[0] = '\0';
    CFTypeID tid = CFGetTypeID(ref);
    if (tid == CFStringGetTypeID()) {
        return CFStringGetCString((CFStringRef)ref, buf, (CFIndex)buf_len, kCFStringEncodingUTF8);
    } else if (tid == CFDataGetTypeID()) {
        CFIndex len = CFDataGetLength((CFDataRef)ref);
        const uint8_t *ptr = CFDataGetBytePtr((CFDataRef)ref);
        if (len > 0 && ptr) {
            size_t copy_len = (size_t)len < (buf_len - 1) ? (size_t)len : (buf_len - 1);
            memcpy(buf, ptr, copy_len);
            buf[copy_len] = '\0';
            return true;
        }
    }
    return false;
}

static bool prop_u32(io_registry_entry_t entry, CFStringRef key, uint32_t *out_val) {
    CFTypeRef ref = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
    if (!ref) return false;
    bool ok = cf_to_u32(ref, out_val);
    CFRelease(ref);
    return ok;
}

static bool search_u32(io_registry_entry_t entry, CFStringRef key, uint32_t *out_val) {
    CFTypeRef ref = IORegistryEntrySearchCFProperty(
        entry,
        kIOServicePlane,
        key,
        kCFAllocatorDefault,
        kIORegistryIterateRecursively | kIORegistryIterateParents
    );
    if (!ref) return false;
    bool ok = cf_to_u32(ref, out_val);
    CFRelease(ref);
    return ok;
}

static bool search_string(io_registry_entry_t entry, CFStringRef key, char *buf, size_t buf_len) {
    CFTypeRef ref = IORegistryEntrySearchCFProperty(
        entry,
        kIOServicePlane,
        key,
        kCFAllocatorDefault,
        kIORegistryIterateRecursively | kIORegistryIterateParents
    );
    if (!ref) return false;
    bool ok = cf_to_string(ref, buf, buf_len);
    CFRelease(ref);
    return ok;
}

static uint32_t get_uart_hpm_rids_mask(void) {
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    if (!root) return 0x1; // Default RID 0 bitmask
    CFTypeRef ref = IORegistryEntrySearchCFProperty(
        root,
        kIODeviceTreePlane,
        CFSTR("uart-hpm-rids"),
        kCFAllocatorDefault,
        kIORegistryIterateRecursively
    );
    IOObjectRelease(root);
    uint32_t mask = 0;
    if (ref) {
        cf_to_u32(ref, &mask);
        CFRelease(ref);
    }
    return mask != 0 ? mask : 0x1;
}

bool hpm_get_host_platform(char *out_name, size_t name_len, uint32_t *out_unlock_key) {
    if (out_name && name_len > 0) out_name[0] = '\0';
    if (out_unlock_key) *out_unlock_key = 0;

    CFMutableDictionaryRef matching = IOServiceMatching("IOPlatformExpertDevice");
    if (!matching) return false;

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
    if (!service) return false;

    io_name_t deviceName;
    memset(deviceName, 0, sizeof(deviceName));
    kern_return_t kr = IORegistryEntryGetName(service, deviceName);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS) return false;

    if (out_name && name_len > 0) {
        snprintf(out_name, name_len, "%s", deviceName);
    }
    if (out_unlock_key) {
        *out_unlock_key = ((uint32_t)(uint8_t)deviceName[0] << 24) |
                          ((uint32_t)(uint8_t)deviceName[1] << 16) |
                          ((uint32_t)(uint8_t)deviceName[2] << 8)  |
                          ((uint32_t)(uint8_t)deviceName[3]);
    }
    return true;
}

size_t hpm_list_host_ports(HPMHostPortInfo *out_ports, size_t max_ports) {
    if (!out_ports || max_ports == 0) return 0;

    // 1. Collect AppleUSBHostController port-number -> locationID base
    typedef struct {
        uint32_t port_number;
        uint32_t location_base;
    } USBPortMap;
    USBPortMap usb_maps[32];
    size_t usb_count = 0;

    CFMutableDictionaryRef usb_match = IOServiceMatching("AppleUSBHostController");
    if (usb_match) {
        io_iterator_t usb_iter = 0;
        if (IOServiceGetMatchingServices(kIOMainPortDefault, usb_match, &usb_iter) == KERN_SUCCESS) {
            io_service_t ctrl;
            while ((ctrl = IOIteratorNext(usb_iter)) != 0) {
                uint32_t loc = 0, pn = 0;
                if (prop_u32(ctrl, CFSTR("locationID"), &loc) &&
                    search_u32(ctrl, CFSTR("port-number"), &pn) &&
                    usb_count < 32) {
                    usb_maps[usb_count].port_number = pn;
                    usb_maps[usb_count].location_base = loc & 0xff000000u;
                    usb_count++;
                }
                IOObjectRelease(ctrl);
            }
            IOObjectRelease(usb_iter);
        }
    }

    uint32_t uart_mask = get_uart_hpm_rids_mask();

    // 2. Iterate AppleHPM services
    CFMutableDictionaryRef hpm_match = IOServiceMatching("AppleHPM");
    if (!hpm_match) return 0;

    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, hpm_match, &iter) != KERN_SUCCESS) {
        return 0;
    }

    size_t count = 0;
    io_service_t dev;
    while ((dev = IOIteratorNext(iter)) != 0 && count < max_ports) {
        uint32_t rid_u = 0;
        if (!prop_u32(dev, CFSTR("RID"), &rid_u)) {
            IOObjectRelease(dev);
            continue;
        }
        HPMHostPortInfo *info = &out_ports[count];
        memset(info, 0, sizeof(HPMHostPortInfo));
        info->rid = (int32_t)rid_u;

        uint32_t pn = 0;
        if (search_u32(dev, CFSTR("port-number"), &pn)) {
            info->port_number = pn;
            for (size_t i = 0; i < usb_count; i++) {
                if (usb_maps[i].port_number == pn) {
                    info->location_base = usb_maps[i].location_base;
                    break;
                }
            }
        }

        if (!search_string(dev, CFSTR("port-location"), info->location_name, sizeof(info->location_name))) {
            snprintf(info->location_name, sizeof(info->location_name), "Port RID %d", info->rid);
        }

        io_string_t pathName;
        if (IORegistryEntryGetPath(dev, kIOServicePlane, pathName) == KERN_SUCCESS) {
            snprintf(info->io_path, sizeof(info->io_path), "%s", pathName);
        }

        info->is_dfu_capable = ((uart_mask & (1u << rid_u)) != 0) || (rid_u == 0);
        count++;
        IOObjectRelease(dev);
    }
    IOObjectRelease(iter);
    return count;
}

size_t hpm_list_apple_usb_devices(HPMUSBDeviceInfo *out_devs, size_t max_devs) {
    if (!out_devs || max_devs == 0) return 0;

    CFMutableDictionaryRef matching = IOServiceMatching("IOUSBHostDevice");
    if (!matching) return 0;

    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) != KERN_SUCCESS) {
        return 0;
    }

    size_t count = 0;
    io_service_t dev;
    while ((dev = IOIteratorNext(iter)) != 0 && count < max_devs) {
        uint32_t vid = 0, pid = 0;
        if (!prop_u32(dev, CFSTR("idVendor"), &vid) || vid != 0x05ac) {
            IOObjectRelease(dev);
            continue;
        }
        prop_u32(dev, CFSTR("idProduct"), &pid);

        HPMUSBDeviceInfo *info = &out_devs[count];
        memset(info, 0, sizeof(HPMUSBDeviceInfo));
        info->vendor_id = (uint16_t)vid;
        info->product_id = (uint16_t)pid;

        uint32_t bcd = 0, dclass = 0, dsub = 0, dproto = 0, loc = 0;
        if (prop_u32(dev, CFSTR("bcdDevice"), &bcd)) info->bcd_device = (uint16_t)bcd;
        if (prop_u32(dev, CFSTR("bDeviceClass"), &dclass)) info->device_class = (uint8_t)dclass;
        if (prop_u32(dev, CFSTR("bDeviceSubClass"), &dsub)) info->device_subclass = (uint8_t)dsub;
        if (prop_u32(dev, CFSTR("bDeviceProtocol"), &dproto)) info->device_protocol = (uint8_t)dproto;
        if (prop_u32(dev, CFSTR("locationID"), &loc)) info->location_id = loc;

        CFTypeRef prodRef = IORegistryEntryCreateCFProperty(dev, CFSTR("USB Product Name"), kCFAllocatorDefault, 0);
        if (!prodRef) {
            prodRef = IORegistryEntryCreateCFProperty(dev, CFSTR("kUSBProductString"), kCFAllocatorDefault, 0);
        }
        if (prodRef) {
            cf_to_string(prodRef, info->product_name, sizeof(info->product_name));
            CFRelease(prodRef);
        }
        if (info->product_name[0] == '\0') {
            io_name_t entryName;
            if (IORegistryEntryGetName(dev, entryName) == KERN_SUCCESS) {
                snprintf(info->product_name, sizeof(info->product_name), "%s", entryName);
            }
        }

        CFTypeRef serRef = IORegistryEntryCreateCFProperty(dev, CFSTR("kUSBSerialNumberString"), kCFAllocatorDefault, 0);
        if (!serRef) {
            serRef = IORegistryEntryCreateCFProperty(dev, CFSTR("USB Serial Number"), kCFAllocatorDefault, 0);
        }
        if (serRef) {
            cf_to_string(serRef, info->serial_number, sizeof(info->serial_number));
            CFRelease(serRef);
        }

        count++;
        IOObjectRelease(dev);
    }
    IOObjectRelease(iter);
    return count;
}

// Low-level AppleHPMLib helpers
static IOReturn hpm_read_reg(AppleHPMLib **device, uint64_t chip, uint8_t reg, uint8_t out_buf[64]) {
    memset(out_buf, 0, 64);
    uint64_t rlen = 0;
    return (*device)->Read(device, chip, reg, out_buf, 64, 0, &rlen);
}

static int hpm_command(AppleHPMLib **device, uint64_t chip, uint32_t cmd, const uint8_t *args, size_t args_len) {
    if (args && args_len > 0) {
        IOReturn wr = (*device)->Write(device, chip, 9, args, args_len, 0);
        if (wr != kIOReturnSuccess) return -1;
    }
    IOReturn cr = (*device)->Command(device, chip, cmd, 0);
    if (cr != kIOReturnSuccess) return -1;
    uint8_t res[64];
    if (hpm_read_reg(device, chip, 9, res) != kIOReturnSuccess) return -1;
    return (int)(res[0] & 0x0fu);
}

static bool hpm_send_vdm(AppleHPMLib **device, uint64_t chip, const uint32_t *vdm_words, size_t word_count, uint32_t *out_reply_hdr) {
    uint8_t start[64];
    if (hpm_read_reg(device, chip, 0x4d, start) != kIOReturnSuccess) return false;
    uint8_t rxst = start[0];

    uint8_t payload[64];
    memset(payload, 0, sizeof(payload));
    payload[0] = (uint8_t)((3u << 4) | (word_count & 0x0fu));
    for (size_t i = 0; i < word_count; i++) {
        uint32_t w = vdm_words[i];
        payload[1 + i * 4 + 0] = (uint8_t)(w & 0xff);
        payload[1 + i * 4 + 1] = (uint8_t)((w >> 8) & 0xff);
        payload[1 + i * 4 + 2] = (uint8_t)((w >> 16) & 0xff);
        payload[1 + i * 4 + 3] = (uint8_t)((w >> 24) & 0xff);
    }

    if (hpm_command(device, chip, fourcc_be("VDMs"), payload, 1 + word_count * 4) != 0) {
        return false;
    }

    uint8_t reply[64];
    bool got = false;
    for (int i = 0; i < 16; i++) {
        if (hpm_read_reg(device, chip, 0x4d, reply) != kIOReturnSuccess) return false;
        if (reply[0] != rxst) {
            got = true;
            break;
        }
        usleep(10000);
    }
    if (!got) return false;

    uint32_t hdr = (uint32_t)reply[1] |
                   ((uint32_t)reply[2] << 8) |
                   ((uint32_t)reply[3] << 16) |
                   ((uint32_t)reply[4] << 24);
    if (out_reply_hdr) *out_reply_hdr = hdr;
    return hdr == (vdm_words[0] | 0x40u);
}

HPMExecutionResult hpm_execute_action(HPMActionType action, int32_t target_rid) {
    HPMExecutionResult res;
    memset(&res, 0, sizeof(res));
    res.used_rid = target_rid >= 0 ? target_rid : 0;

    uint32_t unlock_key = 0;
    if (!hpm_get_host_platform(res.host_platform, sizeof(res.host_platform), &unlock_key)) {
        res.status_code = -1;
        snprintf(res.message, sizeof(res.message), "Impossibile leggere IOPlatformExpertDevice sull'host.");
        return res;
    }

    if (geteuid() != 0) {
        res.status_code = -2;
        snprintf(res.message, sizeof(res.message), "Privilegi di root (amministratore) richiesti per comunicare con AppleHPM.");
        return res;
    }

    CFMutableDictionaryRef matching = IOServiceMatching("AppleHPM");
    if (!matching) {
        res.status_code = -3;
        snprintf(res.message, sizeof(res.message), "IOServiceMatching(AppleHPM) fallito.");
        return res;
    }

    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) != KERN_SUCCESS) {
        res.status_code = -4;
        snprintf(res.message, sizeof(res.message), "Nessun controller AppleHPM trovato (questo Mac host è Apple Silicon?).");
        return res;
    }

    IOCFPlugInInterface **plugin = NULL;
    AppleHPMLib **device = NULL;
    int32_t wanted_rid = target_rid >= 0 ? target_rid : 0;

    io_service_t service;
    while ((service = IOIteratorNext(iter)) != 0) {
        uint32_t rid_u = 0;
        if (!prop_u32(service, CFSTR("RID"), &rid_u) || (int32_t)rid_u != wanted_rid) {
            IOObjectRelease(service);
            continue;
        }

        SInt32 score = 0;
        IOReturn kr = IOCreatePlugInInterfaceForService(
            service,
            kAppleHPMLibType,
            kIOCFPlugInInterfaceID,
            &plugin,
            &score
        );
        IOObjectRelease(service);
        if (kr == kIOReturnSuccess && plugin) {
            HRESULT hr = (*plugin)->QueryInterface(
                plugin,
                CFUUIDGetUUIDBytes(kAppleHPMLibInterface),
                (LPVOID *)&device
            );
            if (hr != S_OK || !device) {
                IODestroyPlugInInterface(plugin);
                plugin = NULL;
                device = NULL;
            }
        }
        break;
    }
    IOObjectRelease(iter);

    if (!plugin || !device) {
        res.status_code = -5;
        snprintf(res.message, sizeof(res.message),
                 "Impossibile aprire il plugin AppleHPMLib per RID=%d.", wanted_rid);
        return res;
    }

    uint64_t chip = 0;
    uint8_t reg3f[64];
    if (hpm_read_reg(device, chip, 0x3f, reg3f) == kIOReturnSuccess) {
        res.connected = (reg3f[0] & 1) != 0;
        res.is_source = (reg3f[0] & 2) == 0;
    }

    uint8_t reg03[64];
    if (hpm_read_reg(device, chip, 0x03, reg03) == kIOReturnSuccess) {
        snprintf(res.hpm_status, sizeof(res.hpm_status), "%.8s", (const char *)reg03);
    }

    if (!res.connected && action != HPM_ACTION_PROBE) {
        IODestroyPlugInInterface(plugin);
        res.status_code = -6;
        snprintf(res.message, sizeof(res.message),
                 "Nessun dispositivo rilevato sulla porta DFU dell'host (RID=%d). Controlla che il cavo USB-C sia collegato alle porte DFU di entrambi i Mac.",
                 wanted_rid);
        return res;
    }

    // Unlock ACE controller and enter DBMa mode
    bool entered_dbma = false;
    if (strcmp(res.hpm_status, "DBMa") != 0) {
        uint8_t key_le[4] = {
            (uint8_t)(unlock_key & 0xff),
            (uint8_t)((unlock_key >> 8) & 0xff),
            (uint8_t)((unlock_key >> 16) & 0xff),
            (uint8_t)((unlock_key >> 24) & 0xff)
        };
        if (hpm_command(device, chip, fourcc_be("LOCK"), key_le, 4) != 0) {
            // Reset with Gaid and retry LOCK
            hpm_command(device, chip, fourcc_be("Gaid"), NULL, 0);
            if (hpm_command(device, chip, fourcc_be("LOCK"), key_le, 4) != 0) {
                IODestroyPlugInInterface(plugin);
                res.status_code = -7;
                snprintf(res.message, sizeof(res.message),
                         "Sblocco controller AppleHPM (LOCK) fallito su host %s.", res.host_platform);
                return res;
            }
        }
        uint8_t dbma_on[1] = { 0x01 };
        if (hpm_command(device, chip, fourcc_be("DBMa"), dbma_on, 1) == 0) {
            if (hpm_read_reg(device, chip, 0x03, reg03) == kIOReturnSuccess) {
                snprintf(res.hpm_status, sizeof(res.hpm_status), "%.8s", (const char *)reg03);
            }
            entered_dbma = (strcmp(res.hpm_status, "DBMa") == 0);
        }
    } else {
        entered_dbma = true;
    }

    if (!entered_dbma) {
        IODestroyPlugInInterface(plugin);
        res.status_code = -8;
        snprintf(res.message, sizeof(res.message),
                 "Impossibile entrare in modalità debug DBMa (stato attuale: %s).", res.hpm_status);
        return res;
    }

    // Perform requested action
    if (action == HPM_ACTION_PROBE) {
        res.status_code = 0;
        snprintf(res.message, sizeof(res.message),
                 "Probe AppleHPM RID=%d riuscito (Host: %s, Connesso: %s, Ruolo: %s, Stato: %s).",
                 wanted_rid,
                 res.host_platform,
                 res.connected ? "SÌ" : "NO",
                 res.connected ? (res.is_source ? "Source/DFP" : "Sink/UFP") : "Nessuno",
                 res.hpm_status);
    } else if (action == HPM_ACTION_DFU_AUTO) {
        const uint32_t vdm_silicon[3] = { 0x05ac8012u, 0x00000106u, 0x80010000u };
        if (hpm_send_vdm(device, chip, vdm_silicon, 3, &res.vdm_reply_header)) {
            res.status_code = 0;
            snprintf(res.message, sizeof(res.message),
                     "Target inviato in modalità DFU con successo (VDM Apple Silicon 0x106 ACK: 0x%08X).",
                     res.vdm_reply_header);
        } else {
            // Fallback for Intel T2 Macs: 0x105 with 0x80020000 (PMU Reset + DFU Hold)
            const uint32_t vdm_t2[3] = { 0x05ac8012u, 0x00000105u, 0x80020000u };
            if (hpm_send_vdm(device, chip, vdm_t2, 3, &res.vdm_reply_header)) {
                res.status_code = 0;
                res.used_t2_fallback = true;
                snprintf(res.message, sizeof(res.message),
                         "Target inviato in modalità DFU tramite encoding Intel T2 (VDM 0x105 PMU Reset + DFU Hold ACK: 0x%08X).",
                         res.vdm_reply_header);
            } else {
                res.status_code = -9;
                snprintf(res.message, sizeof(res.message),
                         "Il Mac target ha rifiutato sia il VDM DFU Apple Silicon (0x106) sia il fallback Intel T2 (0x105/0x80020000). Ultima risposta: 0x%08X.",
                         res.vdm_reply_header);
            }
        }
    } else if (action == HPM_ACTION_DFU_SILICON) {
        const uint32_t vdm_silicon[3] = { 0x05ac8012u, 0x00000106u, 0x80010000u };
        if (hpm_send_vdm(device, chip, vdm_silicon, 3, &res.vdm_reply_header)) {
            res.status_code = 0;
            snprintf(res.message, sizeof(res.message),
                     "Target inviato in DFU (VDM Apple Silicon 0x106 ACK: 0x%08X).", res.vdm_reply_header);
        } else {
            res.status_code = -9;
            snprintf(res.message, sizeof(res.message),
                     "Comando VDM DFU Apple Silicon (0x106) fallito (risposta: 0x%08X).", res.vdm_reply_header);
        }
    } else if (action == HPM_ACTION_DFU_T2) {
        const uint32_t vdm_t2[3] = { 0x05ac8012u, 0x00000105u, 0x80020000u };
        if (hpm_send_vdm(device, chip, vdm_t2, 3, &res.vdm_reply_header)) {
            res.status_code = 0;
            res.used_t2_fallback = true;
            snprintf(res.message, sizeof(res.message),
                     "Target inviato in DFU (VDM Intel T2 0x105/0x80020000 ACK: 0x%08X).", res.vdm_reply_header);
        } else {
            res.status_code = -9;
            snprintf(res.message, sizeof(res.message),
                     "Comando VDM DFU Intel T2 (0x105/0x80020000) fallito (risposta: 0x%08X).", res.vdm_reply_header);
        }
    } else if (action == HPM_ACTION_REBOOT) {
        const uint32_t vdm_reboot[3] = { 0x05ac8012u, 0x00000105u, 0x80000000u };
        if (hpm_send_vdm(device, chip, vdm_reboot, 3, &res.vdm_reply_header)) {
            res.status_code = 0;
            snprintf(res.message, sizeof(res.message),
                     "Riavvio remoto del Mac target eseguito con successo (VDM 0x105 ACK: 0x%08X).", res.vdm_reply_header);
        } else {
            res.status_code = -10;
            snprintf(res.message, sizeof(res.message),
                     "Riavvio remoto VDM fallito (risposta: 0x%08X).", res.vdm_reply_header);
        }
    } else if (action == HPM_ACTION_SERIAL) {
        const uint32_t vdm_serial[2] = { 0x05ac8012u, 0x01840306u };
        if (hpm_send_vdm(device, chip, vdm_serial, 2, &res.vdm_reply_header)) {
            uint8_t dven_arg[4] = { 0x06, 0x03, 0x84, 0x01 };
            if (hpm_command(device, chip, fourcc_be("DVEn"), dven_arg, 4) == 0) {
                res.status_code = 0;
                snprintf(res.message, sizeof(res.message),
                         "Console seriale UART attiva su SBU1/SBU2 (/dev/cu.debug-console @ 115200 8N1). Richiede cavo USB 3.x SuperSpeed/Thunderbolt.");
            } else {
                res.status_code = -11;
                snprintf(res.message, sizeof(res.message),
                         "Target in modalità seriale, ma abilitazione DVEn locale fallita.");
            }
        } else {
            res.status_code = -11;
            snprintf(res.message, sizeof(res.message),
                     "Impossibile attivare modalità seriale sul target (risposta: 0x%08X).", res.vdm_reply_header);
        }
    } else if (action == HPM_ACTION_DEBUGUSB) {
        const uint32_t vdm_kis[2] = { 0x05ac8012u, 0x01824606u };
        if (hpm_send_vdm(device, chip, vdm_kis, 2, &res.vdm_reply_header)) {
            res.status_code = 0;
            snprintf(res.message, sizeof(res.message),
                     "Target commutato in modalità Debug USB (KIS 05ac:1881, ACK: 0x%08X).", res.vdm_reply_header);
        } else {
            res.status_code = -12;
            snprintf(res.message, sizeof(res.message),
                     "Commutazione Debug USB (KIS) fallita (risposta: 0x%08X).", res.vdm_reply_header);
        }
    }

    // Exit DBMa mode cleanly
    uint8_t dbma_off[1] = { 0x00 };
    hpm_command(device, chip, fourcc_be("DBMa"), dbma_off, 1);
    IODestroyPlugInInterface(plugin);
    return res;
}
