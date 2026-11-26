<?php
// Effective PHP settings for tests/php/security.sh (phpinfo() is disabled in the image)
header("Content-Type: text/plain");
echo "cgi.fix_pathinfo=", ini_get("cgi.fix_pathinfo"), "\n";
