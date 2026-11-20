ARCHS = arm64e
export TARGET = iphone:clang:16.5:14.5
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iGameGodVibrate
iGameGodVibrate_FILES = Tweak.x