#include "logging.h"
#include "pci_resource.h"
#include <stdio.h>
#include <stdlib.h>

#define SYS_FILE "/sys/bus/pci/devices/0000:70:00.0/resource0"

void cleanupPciResource(PciResource pciResource) {
    logInfo("Cleanup PciResource");
    pciResource.close(&pciResource);
}

int main(void) {
    PciResource pciResource;
    uint32_t base_address = 0x0;
    uint32_t address = 0xC;

    if (openPciResource(&pciResource, SYS_FILE, 4096, base_address) == EXIT_FAILURE) {
        return EXIT_FAILURE;
    }

    if (pciResource.write32(&pciResource, address, 8) == EXIT_FAILURE) {
        cleanupPciResource(pciResource);
        return EXIT_FAILURE;
    }

    cleanupPciResource(pciResource);
}
