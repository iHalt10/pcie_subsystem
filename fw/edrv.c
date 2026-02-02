#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>

MODULE_DESCRIPTION("example driver");
MODULE_AUTHOR("Takeaki Oura");
MODULE_LICENSE("GPL");
MODULE_VERSION("0.1");

#define PROC_NAME "driver/edev_dma"

struct bar_resource {
    size_t size;
    void __iomem *region;
};

struct dma_resource {
    size_t size;
    void *region;
    dma_addr_t address;
};

struct example_dev {
    struct pci_dev *pdev;
    struct device *dev;
    struct bar_resource bar0;
    struct dma_resource dma;
    struct proc_dir_entry *proc_entry;
};

static struct example_dev *edev;

static u64 lo_hi_readq(void __iomem *addr) {
    u32 low, high;
    low = readl(addr);
    high = readl(addr + 4);
    return ((u64)high << 32) | low;
}

static void lo_hi_writeq(u64 val, void __iomem *addr) {
    writel(val & 0xFFFFFFFF, addr);
    writel(val >> 32, addr + 4);
}

static void *dma_seq_start(struct seq_file *s, loff_t *pos) {
    if (!edev || !edev->dma.region)
        return NULL;

    if (*pos >= edev->dma.size / 4)
        return NULL;

    return (u32 *)edev->dma.region + *pos;
}

static void *dma_seq_next(struct seq_file *s, void *v, loff_t *pos) {
    (*pos)++;
    if (*pos >= edev->dma.size / 4)
        return NULL;

    return (u32 *)edev->dma.region + *pos;
}

static void dma_seq_stop(struct seq_file *s, void *v) {}

static int dma_seq_show(struct seq_file *s, void *v) {
    u32 *data = (u32 *)v;
    loff_t idx = data - (u32 *)edev->dma.region;
    seq_printf(s, "[%04lx]: 0x%08x\n", idx, *data);
    return 0;
}

static const struct seq_operations dma_seq_ops = {
    .start = dma_seq_start,
    .next = dma_seq_next,
    .stop = dma_seq_stop,
    .show = dma_seq_show
};

static int dma_proc_open(struct inode *inode, struct file *file) {
    return seq_open(file, &dma_seq_ops);
}

static const struct proc_ops dma_proc_ops = {
    .proc_open = dma_proc_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = seq_release,
};

static int edev_probe(struct pci_dev *pdev, const struct pci_device_id *ent) {
    int err;
    struct device *dev = &pdev->dev;
    u64 value;

    dev_info(dev, "Vendor - 0x%04x", pdev->vendor);
    dev_info(dev, "Device - 0x%04x", pdev->device);

    err = pci_enable_device(pdev);
    if (err) {
        dev_err(dev, "Failed to enable PCI device\n");
        return err;
    }

    edev = devm_kzalloc(dev, sizeof(struct example_dev), GFP_KERNEL);
    if (!edev) {
        err = -ENOMEM;
        goto disable_device;
    }

    edev->pdev = pdev;
    edev->dev = dev;

    err = pci_request_region(pdev, 0, "edev_bar0");
    if (err) {
        dev_err(dev, "Failed to request BAR0 region\n");
        goto free_dev;
    }

    edev->bar0.size = 4096;
    edev->bar0.region = pci_iomap(pdev, 0, edev->bar0.size);
    if (!edev->bar0.region) {
        dev_err(dev, "Failed to map BAR0\n");
        err = -ENOMEM;
        goto release_bar;
    }

    value = readl(edev->bar0.region);
    dev_info(dev, "BAR0 offset 0x0 value: 0x%016llx\n", value);

    pci_set_master(pdev);
    edev->dma.size = 8192;
    edev->dma.region = dma_alloc_coherent(dev, edev->dma.size, &edev->dma.address, GFP_KERNEL);
    if (!edev->dma.region) {
        dev_err(dev, "Failed to allocate DMA memory\n");
        err = -ENOMEM;
        goto unmap_bar;
    }

    u32 *dma_ptr = (u32 *)edev->dma.region;
    for (int i = 0; i < (edev->dma.size / 4); i++) {
        dma_ptr[i] = 0xCAFE0000 | i;
    }

    dev_info(dev, "DMA memory first value: 0x%08x\n", dma_ptr[0]);
    dev_info(dev, "DMA memory middle value: 0x%08x\n", dma_ptr[1024]);
    dev_info(dev, "DMA memory last value: 0x%08x\n", dma_ptr[2047]);

    value = lo_hi_readq(edev->bar0.region + 0x4);
    dev_info(dev, "Initial DMA address register value: 0x%016llx\n", value);

    lo_hi_writeq(edev->dma.address, edev->bar0.region + 0x4);

    value = lo_hi_readq(edev->bar0.region + 0x4);
    dev_info(dev, "Updated DMA address register value: 0x%016llx\n", value);

    if (value == edev->dma.address) {
        dev_info(dev, "DMA address verification succeeded: written = 0x%016llx, read = 0x%016llx\n",
                 edev->dma.address, value);
    } else {
        dev_err(dev, "DMA address verification failed: written = 0x%016llx, read = 0x%016llx\n",
                edev->dma.address, value);
        err = -EIO;
        goto free_dma;
    }

    edev->proc_entry = proc_create(PROC_NAME, 0444, NULL, &dma_proc_ops);
    if (!edev->proc_entry) {
        dev_err(dev, "Failed to create proc entry\n");
        err = -ENOMEM;
        goto free_dma;
    }

    dev_info(dev, "Created proc entry: /proc/%s\n", PROC_NAME);

    return 0;

free_dma:
    dma_free_coherent(dev, edev->dma.size, edev->dma.region, edev->dma.address);
unmap_bar:
    pci_iounmap(pdev, edev->bar0.region);
release_bar:
    pci_release_region(pdev, 0);
free_dev:
    devm_kfree(dev, edev);
disable_device:
    pci_disable_device(pdev);
    return err;
}

static void edev_remove(struct pci_dev *pdev) {
    struct device *dev = &pdev->dev;

    if (!edev) return;

    if (edev->proc_entry) {
        proc_remove(edev->proc_entry);
        dev_info(dev, "Removed proc entry: /proc/%s\n", PROC_NAME);
    }

    if (edev->dma.region) {
        dma_free_coherent(dev, edev->dma.size, edev->dma.region, edev->dma.address);
    }

    if (edev->bar0.region) {
        pci_iounmap(pdev, edev->bar0.region);
        pci_release_region(pdev, 0);
    }

    pci_disable_device(pdev);
    devm_kfree(dev, edev);
}

static void edev_shutdown(struct pci_dev *pdev) {
    edev_remove(pdev);
}

static const struct pci_device_id pci_ids[] = {
    {PCI_DEVICE(0x1234, 0x0001)},
    {0}
};
MODULE_DEVICE_TABLE(pci, pci_ids);

static struct pci_driver pci_driver = {
    .name = "edev",
    .id_table = pci_ids,
    .probe = edev_probe,
    .remove = edev_remove,
    .shutdown = edev_shutdown
};

static int __init edev_init(void) {
    return pci_register_driver(&pci_driver);
}

static void __exit edev_exit(void) {
    pci_unregister_driver(&pci_driver);
}

module_init(edev_init);
module_exit(edev_exit);
