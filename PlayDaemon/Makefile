ARCHS = arm64e
TARGET = iphone:clang:16.5:14.5
INSTALL_TARGET_PROCESSES =

THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

include $(THEOS)/makefiles/common.mk

TOOL_NAME = PlayDaemon
PlayDaemon_FILES = PlayDaemon.m
PlayDaemon_CFLAGS = -fobjc-arc
PlayDaemon_INSTALL_PATH = /var/jb/usr/bin

include $(THEOS_MAKE_PATH)/tool.mk