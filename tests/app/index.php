<?php

echo "<b>Test files: </b>";
echo "<a href=\"test/files/img1.png\">PNG</a> - ";
echo "<a href=\"test/files/file.pdf\">PDF</a> - ";
echo "<a href=\"test/files/file.docx\">DOCX</a> - ";
echo "<a href=\"test/content.html\">Test site.</a>";
echo "<br/><br/>";

echo "<b>PHP Version:</b> ".phpversion()."<br/>";
echo "<b>Process user:</b> ".posix_getpwuid(posix_geteuid())['name'];

echo "<h3>Request Headers:</h3>";
foreach(getallheaders() as $key=>$val){
  echo "<b>".$key."</b>" . ': ' . $val . '<br/>';
}

echo "<h3>Server Headers:</h3>";
foreach($_SERVER as $key=>$val) {
    echo "<b>".$key."</b>" . ': ' . $val . '<br/>';
}

phpinfo();