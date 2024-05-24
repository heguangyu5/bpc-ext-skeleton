<?php

echo SKEL_CONST_INT, "\n";
echo SKEL_CONST_FLOAT, "\n";
echo SKEL_CONST_STRING, "\n";

skel_sayhi();
skel_sayhi_with_name("World");
skel_sayhi_with_name_default_value();
skel_sayhi_with_name_default_value("Bob");

echo "----------------\n";

skel_sayhi_with_name_ref($name);
var_dump($name);

echo "----------------\n";

skel_sayhi_with_name_ref_default_value();
skel_sayhi_with_name_ref_default_value($name);
var_dump($name);

echo "----------------\n";

skel_sayhi_with_name_optional();
skel_sayhi_with_name_optional("World");

echo "----------------\n";

var_dump(skel_c_strtoupper("world"));
var_dump(skel_c_strtoupper_at("world", 2));

echo "----------------\n";

$names = array('A', 'B', 'C', 'D', 'E');
foreach ($names as $name) {
	$handle = skel_resource_new($name);
	var_dump($handle);
	skel_resource_say($handle, "I", "am", "skel", "resouce", $name);
}
