use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# Blah!

WriteMakefile(
			  'NAME'	=> 'POE::Filter::Zlib',
			  'PREREQ_PM' => {
							  'POE'    => 0.31,
							  'Compress::Zlib' => 1.34,
							  'Carp' => 0,
							 },
			  'VERSION_FROM' => 'lib/POE/Filter/Zlib.pm', # finds $VERSION
			  'dist' => { 'COMPRESS' => 'gzip --best' },
			 );
