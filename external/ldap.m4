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

    AC_CHECK_LIB(ldap, ldap_initialize, with_ldap=yes)
    if test "$with_ldap" != "yes"; then
        AC_MSG_ERROR([OpenLDAP 2.6.x libraries not found (requires ldap_initialize)])
    fi
    OPENLDAP_LIBS="${OPENLDAP_LIBS} -lldap"

    AC_CHECK_LIB(lber, ber_pvt_opt_on, with_ldap_lber=yes)
    if test "$with_ldap_lber" = "yes" ; then
        OPENLDAP_LIBS="${OPENLDAP_LIBS} -llber"
    fi

    LIBS="$LIBS $OPENLDAP_LIBS"
    AC_CHECK_FUNCS([ldap_start_tls])

    CFLAGS=$SAVE_CFLAGS
    LIBS=$SAVE_LIBS
    LDFLAGS=$SAVE_LDFLAGS

    AC_SUBST(OPENLDAP_LIBS)
    AC_SUBST(OPENLDAP_CFLAGS)
])
