<?php
/**
 * Full text search on a database to find a string.
 * NOTE: This version only works on postgres. I'll write a mysql one if and when I need to do it.
 */
define('CLI_SCRIPT', true);
require __DIR__ . '/config.php';
require_once($CFG->libdir . '/clilib.php');

list($options, $unrecognized) = cli_get_params(
    array(
        'help'    => false,
        'search'    => false
    ),
    array(
        's' => 'search',
        'h' => 'help'
    )
);

error_reporting(E_ALL | E_STRICT);
ini_set('display_errors', 1);

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized), 2);
}

if ($options['help']) {
    $help =
        "Does a full search on the POSTGRES database for a string and returns any record it finds containing it.
        
        Example use: php fullsearchpgsql.php --search=\"my search term\"

Options:
-h, --help            Print out this help
-s, --search          The search string

";

    echo $help;
    exit(0);
}

if (!$options['search'] || strlen(trim($options['search'])) == 0) {
    die("Please specify a search string: php fullsearchpgsql.php -s=\"my search term\"\n");
}

$alltables = $DB->get_records_sql("select table_name 
                                from information_schema.tables
                                where table_schema = 'public' and table_name like :prefix", [
    'prefix' => $CFG->prefix . '%',
]);

$tables = [];
foreach ($alltables as $table) {
    $tables[] = str_replace($CFG->prefix, '', $table->table_name);
}

foreach ($tables as $table) {

    mtrace($table);
    mtrace(str_repeat('=', 10));
    $table = '{' . $table . '}';

    $find = $DB->get_records_sql("SELECT t.* FROM {$table} t WHERE (t.*)::text LIKE :search", [
        'search' => '%' . $options['search'] . '%'
    ]);

    if ($find) {
        foreach ($find as $found) {
            mtrace("Found \"{$options['search']}\" in table $table record ({$found->id})");
        }
    }

}

