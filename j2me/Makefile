######################################################################
##
## Copyright (C) 2007-2008,  Simon Kagstrom
##
## Filename:      Makefile
## Author:        Simon Kagstrom <simon.kagstrom@gmail.com>
## Description:   Generic Makefile
##
## $Id: Makefile $
##
######################################################################

# Find out the path to the wireless toolkit                                                                                   
PREVERIFY_BINARY_PATH=$(shell which preverify)
PREVERIFY_REAL_PATH=$(shell readlink -f $(PREVERIFY_BINARY_PATH))
PREVERIFY_DIRNAME=$(shell dirname $(PREVERIFY_BINARY_PATH))
WTK_PATH=$(PREVERIFY_DIRNAME)/../

all: frodo.jar

include/cibyl-syscalls.db: syscalls/command_mgr/include/command_mgr.h
	cibyl-generate-c-header -o include syscalls command_mgr

program: include/cibyl-syscalls.db
	make -C ../Src -f ../Src/Makefile.cibyl

tmpclasses/Cibyl.j: program
	cibyl-mips2java -DJSR075 -I include -O -d tmpclasses program

frodo.jar: tmpclasses/Cibyl.j
	install -d res
	cp `cibyl-config --prefix`/mips-cibyl-elf/sys-root/usr/share/java/Main.java tmpclasses
	cp `cibyl-config --prefix`/mips-cibyl-elf/sys-root/usr/share/java/GameScreenCanvas.java tmpclasses
	cp CibylConfig.java tmpclasses/
	cd tmpclasses && javac -classpath : -source 1.4 -bootclasspath $(WTK_PATH)/lib/cldcapi11.jar:$(WTK_PATH)/lib/midpapi20.jar:$(WTK_PATH)/lib/jsr75.jar -source 1.4 *.java
	preverify -classpath $(WTK_PATH)/lib/cldcapi11.jar:$(WTK_PATH)/lib/midpapi20.jar:$(WTK_PATH)/lib/jsr75.jar: -d classes/ tmpclasses/
	cp tmpclasses/program.data.bin res/
	cp "../Basic ROM" res/Basic_ROM
	cp "../Kernal ROM" res/Kernal_ROM
	cp "../Char ROM" res/Char_ROM
	cp "../1541 ROM" res/1541_ROM
	jar cfm $@ MANIFEST.MF -C classes . -C res .

frodo.jad: frodo.jad.templ frodo.jar
	cat $< > $@
	echo -n "MIDlet-Jar-Size: " >> $@
	wc -c frodo.jar | cut -d ' ' -f -1 >> $@

clean:
	rm -rf classes tmpclasses program *.jar *.jad *~ res include
	make -C ../Src -f ../Src/Makefile.cibyl clean

FORCE:
