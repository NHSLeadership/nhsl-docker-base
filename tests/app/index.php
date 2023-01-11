<?php

echo "<b>Test files: </b>";
echo "<a href=\"test/files/img1.png\">PNG</a> - ";
echo "<a href=\"test/files/file.pdf\">PDF</a> - ";
echo "<a href=\"test/files/file.docx\">DOCX</a> - ";
echo "<a href=\"test/content.html\">Test site.</a>";


echo "<h3>Request Headers:</h3>";
$headers =  getallheaders();
foreach($headers as $key=>$val){
  echo $key . ': ' . $val . '<br/>';
}

echo "<h3>Server Headers:</h3>";
foreach($_SERVER as $key=>$val) {
    echo $key . ': ' . $val . '<br/>';
}

phpinfo();