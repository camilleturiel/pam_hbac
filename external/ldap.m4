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
    OPENLDAP_LIBDIR=""
    for p in /usr/lib/openldap /usr/local/lib /opt/freeware/lib; do
        if test -f "${p}/libldap.a" || ls "${p}"/libldap.so* >/dev/null 2>&1; then
            OPENLDAP_LIBDIR="${p}"
            break;
        fi
    done

    if test -z "$OPENLDAP_LIBDIR"; then
        AC_MSG_ERROR([Cannot find libldap.a or libldap.so])
    fi

    SAVE_CFLAGS=$CFLAGS
    SAVE_LIBS=$LIBS
    SAVE_LDFLAGS=$LDFLAGS
    CFLAGS="$CFLAGS $OPENLDAP_CFLAGS"
    LIBS="$LIBS -L${OPENLDAP_LIBDIR}"
    LDFLAGS="$LDFLAGS -L${OPENLDAP_LIBDIR}"

    AC_CHECK_HEADERS([lber.h])
    AC_CHECK_HEADERS([ldap.h],
                    [],
                    AC_MSG_ERROR([could not locate <ldap.h>]),
                    [ #if HAVE_LBER_H
                    #include <lber.h>
                    #endif
                    ])

    dnl On AIX the linker requires all transitive dependencies to be
    dnl specified.  libldap.a depends on: liblber, libsasl2, libssl,
    dnl libcrypto, libpthread.  Probe for each one and build the
    dnl dependency list incrementally, then use AC_TRY_LINK (which
    dnl does not cache) to test ldap_initialize with all of them.
    LDAP_EXTRA_LIBS=""
    dnl ber_pvt_opt_on was removed in OpenLDAP 2.6.x; use ber_alloc_t instead
    AC_CHECK_LIB(lber, ber_alloc_t,
                 [LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -llber"])
    AC_CHECK_LIB(sasl2, sasl_client_init,
                 [LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -lsasl2"])
    AC_CHECK_LIB(ssl, SSL_CTX_new,
                 [LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -lssl"])
    AC_CHECK_LIB(crypto, EVP_EncryptInit,
                 [LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -lcrypto"])

    dnl Try linking ldap_initialize with all discovered dependencies.
    dnl Use AC_TRY_LINK to avoid caching issues with AC_CHECK_LIB.
    with_ldap=no
    AC_MSG_CHECKING([for ldap_initialize in -lldap])
    SAVE_LIBS2=$LIBS
    LIBS="$LIBS -lldap $LDAP_EXTRA_LIBS"
    AC_TRY_LINK([#include <ldap.h>],
                [ldap_initialize(0, 0);],
                [with_ldap=yes; AC_MSG_RESULT([yes])],
                [AC_MSG_RESULT([no])])
    LIBS=$SAVE_LIBS2

    if test "$with_ldap" != "yes"; then
        AC_MSG_ERROR([OpenLDAP 2.6.x libraries not found (requires ldap_initialize).
            Link test failed with: -lldap $LDAP_EXTRA_LIBS
            Check config.log for details.])
    fi

    dnl Link libldap.a and liblber.a statically by full path so that
    dnl pam_hbac.so does not depend on a runtime -lldap/-llber resolution
    dnl (which could pick up the wrong library, e.g. IBM LDAP in /usr/lib).
    dnl The remaining transitive dependencies (sasl2, ssl, crypto) stay dynamic.
    OPENLDAP_STATIC=""
    if test -f "${OPENLDAP_LIBDIR}/libldap.a"; then
        OPENLDAP_STATIC="${OPENLDAP_LIBDIR}/libldap.a"
    fi
    if test -f "${OPENLDAP_LIBDIR}/liblber.a"; then
        OPENLDAP_STATIC="${OPENLDAP_STATIC} ${OPENLDAP_LIBDIR}/liblber.a"
    fi

    dnl Remove -llber from LDAP_EXTRA_LIBS since liblber.a is linked statically
    LDAP_DYNAMIC_LIBS=`echo "$LDAP_EXTRA_LIBS" | sed 's/-llber//g'`

    if test -n "$OPENLDAP_STATIC"; then
        OPENLDAP_LIBS="${OPENLDAP_STATIC} ${LDAP_DYNAMIC_LIBS}"
        AC_MSG_NOTICE([Linking libldap/liblber statically from ${OPENLDAP_LIBDIR}])
    else
        OPENLDAP_LIBS="-L${OPENLDAP_LIBDIR} -lldap ${LDAP_EXTRA_LIBS}"
        AC_MSG_NOTICE([Linking libldap/liblber dynamically])
    fi

    LIBS="$LIBS $OPENLDAP_LIBS"
    AC_CHECK_FUNCS([ldap_start_tls])

    CFLAGS=$SAVE_CFLAGS
    LIBS=$SAVE_LIBS
    LDFLAGS=$SAVE_LDFLAGS

    AC_SUBST(OPENLDAP_LIBS)
    AC_SUBST(OPENLDAP_CFLAGS)
])
