#!/bin/sh

cd ~

echo '***Make sure you run `sudo chown youruser ~/.composer/ -R` before running this script***'
echo

echo 'Cloning local_codechecker repo...'
echo
git clone git://github.com/moodlehq/moodle-local_codechecker.git

echo 'Installing squizlabs/php_codesniffer globally...'
echo
composer global require squizlabs/php_codesniffer=2.* 

echo 'Copying moodle coding standards to php_codesniffer...'
echo
cp moodle-local_codechecker/moodle/ ~/.config/composer/vendor/squizlabs/php_codesniffer/CodeSniffer/Standards/ -r
cp moodle-local_codechecker/PHPCompatibility/ ~/.config/composer/vendor/squizlabs/php_codesniffer/CodeSniffer/Standards/ -r

echo 'Creating bash alias codecheck...'
echo
unalias codecheck
alias codecheck='f(){ php ~/.config/composer/vendor/squizlabs/php_codesniffer/scripts/phpcs --standard=moodle --report="${2:-full}" ./"${1}"; }; f'

echo 'Finished'
echo 
echo 'Usage: cd path/to/moodle; codecheck /path/to/plugin reporttype'
echo 'Example: codecheck /local/openid_connect'
echo 'Example: codecheck /local/openid_connect summary'

