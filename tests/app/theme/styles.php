<?php
// Stands in for Moodle's theme/styles.php, which is served with slash
// arguments (theme/styles.php/<theme>/<rev>/all). tests/php/security.sh
// checks a request like that reaches this script with the right PATH_INFO.
header("Content-Type: text/plain");
echo "SCRIPT_NAME=", $_SERVER["SCRIPT_NAME"] ?? "", "\n";
echo "PATH_INFO=", $_SERVER["PATH_INFO"] ?? "", "\n";
