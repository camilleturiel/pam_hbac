#!/bin/bash
# All steps in building pam_hbac
# -g - GCC compiler instead of default (ibm-clang)
# -r - build RPM package
# -s - execute rpm related commands with "sudo" (Normally needed because of file permissions)
# -7 - target AIX 7.3 instead of default AIX 7.2
export PATH=${PATH}:/opt/freeware/bin  # This is for the GIT command

aix_ver="7.2"
aix_define="_AIX72"

for arg in "$@"
do
  if [ "$arg" == "-g" ]; then
    gcc_f="gcc"
  elif [ "$arg" == "-r" ]; then
    rpm_f="rpm"
  elif [ "$arg" == "-s" ]; then
    SUDO="sudo -E"
  elif [ "$arg" == "-7" ]; then
    aix_ver="7.3"
    aix_define="_AIX73"
  fi
done

# Cleanup - the best is "rm -rf", but this works
rm -rf .libs > rmlibs.mlog
find src -name '.*'|grep -e deps -e dirstamp -e libs|xargs rm -rf
git clean -fdx >git_clean.mlog

#** git checkout (needed if you do "rm -rf")
git pull
git ls-files --deleted  | xargs git checkout
#We have now restored all files from the repository and deleted all files not in GIT
#changed files are not overwritten


#                  **** Set up compiler and flags   ****
#  The following lines are from README.AIX
export M4=/usr/opt/freeware/bin/m4
export LDFLAGS="-L/usr/lib"
export LIBS="-lpthread"

# Compiler specific section
if [ -z "$gcc_f" ]; then #(not GCC)
  export PATH=/opt/IBM/openxlC/17.1.2/bin/:/opt/IBM/openxlC/17.1.1/bin/:$PATH # ibm-clang compiler
  export CC=ibm-clang
  export CFLAGS="-DSYSV -D${aix_define} -D_ALL_SOURCE -DFUNCPROTO=15 -Wno-error=int-conversion -O2"
  export LDFLAGS="${LDFLAGS} -L/opt/freeware/lib"   #Needed for libglib-2.0.a, perhaps more
  export CFLAGS="${CFLAGS} -I/opt/freeware/include  -target powerpc-ibm-aix${aix_ver}.0.0"
else
  export CC=gcc #normally picked up "automatically"
  # Do not hard-code -DHAVE_LDAP_STR2DN; let configure detect LDAP capabilities.
  # OpenLDAP 2.6.x removed ldap_str2dn/ldap_dnfree; the built-in fallback
  # in pam_hbac_ldap_compat.c will be used automatically when not detected.
  export CFLAGS="-Wno-implicit-function-declaration"
  export LDFLAGS="${LDFLAGS}  -L/opt/freeware/lib " #Cleans up pathnames like  /opt/freeware/lib/gcc/powerpc-ibm-aix7.3.0.0/10/../../../
fi
#export LDFLAGS=" -L/put/front ${LDFLAGS}" # If needed for somewhere to place libraries "in front" in search path

CC_FP=`which ${CC}`
echo "Compiler: ${CC_FP}   *****************************************************"
echo "Target:   AIX ${aix_ver}   *****************************************************"

autoupdate
autoreconf -if|tee autoreconf.mlog
echo "***************** C O N F I G U R E **********************************************"
 # From README.AIX - --with-pammoddir is not in the previous README of this project.
./configure --sysconfdir=/etc/security/ldap \
            --with-pammoddir=/usr/lib/security --disable-man-pages|tee configure.mlog



if [ -n "$rpm_f" ]; then
  echo "RPM BUILD         ********************************************************"
  make dist
  $SUDO cp pam_hbac-1.*.gz /opt/freeware/src/packages/SOURCES/
  $SUDO rpmbuild  --target=ppc-ibm-aix${aix_ver} -vv -ba rpm/pam_hbac.spec|tee rpmbuild.mlog
else
    echo "LOCAL BUILD (NO RPM)  *****************************************************"
	make -s > make.mlog 2>&1
fi
