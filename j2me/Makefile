######################################################################
##
## Copyright (C) 2005,  Blekinge Institute of Technology
##
## Filename:      Makefile
## Author:        Simon Kagstrom <ska@bth.se>
## Description:   Generic Makefile
##
## $Id: Makefile 9386 2006-08-16 06:28:16Z ska $
##
######################################################################
SUBDIRS = ../Src
RESOURCES=res/program.data.bin res/Basic_ROM res/Kernal_ROM res/Char_ROM res/1541_ROM
TARGET   =frodo.jar frodo.jad
CIBYL_SYSCALL_SETS ?= resource_manager

CIBYL_GENERATE_JAVA_WRAPPERS_OPTS=-DJSR075 -S syscalls -Iinclude
CIBYL_MIPS2JAVA_OPTS +=-DJSR075 -Iinclude
CIBYL_CLASSPATH=$(WTK_PATH)/lib/jsr75.jar

all: include/ $(SUBDIRS)

include $(CIBYL_BASE)/build/Rules-j2me.mk

$(SUBDIRS):
	make -C $@ -f $@/Makefile.cibyl

tmpclasses/CibylConfig.java: CibylConfig.java
	cp $< $@

res/Basic_ROM:
	cp "../Basic ROM" $@

res/Kernal_ROM:
	cp "../Kernal ROM" $@

res/Char_ROM:
	cp "../Char ROM" $@

res/1541_ROM:
	cp "../1541 ROM" $@

res/a.bin:
	cp "../a.bin" $@

include/: FORCE
	$(CIBYL_BASE)/tools/cibyl-generate-c-header -o $@ syscalls/ command_mgr
FORCE:
