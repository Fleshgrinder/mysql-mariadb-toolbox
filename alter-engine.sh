#!/bin/sh

# -----------------------------------------------------------------------------
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or distribute
# this software, either in source code form or as a compiled binary, for any
# purpose, commercial or non-commercial, and by any means.
#
# In jurisdictions that recognize copyright laws, the author or authors of this
# software dedicate any and all copyright interest in the software to the
# public domain. We make this dedication for the benefit of the public at large
# and to the detriment of our heirs and successors. We intend this dedication
# to be an overt act of relinquishment in perpetuity of all present and future
# rights to this software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Alter engines of all tables in a database.
#
# AUTHOR:    Richard Fussenegger <richard@fussenegger.info>
# COPYRIGHT: 2015 Richard Fussenegger
# LICENSE:   http://unlicense.org/ PD
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
#                                                                      DEFAULTS
# -----------------------------------------------------------------------------

# Default engine to convert tables to.
ENGINE=InnoDB

# Default password for authentification.
PASSWORD=

# Default user name for authentification.
USER=root

# -----------------------------------------------------------------------------
#                                                              SYSTEM VARIABLES
# -----------------------------------------------------------------------------

# For more information on shell colors and other text formatting see:
# http://stackoverflow.com/a/4332530/1251219
readonly RED=$(tput bold; tput setaf 1)
readonly GREEN=$(tput bold; tput setaf 2)
readonly YELLOW=$(tput bold; tput setaf 3)
readonly UNDERLINE=$(tput smul)
readonly NORMAL=$(tput sgr0)

# The script is not silent by default.
SILENT=false

# -----------------------------------------------------------------------------
#                                                                     FUNCTIONS
# -----------------------------------------------------------------------------

# Print the script usage.
usage()
{
    cat << EOT
Usage: ${UNDERLINE}${0##*/}${NORMAL} ${GREEN}[OPTION]...${NORMAL} ${YELLOW}DATABASE${NORMAL}
Alter engines of all tables in the given database. Note that the database arg-
ument is mandatory for all options.

    -h             Display this help and exit.
    -e [ENGINE]    The engine to convert to, defaults to ${YELLOW}InnoDB${NORMAL}.
    -p [PASSWORD]  The password for ${YELLOW}-u${NORMAL}, defaults to no password. You may want
                       to enter the password directly in the script, since it
                       will be available in your shell history.
    -s             Be silent and do not print any informational text.
    -u [NAME]      The database user name, defaults to ${YELLOW}root${NORMAL}.

Report bugs to richard@fussenegger.info
GitHub repository: https://github.com/Fleshgrinder/mysql-configuration
For complete documentation see README file.
EOT
}

# -----------------------------------------------------------------------------
#                                                                  SCRIPT LOGIC
# -----------------------------------------------------------------------------

# Handle input options.
while getopts ':he:p:su:' OPT
do
    case "${OPT}" in
        h|[?]) usage && exit 0 ;;
        e) ENGINE="${OPTARG}" ;;
        p) PASSWORD="${OPTARG}" ;;
        s) SILENT=true ;;
        u) USER="${OPTARG}" ;;
        \?) printf -- '%sInvalid option -%s\n' "${RED}" "${OPTARG}${NORMAL}" && exit 64 ;;
        :) printf -- '%sOption %s requires an argument.%s\n' "${RED}" "${OPTARG}" "${NORMAL}" && exit 65 ;;
        *) usage && exit 66 ;;
    esac

    shift $(( $OPTIND - 1 ))
done

# Handle optional end-of-options marker.
if [ "${1}" = '--' ]
    then shift $(( $OPTIND - 1 ))
fi

# Make sure the database name was given as argument.
if [ ${#} -ne 1 ]
    then printf -- '%sMissing database argument.\n%s' "${RED}" "${NORMAL}" && usage && exit 67
fi

# Make sure the desired engine is available.
mysql --batch --silent --execute='SHOW ENGINES' --password="${PASSWORD}" --user="${USER}" | grep "^${ENGINE}\s\+\(YES\|DEFAULT\)" 2>/dev/null 1>/dev/null
if [ "${?}" -ne 0 ]
    then printf -- '[%sfail%s] Storage engine %s is not supported.\n' "${RED}" "${NORMAL}" "${YELLOW}${ENGINE}${NORMAL}" && exit 68
fi

# Make sure the database actually exists.
DATABASE=$(mysql --batch --silent --execute="SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${1}'" --password="${PASSWORD}" --user="${USER}")
if [ "${DATABASE}" != "${1}" ]
    then printf -- '[%sfail%s] Database %s does not exist.\n' "${RED}" "${NORMAL}" "${YELLOW}${1}${NORMAL}" && exit 69
fi

# Inform the user that the tables are about to be altered.
[ ${SILENT} = false ] && printf -- 'Changing all tables from their current engine to %s in database %s ...\n' "${YELLOW}${ENGINE}${NORMAL}" "${YELLOW}${DATABASE}${NORMAL}"

# Alter all tables in the given database.
for TABLE in $(mysql --batch --execute='SHOW TABLES' --skip-column-names --password="${PASSWORD}" --user="${USER}" -- "${1}")
do
    OUTPUT=$(mysql --batch --silent --execute="ALTER TABLE \`${TABLE}\` ENGINE=${ENGINE}" --password="${PASSWORD}" --user="${USER}" -- "${DATABASE}" 2>&1)
    if printf -- '%s' "${OUTPUT}" | grep '^ERROR' 2>/dev/null 1>/dev/null
        then printf -- '%s\n' "${OUTPUT}" && exit 70
    fi
    [ ${SILENT} = false ] && printf -- '[%sok%s] %s ...\n' "${GREEN}" "${NORMAL}" "${YELLOW}${TABLE}${NORMAL}"
done

# Inform the user that all tables were altered.
[ ${SILENT} = false ] && printf -- '[%sok%s] Finished changing all tables to InnoDB!\n' "${GREEN}" "${NORMAL}"

exit 0
