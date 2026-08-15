obj-m += hid-asus.o

KERNEL_VERSION ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KERNEL_VERSION)/build

.PHONY: all modules clean

all: modules

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
