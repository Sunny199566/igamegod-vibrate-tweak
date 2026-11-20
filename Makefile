ARCHS = arm64e
export TARGET = iphone:clang:16.5:14.5
THEOS_PACKAGE_SCHEME = rootless
# 新增这一行！强制指定根目录layout
THEOS_LAYOUT_DIR = $(CURDIR)/layout

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += RecordTweak
SUBPROJECTS += GestureManager
SUBPROJECTS += PlayDaemon

include $(THEOS_MAKE_PATH)/aggregate.mk