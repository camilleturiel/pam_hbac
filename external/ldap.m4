dnl check for OpenLDAP 2.6.x libraries
AC_DEFUN([AM_CHECK_OPENLDAP],
[
    for p in /usr/include/openldap /usr/local/include /opt/freeware/include; do
        if test -f "${p}/ldap.h"; then
            OPENLDAP_CFLAGS="${OPENLDAP_CFLAGS} -I${p}"
            break;
        fi
    done

    dnl On AIX, shared libraries may only exist as libldap.a (archive with
    dnl shared members) or versioned libldap.so.N (no unversioned symlink).
    dnl Check for any of these variants.
    for p in /usr/lib/openldap /usr/local/lib /opt/freeware/lib; do
        if test -f "${p}/libldap.a" || ls "${p}"/libldap.so* >/dev/null 2>&1; then
            OPENLDAP_LIBS="-L${p}"
            break;
        fi
    done

    SAVE_CFLAGS=$CFLAGS
    SAVE_LIBS=$LIBS
    SAVE_LDFLAGS=$LDFLAGS
    CFLAGS="$CFLAGS $OPENLDAP_CFLAGS"
    LIBS="$LIBS $OPENLDAP_LIBS"
    dnl AC_CHECK_LIB uses LDFLAGS for the link test, so the -L path must be there
    LDFLAGS="$LDFLAGS $OPENLDAP_LIBS"

    AC_CHECK_HEADERS([lber.h])
    AC_CHECK_HEADERS([ldap.h],
                    [],
                    AC_MSG_ERROR([could not locate <ldap.h>]),
                    [ #if HAVE_LBER_H
                    #include <lber.h>
                    #endif
                    ])

    dnl Check lber first -- on AIX the linker is strict and libldap depends
    dnl on liblber (and possibly libssl/libcrypto), so the ldap link test
    dnl needs these as extra dependencies.
    LDAP_EXTRA_LIBS=""
    AC_CHECK_LIB(lber, ber_pvt_opt_on, [LDAP_EXTRA_LIBS="-llber"])

    dnl Try linking ldap_initialize with its dependencies.
    dnl Use AC_TRY_LINK instead of AC_CHECK_LIB to avoid caching issues
    dnl when retrying with different dependency sets.
    with_ldap=no

    dnl First try: -lldap + lber
    AC_MSG_CHECKING([for ldap_initialize in -lldap])
    SAVE_LIBS2=$LIBS
    LIBS="$LIBS -lldap $LDAP_EXTRA_LIBS"
    AC_TRY_LINK([#include <ldap.h>],
                [ldap_initialize(0, 0);],
                [with_ldap=yes; AC_MSG_RESULT([yes])],
                [AC_MSG_RESULT([no])])
    LIBS=$SAVE_LIBS2

    dnl Second try: also add -lssl -lcrypto (OpenLDAP built with TLS)
    if test "$with_ldap" != "yes"; then
        AC_MSG_CHECKING([for ldap_initialize in -lldap (with -lssl -lcrypto)])
        SAVE_LIBS2=$LIBS
        LIBS="$LIBS -lldap $LDAP_EXTRA_LIBS -lssl -lcrypto"
        AC_TRY_LINK([#include <ldap.h>],
                    [ldap_initialize(0, 0);],
                    [with_ldap=yes; LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -lssl -lcrypto"; AC_MSG_RESULT([yes])],
                    [AC_MSG_RESULT([no])])
        LIBS=$SAVE_LIBS2
    fi

    if test "$with_ldap" != "yes"; then
        AC_MSG_ERROR([OpenLDAP 2.6.x libraries not found (requires ldap_initialize)])
    fi

    OPENLDAP_LIBS="${OPENLDAP_LIBS} -lldap ${LDAP_EXTRA_LIBS}"

    LIBS="$LIBS $OPENLDAP_LIBS"
    AC_CHECK_FUNCS([ldap_start_tls])

    CFLAGS=$SAVE_CFLAGS
    LIBS=$SAVE_LIBS
    LDFLAGS=$SAVE_LDFLAGS

    AC_SUBST(OPENLDAP_LIBS)
    AC_SUBST(OPENLDAP_CFLAGS)
])
