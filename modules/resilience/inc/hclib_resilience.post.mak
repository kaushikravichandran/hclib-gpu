# Post Makefile includes are the main part of a module's build system, allowing
# it to add flags to the overall project compile and link flags.
HCLIB_CFLAGS+=-I$(HCLIB_ROOT)/../modules/resilience/inc
HCLIB_CXXFLAGS+=-I$(HCLIB_ROOT)/../modules/resilience/inc
HCLIB_LDFLAGS+=-L$(HCLIB_ROOT)/../modules/resilience/lib
HCLIB_LDLIBS+=-lhclib_resilience

# ifeq ($(IS_MAC_OS),1)
# HCLIB_LDLIBS += $(call GET_LINK_FLAG,-force_load) \
# 				  $(call GET_LINK_FLAG,$(HCLIB_ROOT)/../modules/system/lib/libhclib_system.a)
# else
# HCLIB_LDLIBS += $(call GET_LINK_FLAG,--whole-archive) \
# 				  $(call GET_LINK_FLAG,$(HCLIB_ROOT)/../modules/system/lib/libhclib_system.a) \
# 				  $(call GET_LINK_FLAG,--no-whole-archive)
# endif
