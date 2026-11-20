ARCHS = arm64e
export TARGET = iphone:clang:16.5:14.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# ========== 这三行就是你缺失的核心部分 ==========
TWEAK_NAME = iGameGodVibrate
iGameGodVibrate_FILES = Tweak.x
include $(THEOS_MAKE_PATH)/tweak.mk