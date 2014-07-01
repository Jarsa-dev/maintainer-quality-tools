#!/bin/bash

#
# USAGE
# travis_run_tests.sh VERSION DB_NAME [dependency_repo_1...]

version=$1
database=$2
shift 2

case ${version} in 
    7.0)
        options="--test-enable"
        ;;
    6.1)
        options=""
        ;;
    *)
        options=""
        ;;
esac

addons_path=/usr/share/pyshared/openerp/addons

for repo in "$@" $TRAVIS_BUILD_DIR; 
do
    addons_path=${repo},${addons_path}
done

echo "working in $TRAVIS_BUILD_DIR"
ls ${TRAVIS_BUILD_DIR}
for name in $(ls ${TRAVIS_BUILD_DIR});
do
    echo "considering $name"
    stripped_name=$(echo ${name} | sed 's/_unported$//')
    if [[ -d ${TRAVIS_BUILD_DIR}/${name} && ${name} = ${stripped_name} && -e ${TRAVIS_BUILD_DIR}/${name}/__init__.py ]]
    then
        if [ -v tested_addons ]
        then
            tested_addons=${name},${tested_addons}
        else
            tested_addons=$name
        fi
    else
        echo " -> probably not an addon"
    fi
done

psql -c 'create database openerp_test with owner openerp;' -U postgres
# setup the base module without running th
/usr/bin/openerp-server --db_user=openerp --db_password=admin -d ${database} --stop-after-init -i base
command="/usr/bin/openerp-server --db_user=openerp --db_password=admin -d ${database} ${options} \
--stop-after-init  --log-level test \
--addons-path=${addons_path} \
-i ${tested_addons}"

echo ${command}
coverage run $command | tee stdout.log

if $(grep -v mail stdout.log | grep -q "At least one test failed when loading the modules.")
then
    exit 1
else
    exit 0
fi

