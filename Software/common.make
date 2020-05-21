# Toolchain definitions
TOOLCHAIN ?= arm-none-eabi-
CC := $(TOOLCHAIN)gcc
AR := $(TOOLCHAIN)ar
OBJCOPY := $(TOOLCHAIN)objcopy

ifndef DESKTOP
    SIZE := $(TOOLCHAIN)size
endif

# Optimization flags
OPT ?= -Os -g3

ifndef DESKTOP
# Hardware flags
DEVICE_FLAGS = -mabi=aapcs \
	-mcpu=cortex-m4 \
	-mfloat-abi=hard \
	-mfpu=fpv4-sp-d16 \
	-mthumb
endif

# Common flags
FLAGS = -DBOARD_CUSTOM \
	-DCONFIG_NFCT_PINS_AS_GPIOS \
	-DFLOAT_ABI_HARD \
	-DNRF52840_XXAA \
	-DNRF_SD_BLE_API_VERSION=6 \
	-DS140 \
	-DSOFTDEVICE_PRESENT \
	-DSWI_DISABLE0

# C flags common to all targets
CFLAGS = $(OPT) \
	$(FLAGS) \
	$(DEVICE_FLAGS) \
	--short-enums \
	-DDEBUG \
	-DSTLVECTOR \
	-Wall \
	-Werror \
	-Wformat=0 \
	-Wno-unknown-pragmas \
	-Wno-unused-function \
	-Wno-unused-local-typedefs \
	-Wno-unused-variable \
	-fdata-sections \
	-ffunction-sections \
	-fno-builtin \
	-fno-strict-aliasing

ifndef DESKTOP
CFLAGS += -DDC801_EMBEDDED

# C++ flags common to all targets
CXXFLAGS = -felide-constructors \
	-fno-exceptions \
	-fno-rtti
else
CFLAGS += -DDC801_DESKTOP
endif

# Assembler flags common to all targets
ASMFLAGS = -g3 \
	$(FLAGS) \
	$(DEVICE_FLAGS)

# Linker flags
LDFLAGS = $(OPT) \
	$(DEVICE_FLAGS) \
	-Wl,--gc-sections

ifndef DESKTOP
LDFLAGS += --specs=nano.specs \
	-L$(SDK_ROOT)/modules/nrfx/mdk \
	-T$(LINKER_SCRIPT)
endif

LD_LIBRARIES = -lc \
	-lm \
	-lsupc++ \
	-lstdc++

ifndef DESKTOP
LD_LIBRARIES += -lnosys
endif

CFLAGS += -D__HEAP_SIZE=16384
CFLAGS += -D__STACK_SIZE=16384
ASMFLAGS += -D__HEAP_SIZE=16384
ASMFLAGS += -D__STACK_SIZE=16384

# GCC Dependency flags:
#  -MD:		Generate dependency tree for specified object as a side effect of compilation
#  -MP:		Add a phony target for generated dependency files.
#			This helps make track changes to header files
#  -MF:		Override default dependency file name
#  -MT:		Override default dependency graph configuration

# Make will automatically integrate these dependency files and only rebuild source files that are
#  newer than their dependency files. If a header file changes, make will scan the dependency tree
#  and rebuild anything in the dependency tree (usually almost everything)

# C files
$(BUILD_DIR)/%.o: $(SRC_ROOT)/%.c
	@echo "[ CC ] $(notdir $<)"

ifeq ($(OS),Windows_NT)
	DIR := $(subst /,\,$(@D))
	@if not exist $(DIR) $(MKDIR) $(DIR)
else
	@$(MKDIR) $(@D)
endif

	@$(CC) -x c -c -std=c11 $(CFLAGS) $(INCLUDES) -MD -MP -MF "$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -MT"$(@:%.o=%.o)" -o "$@" "$<"

# C++ files
$(BUILD_DIR)/%.o: $(SRC_ROOT)/%.cpp
	@echo "[ CXX ] $(notdir $<)"

ifeq ($(OS),Windows_NT)
	DIR := $(subst /,\,$(@D))
	@if not exist $(DIR) $(MKDIR) $(DIR)
else
	@$(MKDIR) $(@D)
endif

	@$(CC) -x c++ -c -std=c++0x $(CFLAGS) $(CXXFLAGS) $(INCLUDES) -MD -MP -MF "$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -MT"$(@:%.o=%.o)" -o "$@" "$<"

# ASM files
$(BUILD_DIR)/%.o: $(SRC_ROOT)/%.S
	@echo "[ AS ] $(notdir $<)"

ifeq ($(OS),Windows_NT)
	DIR := $(subst /,\,$(@D))
	@if not exist $(DIR) $(MKDIR) $(DIR)
else
	@$(MKDIR) $(@D)
endif

	@$(CC) -x assembler-with-cpp -c $(ASMFLAGS) -MD -MP -MF "$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -MT"$(@:%.o=%.o)" -o "$@" "$<"

# Intel format Hex files
$(PRJ_ROOT)/output/%.hex: $(PRJ_ROOT)/output/%.out
	@echo "[ HEX ] $(notdir $@)"
	@$(OBJCOPY) -O ihex "$<" "$@"

# Output binary
$(PRJ_ROOT)/output/%.bin: $(PRJ_ROOT)/output/%.out
	@echo "[ BIN ] $(notdir $@)"
	@$(OBJCOPY) -O binary "$<" "$@"