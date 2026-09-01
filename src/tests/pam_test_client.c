/*
    Authors:
        Sumit Bose <sbose@redhat.com>
        Jakub Hrozek <jhrozek@redhat.com>

    Copyright (C) 2009 Red Hat

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "pam_hbac_compat.h"

#define PAM_TEST_DFL_SVC    "sshd"
#define PAM_TEST_DFL_USER   "beef"

#ifdef HAVE_SECURITY_PAM_MISC_H
# include <security/pam_misc.h>
#elif defined(HAVE_SECURITY_OPENPAM_H)
# include <security/openpam.h>
#endif

#ifdef HAVE_SECURITY_PAM_MISC_H
static struct pam_conv conv = {
    misc_conv,
    NULL
};
#elif defined(HAVE_SECURITY_OPENPAM_H)
static struct pam_conv conv = {
    openpam_ttyconv,
    NULL
};
#else
int dummy_pam_conv(int num_msg,
                   struct pam_message **msgm,
                   struct pam_response **response,
                   void *appdata_ptr)
{
    return PAM_SUCCESS;
}

static struct pam_conv conv = {
    dummy_pam_conv,
    NULL
};
#endif

/* Explain the account-stack result in pam_hbac terms.  The value is the
 * aggregated result of the account stack for the service, but when pam_hbac
 * is the deciding module these are the outcomes its current flow produces.
 */
static const char *
explain_acct_result(int ret)
{
    switch (ret) {
    case PAM_SUCCESS:
        return "access granted by a matching HBAC rule";
    case PAM_PERM_DENIED:
        return "denied: no HBAC rule matched, or host/service unknown to IPA";
    case PAM_USER_UNKNOWN:
        return "not an IPA user (local-only or unresolved), flag unset";
    case PAM_IGNORE:
        return "not an IPA user, deferred to other modules (ignore_unknown_user)";
    case PAM_AUTHINFO_UNAVAIL:
        return "could not reach the IPA LDAP server";
    case PAM_ACCT_EXPIRED:
        return "account expired - from another stack module (pam_hbac never "
               "returns this)";
    case PAM_ABORT:
    case PAM_SYSTEM_ERR:
        return "internal error";
    default:
        return "see message above";
    }
}

int main(int argc, char *argv[])
{
    pam_handle_t *pamh;
    char *user;
    char *svc;
    int ret;

    if (argc > 1 && (strcmp(argv[1], "-h") == 0
                     || strcmp(argv[1], "--help") == 0)) {
        fprintf(stdout, "usage: %s [user] [service]\n"
                        "  defaults: user=%s service=%s\n"
                        "  must be run as root\n"
                        "  exit code is the pam_acct_mgmt() return code\n",
                argv[0], PAM_TEST_DFL_USER, PAM_TEST_DFL_SVC);
        return 0;
    }

    /* Account management reads privileged data (shadow/security databases and
     * the module's LDAP bind credentials), so pam_acct_mgmt() only returns
     * meaningful results as root.  Fail early with a clear message otherwise. */
    if (getuid() != 0) {
        fprintf(stderr, "%s: must be run as root\n", argv[0]);
        return 1;
    }

    if (argc == 1) {
        fprintf(stdout, "missing user and service name, using default\n");
        user = strdup(PAM_TEST_DFL_USER);
        svc = strdup(PAM_TEST_DFL_SVC);
    } else if (argc == 2) {
        fprintf(stdout, "using first argument as user and default service name\n");
        user = strdup(argv[1]);
        svc = strdup(PAM_TEST_DFL_SVC);
    } else {
        user = strdup(argv[1]);
        svc = strdup(argv[2]);
    }

    if (user == NULL || svc == NULL) {
        fprintf(stderr, "out of memory\n");
        free(user);
        free(svc);
        return PAM_BUF_ERR;
    }

    fprintf(stdout, "service: %s\nuser: %s\n", svc, user);

    ret = pam_start(svc, user, &conv, &pamh);
    if (ret != PAM_SUCCESS) {
        fprintf(stdout, "pam_start: %s\n", pam_strerror(pamh, ret));
        free(user);
        free(svc);
        return ret;
    }

    fprintf(stdout, "testing pam_acct_mgmt()\n");
    ret = pam_acct_mgmt(pamh, 0);
    fprintf(stdout, "pam_acct_mgmt [%d]: %s\n", ret, pam_strerror(pamh, ret));
    fprintf(stdout, "result: %s\n", explain_acct_result(ret));

    pam_end(pamh, ret);
    free(user);
    free(svc);

    /* Propagate the PAM result so the caller can script on it, e.g.
     *   ./pam_test_client fpo99 sshd; echo $?
     */
    return ret;
}
