#!/do/not/make
########################################################################
# A toc2 subsystem for creation of installation sets...
#
# these rules only work with GNU Make 3.80 and higher...
#
# To be included from the shared toc makefile. It uses
# $(toc2.home)/bin/install-sh to perform the installation but could
# easily be adapted to use an arbitrary installer.
#
# Sample usage:
#  package.install.bins = mybin myotherbin # installs to $(prefix)/bin
#  package.install.libs = mylib.a myotherlib.a # installs to $(prefix)/lib
#
# There's a whole lot more to know, if you wanna poke around the code.
#
# Design note: the traditional xxx-local targets aren't really
# necessary. If someone wants to customize install they can simply do
# this:
#
# install: my-install
# my-install:
#      ....
#
# For each X in $(toc2.install.target_basenames) the following targets
# are created:
#
#  install-X:
#  uninstall-X:
#  install-X-symlink:
#
# Files will be installed to $(package.install.X.dest) using install
# arguments $(package.install.X.install-flags). All of these vars are
# set up by default, but may be customized:
#
#  package.install.bins.dest = $(prefix)/$(package.name)/bin
#  package.install.bins.install-flags = -m 0755
#
# Installation can be further customized by using $(call toc2.call.install...)
# and the related functions.

ifeq (,$(wildcard $(toc2.bins.installer)))
  toc2.bins.installer := $(call toc2.call.find-program,install-sh,$(toc2.home)/bin)
endif

ifeq (,$(wildcard $(toc2.bins.installer)))
$(error install.make requires that the variable toc2.bins.installer be set. Try $(toc2.home)/bin/install-sh.)
endif


########################################################################
# $(call toc2.call.install.grep_kludge,file_name)
# This is an ancient kludge force [un]install to silently fail without an
# error when passed an empty file lists. This was done because saner
# approaches to checking this failed to work on some older machines.
toc2.call.install.grep_kludge = echo $(1) "" | grep -q '[a-zA-Z0-9]' || exit 0

########################################################################
# $(call toc2.call.install,file_list,destdir[,install-sh-flags])
# Installs files $(1) to $(DESTDIR)$(2). $(3) is passed on to
# $(toc2.bins.installer).
toc2.call.install = $(call toc2.call.install.grep_kludge,$(1)); \
			tgtdir="$(DESTDIR)$(2)"; \
			test -d "$$tgtdir" || mkdir -p "$${tgtdir}" \
				|| { err=$$?; echo "$(@): mkdir -p $${tgtdir} failed"; exit $$err; }; \
			for b in $(1) ""; do test -z "$$b" && continue; \
				b=$$(basename $$b); \
				target="$${tgtdir}/$$b"; \
				cmp "$$target" "$$b" > /dev/null 2>&1  && continue; \
				cmd="$(toc2.bins.installer) $(3) $$b $$target"; echo $$cmd; $$cmd || exit; \
			done

