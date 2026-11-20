ARCHS = arm64e
export TARGET = iphone:clang:16.5:14.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iGameGodVibrate
# 使用 Tweak.x，不用新建xm文件，直接用仓库已存在的文件，不会报文件不存在错误
iGameGodVibrate_FILES = Tweak.x
include $(THEOS_MAKE_PATH)/tweak.mk