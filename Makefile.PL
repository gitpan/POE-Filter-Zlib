use inc::Module::Install;
name 'POE-Filter-Zlib';
author 'Chris Williams <chris@bingosnet.co.uk>';
license 'perl';
version_from 'lib/POE/Filter/Zlib.pm';
requires 'Carp' => 0;
requires 'Compress::Zlib' => 1.34;
requires 'POE'    => 0.38;
WriteAll();