########################################################################
# $(call toc2.call.uninstall,file_list,source_dir)
# removes all files listed in $(1) from target directory $(DESTDIR)$(2).
#
# Maintenance reminder:
# The while/rmdir loop is there to clean up empty dirs left over by
# the uninstall. This is very arguable but seems more or less
# reasonable. The loop takes care to stop when it reaches $(DESTDIR),
# since DESTDIR is presumably (but not necessarily) created by another
# authority.
toc2.call.uninstall =  $(call toc2.call.install.grep_kludge,$(1)); \
			tgtdir="$(DESTDIR)$(2)"; \
			test -e "$${tgtdir}" || exit 0; \
			for b in $(1) ""; do test -z "$$b" && continue; \
				fp="$${tgtdir}/$$b"; test -e "$$fp" || continue; \
				cmd="rm $$fp"; echo $$cmd; $$cmd || exit $$?; \
			done; \
			tgtdir="$(2)"; \
			while test x != "x$${tgtdir}" -a '/' != "$${tgtdir}" -a -d "$(DESTDIR)$${tgtdir}"; do \
				rmdir $(DESTDIR)$${tgtdir} 2>/dev/null || break; \
				echo "Removing empty dir: $(DESTDIR)$${tgtdir}"; \
				tgtdir=$${tgtdir%/*}; \
			done; true

# toc2.call.install-symlink call()able:
# works similarly to toc2.call.install, but symlinks back to the install source,
# instead of copying. Arg $3 is ignored.
# Note that symlinks must be linked to absolute paths here, because we cannot
# easily/reliably make a relative path from the target directory back to 
# the install source:
toc2.call.install-symlink = $(call toc2.call.install.grep_kludge,$(1)); \
			test -d $(2) || mkdir -p "$(2)" || \
				{ err=$$?; echo "$(@): mkdir -p $(2) failed"; exit $$err; }; \
			for b in $(1) ""; do test -z "$$b" && continue; \
				target=$(2)/$$b; \
				test $$target -ef $$b && continue; \
				echo "Symlinking $$target"; ln -s -f $$PWD/$$b $$target || exit $$?; \
			done

########################################################################
# toc2.call.install-dll: installs foo.so.X.Y.Z and symlinks foo.so,
# foo.so.X and foo.so.Y to it, in traditional/common Unix style.
# $1 = so name (foo.so)
# $2-4 = Major, Minor, Patch version numbers
# $5 = destination directory
toc2.call.install-dll =  $(call toc2.call.install.grep_kludge,$(1)); \
                        test -d $(5) || mkdir -p $(5) || exit; \
                        wholename=$(1).$(2).$(3).$(4); \
                        target=$(5)/$$wholename; \
			test $$wholename -ef $$target || { \
	                        echo "Installing/symlinking $$target"; \
				cmd="$(toc2.bins.installer) -s $$wholename $$target"; \
				$$cmd || exit $$?; \
			}; \
			cd $(5); \
			for i in $(1) $(1).$(2) $(1).$(2).$(3); do \
				test -e $$i && rm -f $$i; \
				cmd="ln -fs $$wholename $$i"; echo $$cmd; \
				$$cmd || exit $$?; \
			done
## symlinking method number 2:
##			{ set -x; \
##				ln -fs $(1).$(2).$(3).$(4) $(1).$(2).$(3); \
##				ln -fs $(1).$(2).$(3) $(1).$(2); \
##				ln -fs $(1).$(2) $(1); \
##			}

toc2.install.flags.nonbins = -m 0644
toc2.install.flags.bins = -s -m 0755
toc2.install.flags.bin-scripts = -m 0755
toc2.install.flags.dlls = -m 0755

install: subdirs-install
uninstall: subdirs-uninstall
install-symlink: subdirs-install-symlink

.PHONY: install-subdirs
install-subdirs: subdirs-install
.PHONY: install-subdirs-symlink
install-subdirs-symlink: subdirs-install-symlink
.PHONY: uninstall-subdirs
uninstall-subdirs: subdirs-uninstall

########################################################################
# $(eval $(call toc2.call.setup_install_rules,SET_NAME,dest_dir,install_flags))
define toc2.call.setup_install_rules
$(if $(1),,$(error toc2.call.setup_install_rules requires an install set name as $$1))
$(if $(2),,$(error toc2.call.setup_install_rules requires an installation path as $$2))

$(if $(package.install.$(1).dupecheck),$(error toc2.call.setup_install_rules: rules for $1 have already been created. \
	You cannot create them twice.))
package.install.$(1).dupecheck := 1
package.install.$(1).dest ?= $(2)
package.install.$(1).install-flags ?= $(3)

.PHONY: install-$(1)
install-$(1):
	@test x = "x$$(package.install.$(1))" && exit 0; \
	$$(call toc2.call.install,$$(package.install.$(1)),$$(package.install.$(1).dest),$$(package.install.$(1).install-flags))
install: install-$(1)

.PHONY: install-$(1)-symlink
install-$(1)-symlink:
	@test x = "x$$(package.install.$(1))" && exit 0; \
	$$(call toc2.call.install-symlink,$$(package.install.$(1)),$$(package.install.$(1).dest))

.PHONY: uninstall-$(1)
uninstall-$(1):
	@test x = "x$$(package.install.$(1))" && exit 0; \
	$$(call toc2.call.uninstall,$$(package.install.$(1)),$$(package.install.$(1).dest))
uninstall: uninstall-$(1)
endef
# set up the initial install locations and install flags:
toc2.install.target_basenames := bins sbins \
				bin-scripts \
				libs dlls \
				package_libs package_dlls \
				headers package_headers \
				package_data docs \
				man1 man2 man3 man4 \
				man5 man6 man7 man8 man9
$(eval $(call toc2.call.setup_install_rules,bins,$(prefix)/bin,$(toc2.install.flags.bins)))
$(eval $(call toc2.call.setup_install_rules,bin-scripts,$(prefix)/bin,$(toc2.install.flags.bin-scripts)))
$(eval $(call toc2.call.setup_install_rules,sbins,$(prefix)/sbin,$(toc2.install.flags.bins)))
$(eval $(call toc2.call.setup_install_rules,libs,$(prefix)/lib,$(toc2.install.flags.nonbins)))
$(eval $(call toc2.call.setup_install_rules,dlls,$(prefix)/lib,$(toc2.install.flags.dlls)))
$(eval $(call toc2.call.setup_install_rules,package_libs,$(prefix)/lib/$(package.name),$(toc2.install.flags.nonbins)))
$(eval $(call toc2.call.setup_install_rules,package_dlls,$(prefix)/lib/$(package.name),$(toc2.install.flags.dlls)))
$(eval $(call toc2.call.setup_install_rules,headers,$(prefix)/include,$(toc2.install.flags.nonbins)))
$(eval $(call toc2.call.setup_install_rules,package_headers,$(prefix)/include/$(package.name),$(toc2.install.flags.nonbins)))
$(eval $(call toc2.call.setup_install_rules,package_data,$(prefix)/share/$(package.name),$(toc2.install.flags.nonbins)))
$(eval $(call toc2.call.setup_install_rules,docs,$(prefix)/share/doc/$(package.name),$(toc2.install.flags.nonbins)))
# Set up man page entries...
$(foreach NUM,1 2 3 4 5 6 7 8 9,$(eval $(call \
	toc2.call.setup_install_rules,man$(NUM),man/man$(NUM),$(toc2.install.flags.nonbins))))