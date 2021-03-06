ifndef DEVKITPRO
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
else
include $(DEVKITPRO)/libnx/switch_rules
endif

VERSION_MAJOR	:=	0
VERSION_MINOR	:=	0
VERSION_PATCH	:=	1

APP_TITLE	:=	Hello eXUI
APP_AUTHOR	:=	$(shell whoami)
APP_VERSION	:=	$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)

LIB_EXUI	:=	libs/eXUI
LIB_NANOVG	:=	$(LIB_EXUI)/libs/nanovg
TARGET		:=	hello-eXUI
SOURCES     :=	source
SHADERS		:=	$(LIB_NANOVG)/shaders
INCLUDES	:=	include
ROMFS		:=	romfs
OUT_SHADERS	:=	shaders

LIBDIRS		:=	$(PORTLIBS) $(LIBNX) $(LIB_EXUI) $(LIB_NANOVG)

ARCH		:=	-march=armv8-a -mtune=cortex-a57 -mtp=soft -fPIE

DEFINES		:=	-D__SWITCH__
DEFINES		+=	-DVERSION_MAJOR=$(VERSION_MAJOR)
DEFINES		+=	-DVERSION_MINOR=$(VERSION_MINOR)
DEFINES		+=	-DVERSION_PATCH=$(VERSION_PATCH)

CFLAGS		:=	-Wall -O3 -ffunction-sections \
				$(ARCH) $(DEFINES)

CXXFLAGS	:=	-std=gnu++2a -fno-exceptions -fno-rtti

LDFLAGS		:=	-specs=$(DEVKITPRO)/libnx/switch.specs $(ARCH)

# For Deko3D Builds (smallest binary output)
LIBS		:=	-leXUI -lnanovg -ldeko3d -lnx

CPPFILES	:=	$(foreach SOURCE,$(SOURCES),$(wildcard $(SOURCE)/*.cpp))
GLSLFILES	:=	$(wildcard $(SHADERS)/*.glsl)
OFILES 		:=	$(CPPFILES:%.cpp=%.o)
DEPENDS		:=	$(OFILES_SRC:%.o=%.d)
INCFLAGS	:=	$(foreach LIBDIR,$(LIBDIRS),-I$(LIBDIR)/include) \
				$(foreach INCLUDE,$(INCLUDES),-I$(INCLUDE))
LIBPATHS	:=	$(foreach LIBDIR,$(LIBDIRS),-L$(LIBDIR)/lib)

ifeq ($(strip $(CPPFILES)),)
	LD	:=	$(CC)
else
	LD	:=	$(CXX)
endif

ifneq ($(strip $(ROMFS)),)
	ROMFS_TARGETS :=
	ROMFS_FOLDERS :=
	ifneq ($(strip $(OUT_SHADERS)),)
		ROMFS_SHADERS := $(ROMFS)/$(OUT_SHADERS)
		ROMFS_TARGETS += $(patsubst $(SHADERS)/%.glsl, $(ROMFS_SHADERS)/%.dksh, $(GLSLFILES))
		ROMFS_FOLDERS += $(ROMFS_SHADERS)
	endif

	ROMFS_DEPS := $(foreach ROMFS_TARGET,$(ROMFS_TARGETS),$(ROMFS_TARGET))
endif

APP_ICON	:=	icon.jpg
OUTPUT		:=	$(TARGET)
NACP_OUTPUT	:=	$(OUTPUT).nacp
NRO_OUTPUT	:=	$(OUTPUT).nro
ELF_OUTPUT	:=	$(OUTPUT).elf
NROFLAGS	+=	--nacp=$(NACP_OUTPUT) --romfsdir=$(ROMFS) --icon=$(APP_ICON)

.PHONY: build clean

build:	$(NRO_OUTPUT)
$(NRO_OUTPUT):	$(ELF_OUTPUT) $(NACP_OUTPUT) $(ROMFS_DEPS)

ifneq ($(strip $(ROMFS_TARGETS)),)

$(ROMFS_TARGETS): | $(ROMFS_FOLDERS)

$(ROMFS_FOLDERS):
	mkdir -p $@

$(ROMFS_SHADERS)/%_vsh.dksh: $(SHADERS)/%_vsh.glsl
	uam -s vert -o $@ $<

$(ROMFS_SHADERS)/%_tcsh.dksh: $(SHADERS)/%_tcsh.glsl
	uam -s tess_ctrl -o $@ $<

$(ROMFS_SHADERS)/%_tesh.dksh: $(SHADERS)/%_tesh.glsl
	uam -s tess_eval -o $@ $<

$(ROMFS_SHADERS)/%_gsh.dksh: $(SHADERS)/%_gsh.glsl
	uam -s geom -o $@ $<

$(ROMFS_SHADERS)/%_fsh.dksh: $(SHADERS)/%_fsh.glsl
	uam -s frag -o $@ $<

$(ROMFS_SHADERS)/%.dksh: $(SHADERS)/%.glsl
	uam -s comp -o $@ $<

endif

%.o:	%.cpp
	$(CXX) -MMD -MP -MF $(@:%.o=%.d) $(CFLAGS) $(INCFLAGS) $(CXXFLAGS) -c $< -o $@

$(ELF_OUTPUT):	$(OFILES)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBPATHS) $(LIBS) -o $@

clean:
	rm -f $(ROMFS_DEPS) $(NRO_OUTPUT) $(NACP_OUTPUT) $(ELF_OUTPUT) $(OFILES) $(DEPENDS)

-include $(DEPENDS)
