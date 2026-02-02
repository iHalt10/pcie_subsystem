.PHONY: all clean

CC = gcc
CFLAGS = -Wall -Wextra -O2 -g
OBJS_DIR = objs

SRC = main.c logging.c pci_resource.c
HEADERS = logging.h pci_resource.h

OBJS = $(addprefix $(OBJS_DIR)/, $(SRC:.c=.o))

TARGET = main

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

$(OBJS_DIR)/%.o: %.c $(HEADERS)
	@mkdir -p $(OBJS_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(OBJS_DIR) $(TARGET)
