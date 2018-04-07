src = $(wildcard *.c)
obj = $(src:.c=.o)

# Build type parameter

ifeq ($(BUILD),debug)
    CFLAGS_USE += -O0 -ggdb -Wall # -fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls
    GLAD_GEN = c-debug
    # LDFLAGS += -lasan
else
    CFLAGS_USE += -O2 -march=native
    GLAD_GEN = c
endif

# Detect OS if not specified (OSX, Linux, BSD are supported)

ifndef INSTALL
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        INSTALL = osx
    else
        INSTALL = unix
    endif
endif

# Install type parameter

ifeq ($(INSTALL),standalone)
    CFLAGS_USE += -DGLAVA_STANDALONE
endif

ifeq ($(INSTALL),unix)
    CFLAGS_USE += -DGLAVA_UNIX
    ifdef XDG_CONFIG_DIRS
        SHADER_DIR = $(firstword $(subst :, ,$XDG_CONFIG_DIR))/glava
    else
        SHADER_DIR = etc/xdg/glava
    endif
endif

ifeq ($(INSTALL),osx)
    CFLAGS_USE += -DGLAVA_OSX
    SHADER_DIR = Library/glava
endif

ifndef DISABLE_GLFW
    CFLAGS_USE += -DGLAVA_GLFW
    LDFLAGS += -lglfw
endif

ifndef DISABLE_GLX
    CFLAGS_USE += -DGLAVA_GLX
    LDFLAGS += -lXrender
endif

ifndef DISABLE_UI
    ifneq ($(shell ls /usr/lib/libluajit-5.1.so 2>/dev/null),)
        LDFLAGS += -lluajit-5.1
        CFLAGS_USE += -DGLAVA_LUAJIT
    else
        LDFLAGS += -llua
        CFLAGS_USE += -DGLAVA_LUA
    endif
	CFLAGS_USE += -DGLAVA_UI
endif

LDFLAGS += -lfreetype -lpulse -lpulse-simple -pthread -ldl -lm -lX11 -lXext

PYTHON = python

GLAVA_VERSION = \"$(shell git describe --tags 2>/dev/null)\"
ifeq ($(GLAVA_VERSION),\"\")
    GLAVA_VERSION = \"unknown\"
endif

GLAD_INSTALL_DIR = glad
GLAD_SRCFILE = ./glad/src/glad.c
GLAD_ARGS = --generator=$(GLAD_GEN) --extensions=GL_EXT_framebuffer_multisample,GL_EXT_texture_filter_anisotropic
CFLAGS_USE += -I/usr/include/freetype2 -I glad/include -DGLAVA_VERSION="$(GLAVA_VERSION)" $(CFLAGS)

all: glava

%.o: %.c glad.o
	$(CC) $(CFLAGS_USE) -o $@ -c $(firstword $<)

glava: $(obj)
	$(CC) -o glava $(obj) glad.o $(LDFLAGS)

glad.o:
	cd $(GLAD_INSTALL_DIR) && $(PYTHON) -m glad $(GLAD_ARGS) --out-path=.
	$(CC) $(CFLAGS_USE) -o glad.o $(GLAD_SRCFILE) -c

.PHONY: clean
clean:
	rm -f $(obj) glava glad.o

.PHONY: install
install:
	install -Dm755 glava "$(DESTDIR)/usr/bin/glava"
	install -d "$(DESTDIR)/$(SHADER_DIR)"
	cp -Rv shaders/* "$(DESTDIR)/$(SHADER_DIR)"

.PHONY: uninstall
uninstall:
	rm /usr/bin/glava
	rm -rf $(SHADER_DIR)/glava

