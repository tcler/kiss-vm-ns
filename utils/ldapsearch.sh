#!/bin/bash
#ldapsearch example
#ref:
#  https://www.rfc-editor.org/rfc/rfc4515
#  https://tylersguides.com/guides/ldap-search-filters/

command -v ldapsearch &>/dev/null || {
	echo "{WARN} command 'ldapsearch' is required(package openldap-clients on Fedora/RHEL/CentOS)" >&2
	exit
}

ldapServer=ldap://ldap.corp.redhat.com
trim() {
	local var="$*"
	var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
	printf '%s' "$var"
}

uid=$(trim "${1}")
cn=$(trim "${2}")
shift 2
[[ -z "$uid" ]] && uid=$(klist | awk -F'[@ ]+' '/Default principal:/{print $3}')
[[ -z "$uid" ]] && uid=$USER
[[ -z "$cn" ]] && cn=*

#ldapsearch -x -H $ldapServer -LLL -b 'dc=redhat,dc=com' "(&(rhatLegalEntity=Red Hat Software *Beijing*)(l=Xi'an*)(cn=*)(uid=*))"  uid cn l
echo "{DEBUG} filter: (uid=$uid)(cn=$cn), attr: $*" >&2
ldapsearch -x -H $ldapServer -LLL -b 'dc=redhat,dc=com' "(&(rhatLegalEntity=*)(l=*)(cn=${cn})(uid=${uid}))" "$@"
