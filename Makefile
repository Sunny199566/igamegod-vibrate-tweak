ARCHS = arm64e
export TARGET = iphone:clang:16.5:14.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iGameGodVibrate
# ✅ 修改这里！把 Tweak.x → iGameGodVibrate.xm
iGameGodVibrate_FILES = iGameGodVibrate.xm
include $(THEOS_MAKE_PATH)/tweak.mk