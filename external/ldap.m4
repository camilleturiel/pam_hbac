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
    dnl dependency list incrementally.
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
    AC_CHECK_LIB(pthread, pthread_create,
                 [LDAP_EXTRA_LIBS="$LDAP_EXTRA_LIBS -lpthread"])

    dnl Build the full library list using full paths for libldap/liblber so
    dnl the correct OpenLDAP is always chosen — on AIX both IBM LDAP and
    dnl OpenLDAP install a libldap.a, and -lldap may resolve to the wrong one
    dnl regardless of the -L search path order.
    LDAP_DYNAMIC_LIBS=`echo "$LDAP_EXTRA_LIBS" | sed 's/-llber//g'`
    OPENLDAP_LIBS="${OPENLDAP_LIBDIR}/libldap.a ${OPENLDAP_LIBDIR}/liblber.a ${LDAP_DYNAMIC_LIBS}"

    dnl Try linking ldap_initialize using the same full-path form that the
    dnl production build uses.  AC_TRY_LINK is used (not AC_CHECK_LIB) to
    dnl avoid caching a result based on -lldap that might have resolved to a
    dnl different installation.
    with_ldap=no
    AC_MSG_CHECKING([for ldap_initialize in ${OPENLDAP_LIBDIR}/libldap.a])
    SAVE_LIBS2=$LIBS
    LIBS="$LIBS ${OPENLDAP_LIBS}"
    AC_TRY_LINK([#include <ldap.h>],
                [ldap_initialize(0, 0);],
                [with_ldap=yes; AC_MSG_RESULT([yes])],
                [AC_MSG_RESULT([no])])
    LIBS=$SAVE_LIBS2

    if test "$with_ldap" != "yes"; then
        AC_MSG_ERROR([OpenLDAP 2.6.x libraries not found (requires ldap_initialize).
            Link test failed with: ${OPENLDAP_LIBS}
            Check config.log for details.])
    fi

    LIBS="$LIBS $OPENLDAP_LIBS"
    AC_CHECK_FUNCS([ldap_start_tls])

    CFLAGS=$SAVE_CFLAGS
    LIBS=$SAVE_LIBS
    LDFLAGS=$SAVE_LDFLAGS

    AC_SUBST(OPENLDAP_LIBS)
    AC_SUBST(OPENLDAP_CFLAGS)
])
