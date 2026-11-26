#!/usr/bin/perl -w

###############################################################################
#
# Version:	2.5
# Date:		2016-04-19
# Author:	Jan Heinecke
# Filename:	KMbeuEmpPS.pl
#
# ###added encryption support

# requires Cups v1.3 (or newer)
#
# supported features
# - Secure Print
# - BoxPrint
# - ID&Print  (public user when no authentication is set)
# - Authentication MFP / Server
# - PSES Authentication
# - AccountTrack
# - CopySecurity
# - Date/Time Stamp
# - Page Number Stamp
# - page logging (in cups)
# - SafeQ support set different User Name than Linux User
#
# re-designed filter (based on femperonpsc250mu.pl)
# - PPD with custom input fields
# - using arguments (ARGV[#]) for reading custom driver settings
#
# - not needed sections in filter removed
# - filter file name changed
#
# - support for overwrite driver settings using a file in the users home folder
#
# - debug information can be logged in Cups error log
# - additional code if driver settings are not submitted with (ARGV[4]) 
#   e.g non GUI application or when sending print file by lp command
# - optimized code for less memory usage
#
###############################################################################

# Starting and be strict
use strict;

# Workaround for alternative driver settings using a file in the users home folder
# $usesettingsfile= 0 for disable, 1 for enable function
my $usesettingsfile=0;

# in addition the path to the home folder is needed 
# in most Linux distributions the home folders are located by default in "/home"
# for this function, the expectation is that sub folders exists which are named as 
# the username transfered to Cups
my $homefolderspath="/home";


# Debug information from the Cups filter can be written to the cups error_log
# Debug mode will only work when debug logging is enabled in Cups
# Debug mode OFF: $dbg_mode=0
# Debug mode ON: $dbg_mode=1
# By default this is $dbg_mode=0
my $dbg_mode=0;

# The file to read from 
# This can be a file given as argument or STDIN 
# See CUPS Software Programmers manual  
my $inputfile;


sub debug_log {
	my($debug_txt) = @_;
	if($dbg_mode==1)
	{
		print STDERR "DEBUG: KMbeuEmpPS.pl ".$debug_txt."\n";
	}
}
debug_log("filter debug mode enabled");

# Open the input file, if a filename is given, this must be ARGV[5] according to
# CUPS Software Programmers Manual
# A file argument may be provided to the filter in the filter chain
# If no file argument is given, STDIN is used
if (defined $ARGV[5])
{	
	# choose ARGV[5] as inputfile
	$inputfile= $ARGV[5];
}
else
{
	# choose STDIN as inputfile
	$inputfile = "-";
}


# as described in the Cups API filter documentation following arguments will be passed to the filter
# argv[1] The job ID
# argv[2] The user printing the job
# argv[3] The job name/title
# argv[4] The number of copies to print
# argv[5] The options that were provided when the job was submitted
# argv[6] The file to print (first program only)
# unfortunatley in perl we start counting by 0, so the job ID is $ARGV[0], user is $ARGV[1], ...
my $username='';
if (defined $ARGV[1])
{
	$username=$ARGV[1];
}

debug_log ("<ARGV_0>".$ARGV[0]);
debug_log ("<ARGV_1>".$ARGV[1]);
debug_log ("<ARGV_2>".$ARGV[2]);
debug_log ("<ARGV_3>".$ARGV[3]);
debug_log ("<ARGV_4>".$ARGV[4]);
if (defined $ARGV[5])
{
	debug_log ("<ARGV_5>".$ARGV[5]);
}

my $A4Device=0;
my $SecurePrint=0;
my $IDPrint=0;
my $SecureID='';
my $SecurePass='';
my $ProofPrint=0;
my $AccountTrack=0;
my $AccountTrackDepartmentCode='';
my $AccountTrackPass='';
my $Authentication=0;
my $AuthenticationUser='';
my $AuthenticationPass='';
my $AuthenticationServer=1;
my $BoxPrint=0;
my $BoxNumber='';
my $BoxFileName='';
my $SafeQ=0;
my $SafeQName='';

my $CopySecurityEnable=0;
my $CopySecurityMode='';
my $CopySecurityPass='';
my $CopySecurityCharacters='';
my $CopySecurityDateTime='';
my $CopySecurityDateFormat='';
my $CopySecurityTimeFormat='';
my $CopySecuritySerialNumber=0;
my $CopySecurityDistributionControlNumber=0;
my $CopySecurityDCNStart='';
my $CopySecurityJobNumber=0;
my $CopySecurityPatternAngle='';
my $CopySecurityPatternTextSize='';
my $CopySecurityPatternColor='BLACK';
my $CopySecurityPatternDensity='';
my $CopySecurityPatternContrast='';
my $CopySecurityPatternOverwrite='';
my $CopySecurityBackgroundPattern='';
my $CopySecurityPatternEmboss='';

my $StampDateTime='';
my $StampDateFormat='';
my $StampTimeFormat='';
my $StampPages='ALLPAGES';			
my $StampTextColor='BLACK';
my $StampPrintPosition='';

my $StampPageNumberEnable=0;
my $StampPageNumberStartingPage='';
my $StampPageNumberStartingNumber='';
my $StampPageNumberCoverMode='ALLPAGES';
my $StampPNTextColor='BLACK';
my $StampPNPrintPosition='';


my $EncryptionEnable=0;
my $EncryptionPassphrase='';
# only A3 products support custom encryption passphrase
# $EncryptionSupport will be used to decide if model supports encryption based on availability
# of encryption setting in PPD
# this is required because of workaround setting with external file
my $EncryptionSupport=0;

# Array to store the postscript file generated by pstops
# MIME-type:application/vnd.cups-postscript
# This Array will later be included in the final job file send to the printer
# only used when $ARGV[4] does not contain PPd settings
my @output=();	


# usually $ARGV[4] contains selected driver options
# non-GUI applications may not submit PPD settings in $ARGV[4]
# this switch will check if PPD settings are transmitted
# if not, the filter needs to read and parse the whole inputfile
$_=$ARGV[4];
# OpenOffice/LibreOffice(with custom inputs) behaves somehow strange, so just switching by KMAuthentication is not enough
if ( m/KMOutputMethod|KMSectionManagement|KMAuthentication|KMCopySecurityEnable|KMEncryption|KMStampPageNumberEnable/ )
{
	
	# $ARGV[4] contains selected driver options
	# replace <space> within option values to allow splitting options by space character
	$ARGV[4] =~ s/\\\s/%#%/g;  
	my @drv_options=split(/\s/,$ARGV[4]);
	
	
	#parsing driver settings
	my $option;
	foreach $option (@drv_options)
	{
		# put <space> back for each option
		$option =~ s/%#%/ /g; 
	
		$_=$option;
	
		# C35 will have different PJL commands, PPD has been modified to use KMPOutputMethod instead of KMOutputMethod
		if ( m/POutputMethod/ )
		{
			$A4Device=1;
		}
	
		# output method settings
		if ( m/OutputMethod=ProofMode/ )
		{
			$ProofPrint=1;
			next;
		}
	
		if ( m/OutputMethod=Secure/ )
		{
			$SecurePrint=1;
			next;
		}
	
		# save in box
		if ( m/OutputMethod=Box/ )
		{
			$BoxPrint=1; 
			next;
		}
		
		# save in box and print
		if ( m/OutputMethod=BoxPrint/ )
		{
			$BoxPrint=2;
			next;
		}
		#ID & Print
		if ( m/OutputMethod=IDPrint/ )
		{
			$IDPrint=1;
			next;
		}
		#SafeQ
		if ( m/OutputMethod=SafeQ/ )
		{
			$SafeQ=1;
			next;
		}
		
		# secure print setting  
		if ( m/KMSecID/ )
		{
			if ( m/KMSecID=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMSecID=//g ;
			$option =~ s/Custom.//g ;
			$SecureID=$option;
			next;
			}
		}
		
		if ( m/KMSecPass/ )
		{
			if ( m/KMSecPass=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMSecPass=//g ;
			$option =~ s/Custom.//g ;
			$SecurePass=$option;
			next;
			}
		}
		
		# Box Print
		if ( m/KMBoxNumber/ )
		{
			if ( m/KMBoxNumber=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMBoxNumber=//g ;
			$option =~ s/Custom.//g ;
			$BoxNumber=$option;
			next;
			}
		}
		
		if ( m/KMBoxFileName/ )
		{
			if ( m/KMBoxFileName=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMBoxFileName=//g ;
			$option =~ s/Custom.//g ;
			$BoxFileName=$option;
			next;
			}
		}
		
		# SafeQ setting  
		if ( m/KMSafeQUser/ )
		{
			if ( m/KMSafeQUser=<Current_User>/ )
			{
			$SafeQName=$username;
			next;
			}
			else
			{
			$option =~ s/KMSafeQUser=//g ;
			$option =~ s/Custom.//g ;
			$SafeQName=$option;
			next;
			}
		}
		
		
		# Account Track
		if ( m/KMSectionManagement/ )
		{
			if ( m/noKMSectionManagement/ )
			{
			next;
			}
			else
			{
			$AccountTrack=1;
			next;
			}
		}
		
		if ( m/KMDepCode/ )
		{
			if ( m/KMDepCode=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMDepCode=//g ;
			$option =~ s/Custom.//g ;
			$AccountTrackDepartmentCode=$option;
			next;
			}
		}
		
		if ( m/KMAccPass/ )
		{
			if ( m/KMAccPass=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMAccPass=//g ;
			$option =~ s/Custom.//g ;
			$AccountTrackPass=$option;
			next;
			}
		}
		
		# Authentication
		if ( m/KMAuthentication/ )
		{
			if ( m/KMAuthentication=False/ )
			{
			next;
			}
			#MFP Authentication
			if ( m/KMAuthentication=Private/ )
			{
			$Authentication=1;
			next;
			}
			#PSES authentication
			if ( m/KMAuthentication=PSES/ )
			{
			$Authentication=2;
			next;
			}
			#Server and MFP+Server Authentication
			if ( m/KMAuthentication=Server/ )
			{
			$Authentication=3;
			next;
			}
		}
		
		if ( m/KMAuthUser/ )
		{
			if ( m/KMAuthUser=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMAuthUser=//g ;
			$option =~ s/Custom.//g ;
			$AuthenticationUser=$option;
			next;
			}
		}
		
		if ( m/KMAuthPass/ )
		{
			if ( m/KMAuthPass=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMAuthPass=//g ;
			$option =~ s/Custom.//g ;
			$AuthenticationPass=$option;
			next;
			}
		}

		if ( m/KMAuthServer/ )
		{
			if ( m/KMAuthServer=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMAuthServer=//g ;
			$AuthenticationServer=$option;
			next;
			}
		}
		
		# Copy Security
		if ( m/KMCopySecurityEnable/ )
		{
			if ( m/noKMCopySecurityEnable/ )
			{
			next;
			}
			else
			{
			$CopySecurityEnable=1;
			next;
			}
		}
		
		if ( m/KMCopySecurityMode=/ )
		{
			$option =~ s/KMCopySecurityMode=//g ;
			$CopySecurityMode=$option;
			next;
		}
		
		if ( m/KMCopySecurityPass=/ )
		{
			$option =~ s/KMCopySecurityPass=//g ;
			$option =~ s/Custom.//g ;
			$CopySecurityPass=$option;
			next;
		}
		
		if ( m/KMCopySecurityCharacters=/ )
		{
			$option =~ s/KMCopySecurityCharacters=//g ;
			$CopySecurityCharacters=$option;
			next;
		}
		
		if ( m/KMCopySecurityDateTime=/ )
		{
			$option =~ s/KMCopySecurityDateTime=//g ;
			$CopySecurityDateTime=$option;
			next;
		}
		
		if ( m/KMCopySecurityDateFormat=/ )
		{
			$option =~ s/KMCopySecurityDateFormat=//g ;
			$CopySecurityDateFormat=$option;
			next;
		}
		
		if ( m/KMCopySecurityTimeFormat=/ )
		{
			$option =~ s/KMCopySecurityTimeFormat=//g ;
			$CopySecurityTimeFormat=$option;
			next;
		}
		
		if ( m/KMCopySecuritySerialNumber/ )
		{
			if ( m/noKMCopySecuritySerialNumber/ )
			{
			next;
			}
			else
			{
			$CopySecuritySerialNumber=1;
			next;
			}
		}
		
		if ( m/KMCopySecurityDCNumber/ )
		{
			if ( m/noKMCopySecurityDCNumber/ )
			{
			next;
			}
			else
			{
			$CopySecurityDistributionControlNumber=1;
			next;
			}
		}
		
		if ( m/CopySecurityDCNStart=/ )
		{
			$option =~ s/KMCopySecurityDCNStart=//g ;
			$option =~ s/Custom.//g ;
			$CopySecurityDCNStart=$option;
			next;
		}
		if ( m/KMCopySecurityJobNumber/ )
		{
			if ( m/noKMCopySecurityJobNumber/ )
			{
			next;
			}
			$CopySecurityJobNumber=1;
			next;
		}
		if ( m/KMCopySecurityPatternAngle=/ )
		{
			$option =~ s/KMCopySecurityPatternAngle=//g ;
			$CopySecurityPatternAngle=$option;
			next;
		}
		if ( m/KMCopySecurityPatternTextSize=/ )
		{
			$option =~ s/KMCopySecurityPatternTextSize=//g ;
			$CopySecurityPatternTextSize=$option;
			next;
		}
		if ( m/KMCopySecurityPatternColor=/ )
		{
			$option =~ s/KMCopySecurityPatternColor=//g ;
			$CopySecurityPatternColor=$option;
			next;
		}
		if ( m/KMCopySecurityPatternDensity=/ )
		{
			$option =~ s/KMCopySecurityPatternDensity=//g ;
			$CopySecurityPatternDensity=$option;
			next;
		}
		if ( m/KMCopySecurityPatternContrast=/ )
		{
			$option =~ s/KMCopySecurityPatternContrast=//g ;
			$CopySecurityPatternContrast=$option;
			next;
		}
		if ( m/KMCopySecurityPatternOverwrite=/ )
		{
			$option =~ s/KMCopySecurityPatternOverwrite=//g ;
			$CopySecurityPatternOverwrite=$option;
			next;
		}
		if ( m/KMCopySecurityBackgroundPattern=/ )
		{
			$option =~ s/KMCopySecurityBackgroundPattern=//g ;
			$CopySecurityBackgroundPattern=$option;
			next;
		}
		if ( m/KMCopySecurityPatternEmboss=/ )
		{
			$option =~ s/KMCopySecurityPatternEmboss=//g ;
			$CopySecurityPatternEmboss=$option;
			next;
		}
		# Date/Time Stamp
		if ( m/KMStampDateTime=/ )
		{
			$option =~ s/KMStampDateTime=//g ;
			$StampDateTime=$option;
			next;
		}
		if ( m/KMStampDateFormat=/ )
		{
			$option =~ s/KMStampDateFormat=//g ;
			$StampDateFormat=$option;
			next;
		}
		if ( m/KMStampTimeFormat=/ )
		{
			$option =~ s/KMStampTimeFormat=//g ;
			$StampTimeFormat=$option;
			next;
		}
		if ( m/KMStampPages=/ )
		{
			$option =~ s/KMStampPages=//g ;
			$StampPages=$option;
			next;
		}
		if ( m/KMStampTextColor=/ )
		{
			$option =~ s/KMStampTextColor=//g ;
			$StampTextColor=$option;
			next;
		}
		if ( m/KMStampPrintPosition=/ )
		{
			$option =~ s/KMStampPrintPosition=//g ;
			$StampPrintPosition=$option;
			next;
		}
		
		# Page Number Stamp
		if ( m/KMStampPageNumberEnable/ )
		{
			if ( m/noKMStampPageNumberEnable/ )
			{
			next;
			}
			$StampPageNumberEnable=1;
			next;
		}
		if ( m/KMStampPNStartingPage=/ )
		{
			$option =~ s/KMStampPNStartingPage=//g ;
			$option =~ s/Custom.//g ;
			$StampPageNumberStartingPage=$option;
			next;
		}
		if ( m/KMStampPNStartingNumber=/ )
		{
			$option =~ s/KMStampPNStartingNumber=//g ;
			$option =~ s/Custom.//g ;
			$StampPageNumberStartingNumber=$option;
			next;
		}
		if ( m/KMStampPageNumberCoverMode=/ )
		{
			$option =~ s/KMStampPageNumberCoverMode=//g ;
			$StampPageNumberCoverMode=$option;
			next;
		}
		if ( m/KMStampPNTextColor=/ )
		{
			$option =~ s/KMStampPNTextColor=//g ;
			$StampPNTextColor=$option;
			next;
		}
		if ( m/KMStampPNPrintPosition=/ )
		{
			$option =~ s/KMStampPNPrintPosition=//g ;
			$StampPNPrintPosition=$option;
			next;
		}
	

		#printer driver encryption
		if ( m/KMEncryption/ )
		{
		$EncryptionSupport=1;
		if ( m/noKMEncryption/ )
			{
			next;
			}
			else
			{
			$EncryptionEnable=1;
			next;
			}
		}
		
		if ( m/KMEncPass/ )
		{
			if ( m/KMEncPass=None/ )
			{
			next;
			}
			else
			{
			$option =~ s/KMEncPass=//g ;
			$option =~ s/Custom.//g ;
			$EncryptionPassphrase=$option;
			next;
			}
		}

	
	}
	#end parsing driver settings
}
else
{
	# parse inputfile for driver settings if not submitted within $ARGV[4] 

	
	# open inputfile (file handle: INFILE) or create error message
	open(INFILE, $inputfile) or die "Can't open file: $inputfile\n";
	
	# Loop over $inputfile - line by line
	# The next section seperates postscript commands and PJL commands
	while (<INFILE>)
	{
		# chomp $_;
		# The actual line is $_ , it is pushed to the output array which stores 
		# all job data 
		push @output,$_;
	}
	
	# Now the job data is stored, the postscript file is not needed
	# any longer
	# Close the input file handle
	close(INFILE);

	my $inc=-1;
	my $option;
	#parsing driver settings
	foreach $_(@output)
	{
		++$inc;
		# C35 will have different PJL commands, PPD has been modified to use KMPOutputMethod instead of KMOutputMethod
		if ( m/POutputMethod/ )
		{
			$A4Device=1;
		}

		# output method settings
		if ( m/OutputMethod ProofMode/ )
		{
			$ProofPrint=1;
			next;
		}

		if ( m/OutputMethod Secure/ )
		{
			$SecurePrint=1;
			next;
		}
		
		# save in box
		if ( m/OutputMethod Box/ )
		{
			$BoxPrint=1; 
			next;
		}
		
		# save in box and print
		if ( m/OutputMethod BoxPrint/ )
		{
			$BoxPrint=2;
			next;
		}
		#ID & Print
		if ( m/OutputMethod IDPrint/ )
		{
			$IDPrint=1;
			next;
		}
		#SafeQ
		if ( m/OutputMethod SafeQ/ )
		{
			$SafeQ=1;
			next;
		}
		
		# secure print setting  
		if ( m/KMSecID/ )
		{
			if ( m/KMSecID None/ )
			{
				next;
			}
			# custom input secure print ID from next line
			if ( m/CustomKMSecID/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$SecureID=$option;
				next;
			}
			# if secure print ID is added to PPD
			if ( m/KMSecID/ )
			{
				$option=$_;
				$option =~ s/.*KMSecID // ;
				$option =~ s/\s// ;
				$SecureID=$option;
				next;
			}
		}

		if ( m/KMSecPass/ )
		{
			if ( m/KMSecPass None/ )
			{
				next;
			}
			if ( m/CustomKMSecPass/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$SecurePass=$option;
				next;
			}
			if ( m/KMSecPass/ )
			{
				$option=$_;
				$option =~ s/.*KMSecPass // ;
				$option =~ s/\s// ;
				$SecurePass=$option;
				next;
			}			
		}
		
		# Box Print
		if ( m/KMBoxNumber/ )
		{
			if ( m/KMBoxNumber None/ )
			{
				next;
			}
			if ( m/CustomKMBoxNumber/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$BoxNumber=$option;
				next;
			}
			if ( m/KMBoxNumber/ )
			{
				$option=$_;
				$option =~ s/.*KMBoxNumber // ;
				$option =~ s/\s// ;
				$BoxNumber=$option;
				next;
			}
		}
		
		if ( m/KMBoxFileName/ )
		{
			if ( m/KMBoxFileName None/ )
			{
				next;
			}
			if ( m/CustomKMBoxFileName/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$BoxFileName=$option;
				next;
			}
			if ( m/KMBoxFileName/ )
			{
				$option=$_;
				$option =~ s/.*KMBoxFileName // ;
				$option =~ s/\s// ;
				$BoxFileName=$option;
				next;
			}
		}
				
		# SafeQ setting  
		if ( m/KMSafeQUser/ )
		{
			if ( m/KMSafeQUser <Current_User>/ )
			{
				$SafeQName=$username;
				next;
			}
			if ( m/CustomKMSafeQUser/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$SafeQName=$option;
				next;
			}
			if ( m/KMSafeQUser/ )
			{
				$option=$_;
				$option =~ s/.*KMSafeQUser // ;
				$option =~ s/\s// ;
				$SafeQName=$username;
				next;
			}
		}

		# Account Track
		if ( m/KMSectionManagement/ )
		{
			if ( m/KMSectionManagement True/ )
			{
				$AccountTrack=1;
				next;
			}
			next;
		}
		
		if ( m/KMDepCode/ )
		{
			if ( m/KMDepCode None/ )
			{
				next;
			}
			if ( m/CustomKMDepCode/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$AccountTrackDepartmentCode=$option;
				next;
			}
			if ( m/KMDepCode/ )
			{
				$option=$_;
				$option =~ s/.*KMDepCode // ;
				$option =~ s/\s// ;
				$AccountTrackDepartmentCode=$option;
				next;
			}
		}

		if ( m/KMAccPass/ )
		{
			if ( m/KMAccPass None/ )
			{
				next;
			}
			if ( m/CustomKMAccPass/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$AccountTrackPass=$option;
				next;
			}
			if ( m/KMAccPass/ )
			{
				$option=$_;
				$option =~ s/.*KMAccPass // ;
				$option =~ s/\s// ;
				$AccountTrackPass=$option;
				next;
			}
		}

		# Authentication
		if ( m/KMAuthentication/ )
		{
			#MFP Authentication
			if ( m/KMAuthentication Private/ )
			{
				$Authentication=1;
				next;
			}
			#PSES authentication
			if ( m/KMAuthentication PSES/ )
			{
				$Authentication=2;
				next;
			}
			##Server and MFP+Server Authentication
			if ( m/KMAuthentication Server/ )
			{
				$Authentication=3;
				next;
			}
			next;
		}
		
		if ( m/KMAuthUser/ )
		{
			if ( m/KMAuthUser None/ )
			{
				next;
			}
			if ( m/CustomKMAuthUser/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$AuthenticationUser=$option;
				next;
			}
			if ( m/KMAuthUser/ )
			{
				$option=$_;
				$option =~ s/.*KMAuthUser // ;
				$option =~ s/\s// ;
				$AuthenticationUser=$option;
				next;
			}
		}
		
		if ( m/KMAuthPass/ )
		{
			if ( m/KMAuthPass None/ )
			{
				next;
			}
			if ( m/CustomKMAuthPass/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$AuthenticationPass=$option;
				next;
			}
			if ( m/KMAuthPass/ )
			{
				$option=$_;
				$option =~ s/.*KMAuthPass // ;
				$option =~ s/\s// ;
				$AuthenticationPass=$option;
				next;
			}
		}

		if ( m/KMAuthServer/ )
		{
			if ( m/KMAuthServer None/ )
			{
				next;
			}
			else
			{
				$option=$_;
				$option =~ s/.*KMAuthServer // ;
				$option =~ s/\s// ;
				$AuthenticationServer=$option;
				next;
			}
		}
		
		
		# Copy Security
		if ( m/KMCopySecurityEnable/ )
		{
			if ( m/KMCopySecurityEnable True/ )
			{
				$CopySecurityEnable=1;
				next;
			}
			next;
		}
		
		if ( m/KMCopySecurityMode/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityMode // ;
			$option =~ s/\s// ;
			$CopySecurityMode=$option;
			next;
		}
		
		if ( m/KMCopySecurityPass/ )
		{
			if ( m/KMCopySecurityPass None/ )
			{
				next;
			}
			if ( m/CustomKMCopySecurityPass/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$CopySecurityPass=$option;
				next;
			}
			if ( m/KMCopySecurityPass/ )
			{
				$option=$_;
				$option =~ s/.*KMCopySecurityPass // ;
				$option =~ s/\s// ;
				$CopySecurityPass=$option;
				next;
			}
		}
		
		if ( m/KMCopySecurityCharacters/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityCharacters // ;
			$option =~ s/\s// ;
			$CopySecurityCharacters=$option;
			next;
		}
		
		if ( m/KMCopySecurityDateTime/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityDateTime // ;
			$option =~ s/\s// ;
			$CopySecurityDateTime=$option;
			next;
		}
		
		if ( m/KMCopySecurityDateFormat/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityDateFormat // ;
			$option =~ s/\s// ;
			$CopySecurityDateFormat=$option;
			next;
		}
		
		if ( m/KMCopySecurityTimeFormat/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityTimeFormat // ;
			$option =~ s/\s// ;
			$CopySecurityTimeFormat=$option;
			next;
		}
		
		if ( m/KMCopySecuritySerialNumber/ )
		{
			if ( m/KMCopySecuritySerialNumber True/ )
			{
				$CopySecuritySerialNumber=1;
				next;
			}
		}
		
		if ( m/KMCopySecurityDCNumber/ )
		{
			if ( m/KMCopySecurityDCNumber True/ )
			{
				$CopySecurityDistributionControlNumber=1;
				next;
			}
		}
		
		if ( m/CopySecurityDCNStart/ )
		{
			if ( m/CopySecurityDCNStart 1/ )
			{
				$CopySecurityDCNStart=1;
				next;
			}
			if ( m/CustomCopySecurityDCNStart/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$CopySecurityDCNStart=$option;
				next;
			}
			if ( m/CopySecurityDCNStart/ )
			{
				$option=$_;
				$option =~ s/.*CopySecurityDCNStart // ;
				$option =~ s/\s// ;
				$CopySecurityDCNStart=$option;
				next;
			}
		}
		if ( m/KMCopySecurityJobNumber/ )
		{
			if ( m/KMCopySecurityJobNumber True/ )
			{
				$CopySecurityJobNumber=1;
				next;
			}	
		}
		if ( m/KMCopySecurityPatternAngle/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternAngle // ;
			$option =~ s/\s// ;
			$CopySecurityPatternAngle=$option;
			next;
		}
		if ( m/KMCopySecurityPatternTextSize/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternTextSize // ;
			$option =~ s/\s// ;
			$CopySecurityPatternTextSize=$option;
			next;
		}
		if ( m/KMCopySecurityPatternColor/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternColor // ;
			$option =~ s/\s// ;
			$CopySecurityPatternColor=$option;
			next;
		}
		if ( m/KMCopySecurityPatternDensity/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternDensity // ;
			$option =~ s/\s// ;
			$CopySecurityPatternDensity=$option;
			next;
		}
		if ( m/KMCopySecurityPatternContrast/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternContrast // ;
			$option =~ s/\s// ;
			$CopySecurityPatternContrast=$option;
			next;
		}
		if ( m/KMCopySecurityPatternOverwrite/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternOverwrite // ;
			$option =~ s/\s// ;
			$CopySecurityPatternOverwrite=$option;
			next;
		}
		if ( m/KMCopySecurityBackgroundPattern/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityBackgroundPattern // ;
			$option =~ s/\s// ;
			$CopySecurityBackgroundPattern=$option;
			next;
		}
		if ( m/KMCopySecurityPatternEmboss/ )
		{
			$option=$_;
			$option =~ s/.*KMCopySecurityPatternEmboss // ;
			$option =~ s/\s// ;
			$CopySecurityPatternEmboss=$option;
			next;
		}
		# Date/Time Stamp
		if ( m/KMStampDateTime / )
		{
			$option=$_;
			$option =~ s/.*KMStampDateTime // ;
			$option =~ s/\s// ;
			$StampDateTime=$option;
			next;
		}
		if ( m/KMStampDateFormat/ )
		{
			$option=$_;
			$option =~ s/.*KMStampDateFormat // ;
			$option =~ s/\s// ;
			$StampDateFormat=$option;
			next;
		}
		if ( m/KMStampTimeFormat/ )
		{
			$option=$_;
			$option =~ s/.*KMStampTimeFormat // ;
			$option =~ s/\s// ;
			$StampTimeFormat=$option;
			next;
		}
		if ( m/KMStampPages/ )
		{
			$option=$_;
			$option =~ s/.*KMStampPages // ;
			$option =~ s/\s// ;
			$StampPages=$option;
			next;
		}
		if ( m/KMStampTextColor/ )
		{
			$option=$_;
			$option =~ s/.*KMStampTextColor // ;
			$option =~ s/\s// ;
			$StampTextColor=$option;
			next;
		}
		if ( m/KMStampPrintPosition/ )
		{
			$option=$_;
			$option =~ s/.*KMStampPrintPosition // ;
			$option =~ s/\s// ;
			$StampPrintPosition=$option;
			next;
		}
		
		# Page Number Stamp
		if ( m/KMStampPageNumberEnable/ )
		{
			if ( m/KMStampPageNumberEnable True/ )
			{
				$StampPageNumberEnable=1;
				next;
			}
		}
		if ( m/KMStampPNStartingPage/ )
		{
			if ( m/KMStampPNStartingPage 1/ )
			{
				$StampPageNumberStartingPage=1;
				next;
			}
			if ( m/CustomKMStampPNStartingPage/ )
			{
				$option=$_;
				$option =~ s/.*KMStampPNStartingPage // ;
				$option =~ s/\s// ;
				$StampPageNumberStartingPage=$option;
				next;
			}
			if ( m/KMStampPNStartingPage/ )
			{
				$option=$_;
				$option =~ s/.*KMStampPNStartingPage // ;
				$option =~ s/\s// ;
				$StampPageNumberStartingPage=$option;
				next;
			}
		}
		if ( m/KMStampPNStartingNumber/ )
		{
			if ( m/KMStampPNStartingNumber 1/ )	
			{
				$StampPageNumberStartingNumber=1;
				next;
			}
			if ( m/CustomKMStampPNStartingNumber/ )	
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$StampPageNumberStartingNumber=$option;
			next;
			}
			if ( m/KMStampPNStartingNumber/ )	
			{
				$option=$_;
				$option =~ s/.*KMStampPNStartingNumber // ;
				$option =~ s/\s// ;
				$StampPageNumberStartingNumber=$option;
				next;
			}
		}
		if ( m/KMStampPageNumberCoverMode/ )
		{
			$option=$_;
			$option =~ s/.*KMStampPageNumberCoverMode // ;
			$option =~ s/\s// ;
			$StampPageNumberCoverMode=$option;
			next;
		}
		if ( m/KMStampPNTextColor/ )
		{
			$option=$_;
			$option =~ s/.*KMStampPNTextColor // ;
			$option =~ s/\s// ;
			$StampPNTextColor=$option;
			next;
		}
		if ( m/KMStampPNPrintPosition/ )
		{
			$option=$_;
			$option =~ s/.*KMStampPNPrintPosition // ;
			$option =~ s/\s// ;
			$StampPNPrintPosition=$option;
			next;
		}
				
		# Printer Driver Encryption
		if ( m/KMEncryption/ )
		{
		$EncryptionSupport=1;
		if ( m/KMEncryption True/ )
			{
				$EncryptionEnable=1;
				next;
			}
			next;
		}
		
		if ( m/KMEncPass/ )
		{
			if ( m/KMEncPass None/ )
			{
				next;
			}
			if ( m/CustomKMEncPass/ )
			{
				$option=$output[$inc+1];
				$option =~ s/^\(// ;
				$option =~ s/\)$// ;
				$option =~ s/\s// ;
				$EncryptionPassphrase=$option;
				next;
			}
			if ( m/KMEncPass/ )
			{
				$option=$_;
				$option =~ s/.*KMEncPass // ;
				$option =~ s/\s// ;
				$EncryptionPassphrase=$option;
				next;
			}
		}
	
	}
	# OpenOffice fix
	# OpenOffice/LibreOffice behaves strange with custom inputs
	# PS code contains values from printer default setting ; but correct values are provided with <ARGV[4]>
	# so wee need to parse ARGV[4] for custom values
	$_=$ARGV[4];
	# check if custom input is used
	if ( m/KMSecID|KMSecPass|KMBoxNumber|KMBoxFileName|KMSafeQUser|KMDepcode|KMAccPass|KMAuthUser|KMAuthPass|KMCopySecurityPass|KMCopySecurityDCNStart|KMEncPass|KMStampPNStartingPage|KMStampPNStartingNumber/ )
	{
		# replace <space> within option values to allow splitting options by space character
		$ARGV[4] =~ s/\\\s/%#%/g;  
		my @drv_options=split(/\s/,$ARGV[4]);
		#parsing driver settings
		my $option;
		foreach $option (@drv_options)
		{
			# put <space> back for each option
			$option =~ s/%#%/ /g; 
		
			$_=$option;
		
			# secure print setting  
			if ( m/KMSecID/ )
			{
				if ( m/KMSecID=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMSecID=//g ;
				$option =~ s/Custom.//g ;
				$SecureID=$option;
				next;
				}
			}
			
			if ( m/KMSecPass/ )
			{
				if ( m/KMSecPass=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMSecPass=//g ;
				$option =~ s/Custom.//g ;
				$SecurePass=$option;
				next;
				}
			}
			
			# Box Print
			if ( m/KMBoxNumber/ )
			{
				if ( m/KMBoxNumber=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMBoxNumber=//g ;
				$option =~ s/Custom.//g ;
				$BoxNumber=$option;
				next;
				}
			}
			
			if ( m/KMBoxFileName/ )
			{
				if ( m/KMBoxFileName=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMBoxFileName=//g ;
				$option =~ s/Custom.//g ;
				$BoxFileName=$option;
				next;
				}
			}
			
			# SafeQ setting  
			if ( m/KMSafeQUser/ )
			{
				if ( m/KMSafeQUser=<Current_User>/ )
				{
				$SafeQName=$username;
				next;
				}
				else
				{
				$option =~ s/KMSafeQUser=//g ;
				$option =~ s/Custom.//g ;
				$SafeQName=$option;
				next;
				}
			}
			
			
			# Account Track
			if ( m/KMDepCode/ )
			{
				if ( m/KMDepCode=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMDepCode=//g ;
				$option =~ s/Custom.//g ;
				$AccountTrackDepartmentCode=$option;
				next;
				}
			}
			
			if ( m/KMAccPass/ )
			{
				if ( m/KMAccPass=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMAccPass=//g ;
				$option =~ s/Custom.//g ;
				$AccountTrackPass=$option;
				next;
				}
			}
			
			# Authentication
			if ( m/KMAuthUser/ )
			{
				if ( m/KMAuthUser=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMAuthUser=//g ;
				$option =~ s/Custom.//g ;
				$AuthenticationUser=$option;
				next;
				}
			}
			
			if ( m/KMAuthPass/ )
			{
				if ( m/KMAuthPass=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMAuthPass=//g ;
				$option =~ s/Custom.//g ;
				$AuthenticationPass=$option;
				next;
				}
			}
	
			# Copy Security
			if ( m/KMCopySecurityPass=/ )
			{
				$option =~ s/KMCopySecurityPass=//g ;
				$option =~ s/Custom.//g ;
				$CopySecurityPass=$option;
				next;
			}
			
			if ( m/CopySecurityDCNStart=/ )
			{
				$option =~ s/KMCopySecurityDCNStart=//g ;
				$option =~ s/Custom.//g ;
				$CopySecurityDCNStart=$option;
				next;
			}
			# Page Number Stamp
			if ( m/KMStampPNStartingPage=/ )
			{
				$option =~ s/KMStampPNStartingPage=//g ;
				$option =~ s/Custom.//g ;
				$StampPageNumberStartingPage=$option;
				next;
			}
			if ( m/KMStampPNStartingNumber=/ )
			{
				$option =~ s/KMStampPNStartingNumber=//g ;
				$option =~ s/Custom.//g ;
				$StampPageNumberStartingNumber=$option;
				next;
			}
		
	
			#printer driver encryption
			if ( m/KMEncPass/ )
			{
				if ( m/KMEncPass=None/ )
				{
				next;
				}
				else
				{
				$option =~ s/KMEncPass=//g ;
				$option =~ s/Custom.//g ;
				$EncryptionPassphrase=$option;
				next;
				}
			}
	
		
		}
		#end parsing ARGV4
		
		
	}
}


# check users homedir for separate printer setting file
# workaround solution for OpenOffice/LibreOffice

if($usesettingsfile==1)
{
  my @KMDRVSET=();


  if (defined $ARGV[1])
  {
	debug_log("<USERNAME>".$ARGV[1]);
  }


  $_=$homefolderspath."/".$ARGV[1];

debug_log( "<HOMEFOLDER>".$_);


  if ((-e $_."/KMdrv.txt") && (-r $_."/KMdrv.txt"))
    {
      open (INFILE, $_."/KMdrv.txt");
      while (<INFILE>)
      {
        push @KMDRVSET,$_;
      }
      
      my $KMDRVline;
      foreach $KMDRVline (@KMDRVSET)
      {
        $_ = $KMDRVline;
        s/^\s+//;
        s/\s+$//;
        
        # skip comment lines
        if ( m/^\#/ )
        {
          next;
        } 
        if ( m/^\;/ )
        {
          next;
        } 
        # skip empty lines
        if ( $_ eq '' )
        {
          next;
        } 


	debug_log("<KMDRVline>".$_);

        
        if ( m/^OutputMethod=Secure/ )
        {
          $SecurePrint=1;
          $ProofPrint=0;
          $BoxPrint=0;
          $IDPrint=0;
		  $SafeQ=0;
          next;
        }      
        if ( m/^OutputMethod=ProofMode/ )
        {
          $ProofPrint=1;
          $SecurePrint=0;
          $BoxPrint=0;
          $IDPrint=0;
		  $SafeQ=0;
          next;
        }      
        if ( m/^OutputMethod=Box/ )
        {
          $BoxPrint=1;
          $SecurePrint=0;
          $ProofPrint=0;
          $IDPrint=0;
		  $SafeQ=0;
          next;
        }      
        if ( m/^OutputMethod=BoxPrint/ )
        {
          $BoxPrint=2;
          $SecurePrint=0;
          $ProofPrint=0;
          $IDPrint=0;
		  $SafeQ=0;
          next;
        }      
        if ( m/^OutputMethod=IDPrint/ )
        {
          $IDPrint=1;
          $SecurePrint=0;
          $ProofPrint=0;
          $BoxPrint=0;
		  $SafeQ=0;
          next;
        }      
        if ( m/^OutputMethod=Print/ )
        {
          $SecurePrint=0;
          $BoxPrint=0;
          $ProofPrint=0;
          $IDPrint=0;
		  $SafeQ=0;
          next;
        }   

        if ( m/^OutputMethod=SafeQ/ )
        {
          $SecurePrint=0;
          $BoxPrint=0;
          $ProofPrint=0;
          $IDPrint=0;
		  $SafeQ=1;
          next;
        }   
		        
        if ( m/^SecurePrintID=/ )
        {
          s/^SecurePrintID=//; 
          s/^\s+//;
          s/\s+$//;
           $SecureID=$_;
          next;
        }      
        if ( m/^SecurePrintPassword=/ )
        {
          s/^SecurePrintPassword=//; 
          s/^\s+//;
          s/\s+$//;
          $SecurePass=$_;
          next;
        }      

        if ( m/^BoxNumber=/ )
        {
          s/^BoxNumber=//; 
          s/^\s+//;
          s/\s+$//;
          $BoxNumber=$_;
          next;
        }      
        if ( m/^BoxFileName=/ )
        {
          s/^BoxFileName=//; 
          s/^\s+//;
          s/\s+$//;
          $BoxFileName=$_;
          next;
        }      

        if ( m/^SafeQUser=/ )
        {
          s/^SafeQUser=//; 
          s/^\s+//;
          s/\s+$//;
          $SafeQName=$_;
          next;
        }      
		
		
        if ( m/^AccountTrack=True/ )
        {
          $AccountTrack=1;
          next;
        }      
        if ( m/^AccountTrack=False/ )
        {
          $AccountTrack=0;
          next;
        }      
        if ( m/^DepartmentCode=/ )
        {
          s/^DepartmentCode=//; 
          s/^\s+//;
          s/\s+$//;
          $AccountTrackDepartmentCode=$_;
          next;
        }      
        if ( m/^AccountPassword=/ )
        {
          s/^AccountPassword=//; 
          s/^\s+//;
          s/\s+$//;
          $AccountTrackPass=$_;
          next;
        }      

        if ( m/^Authentication=PSES/ )
        {
          $Authentication=2;
          next;
        }      
        if ( m/^Authentication=True/ )
        {
          $Authentication=1;
          next;
        }      
        if ( m/^Authentication=Server/ )
        {
          $Authentication=3;
          next;
        }      
        if ( m/^Authentication=False/ )
        {
          $Authentication=0;
          next;
        }      
        if ( m/^AuthenticationUsername=/ )
        {
          s/^AuthenticationUsername=//; 
          s/^\s+//;
          s/\s+$//;
          $AuthenticationUser=$_;
          next;
        }      
        if ( m/^AuthenticationPassword=/ )
        {
          s/^AuthenticationPassword=//; 
          s/^\s+//;
          s/\s+$//;
          $AuthenticationPass=$_;
          next;
        }              
        if ( m/^AuthenticationServer=/ )
        {
          s/^AuthenticationServer=//; 
          s/^\s+//;
          s/\s+$//;
          $AuthenticationServer=$_;
          next;
        }              

        if ( m/^Encryption=True/ )
        {
          $EncryptionEnable=1;
          next;
        }      
        if ( m/^Encryption=False/ )
        {
          $EncryptionEnable=0;
          next;
        }      
        if ( m/^EncryptionPassphrase=/ )
        {
          s/^EncryptionPassphrase=//; 
          s/^\s+//;
          s/\s+$//;
          $EncryptionPassphrase=$_;
          next;
        }      
        
      }
    }
}

# if encryption is enabled, encryption passphrase must be 20 character
# disable encryption if it does not fit
if (($EncryptionEnable==1) && (length($EncryptionPassphrase)!=20))
{
  $EncryptionEnable=0;
  $EncryptionPassphrase="incorrect number of characters";
}

#add current folder to library path otherwise Encryption module cannot be found
use FindBin;
push (@INC, $FindBin::Bin);

# subroutine to call encryption module
sub encrypt
{
  my $pwd=$_[0];
  my $key=$EncryptionPassphrase;
  my $result="";
  require KMbeuEnc;
  my @cipher=KMEncryption::kmEncrypt($key,$pwd);
  for (my $i1=0; $i1<scalar(@cipher);$i1++)
  {
    $result=$result.sprintf("%02X",$cipher[$i1]);
  }
  return $result;
}


# only encrypt values if device supports encryption
if (($EncryptionEnable==1)&&($EncryptionSupport==1))
{
  $SecurePass=encrypt($SecurePass);
  $AccountTrackPass=encrypt($AccountTrackPass);
  $AuthenticationUser=encrypt($AuthenticationUser);
  $AuthenticationPass=encrypt($AuthenticationPass);
  $CopySecurityPass=encrypt($CopySecurityPass);
}

#use job name if box file name is not defined
if ( $BoxFileName eq "" ) { $BoxFileName=$ARGV[2]; }

debug_log("<SecurePrint>".$SecurePrint);
debug_log("<SecureID>".$SecureID);
debug_log("<SecurePass>".$SecurePass);
debug_log("<ProofPrint>".$ProofPrint);
debug_log("<AccountTrack>".$AccountTrack);
debug_log("<AccountTrackDepartmentCode>".$AccountTrackDepartmentCode);
debug_log("<AccountTrackPass>".$AccountTrackPass);
debug_log("<Authentication>".$Authentication);
debug_log("<AuthenticationUser>".$AuthenticationUser);
debug_log("<AuthenticationPass>".$AuthenticationPass);
debug_log("<AuthenticationServer>".$AuthenticationServer);
debug_log("<BoxPrint>".$BoxPrint);
debug_log("<BoxNumber>".$BoxNumber);
debug_log("<BoxFileName>".$BoxFileName);
debug_log("<IDPrint>".$IDPrint);
debug_log("<SafeQ>".$SafeQ);
debug_log("<SafeQName>".$SafeQName);

debug_log("<CopySecurityEnable>".$CopySecurityEnable);
debug_log("<CopySecurityMode>".$CopySecurityMode);
debug_log("<CopySecurityPass>".$CopySecurityPass);
debug_log("<CopySecurityCharacters>".$CopySecurityCharacters);
debug_log("<CopySecurityDateTime>".$CopySecurityDateTime);
debug_log("<CopySecurityDateFormat>".$CopySecurityDateFormat);
debug_log("<CopySecurityTimeFormat>".$CopySecurityTimeFormat);
debug_log("<CopySecuritySerialNumber>".$CopySecuritySerialNumber);
debug_log("<CopySecurityDistributionControlNumber>".$CopySecurityDistributionControlNumber);
debug_log("<CopySecurityDCNStart>".$CopySecurityDCNStart);
debug_log("<CopySecurityJobNumber>".$CopySecurityJobNumber);
debug_log("<CopySecurityPatternAngle>".$CopySecurityPatternAngle);
debug_log("<CopySecurityPatternTextSize>".$CopySecurityPatternTextSize);
debug_log("<CopySecurityPatternColor>".$CopySecurityPatternColor);
debug_log("<CopySecurityPatternDensity>".$CopySecurityPatternDensity);
debug_log("<CopySecurityPatternContrast>".$CopySecurityPatternContrast);
debug_log("<CopySecurityPatternOverwrite>".$CopySecurityPatternOverwrite);
debug_log("<CopySecurityBackgroundPattern>".$CopySecurityBackgroundPattern);
debug_log("<CopySecurityPatternEmboss>".$CopySecurityPatternEmboss);

debug_log("<StampDateTime>".$StampDateTime);
debug_log("<StampDateFormat>".$StampDateFormat);
debug_log("<StampTimeFormat>".$StampTimeFormat);
debug_log("<StampPages>".$StampPages);
debug_log("<StampTextColor>".$StampTextColor);
debug_log("<StampPrintPosition>".$StampPrintPosition);

debug_log("<StampPageNumberEnable>".$StampPageNumberEnable);
debug_log("<StampPageNumberStartingPage>".$StampPageNumberStartingPage);
debug_log("<StampPageNumberStartingNumber>".$StampPageNumberStartingNumber);
debug_log("<StampPageNumberCoverMode>".$StampPageNumberCoverMode);
debug_log("<StampPNTextColor>".$StampPNTextColor);
debug_log("<StampPNPrintPosition>".$StampPNPrintPosition);

debug_log("<EncryptionSupport>".$EncryptionSupport);
debug_log("<Encryption>".$EncryptionEnable);
debug_log("<EncryptionPassphrase>".$EncryptionPassphrase);


# $ARGV contains Job information which will be added to the PJL header
my @pjl_lines=();
# PJL header
push @pjl_lines, "\e\%-12345X\@PJL JOB\n";
push @pjl_lines, '@PJL COMMENT'."\n";

# for A4 devices the username will be used as secure print ID
# so we can use the real user-name only if we have A3 device or secure print is not used
# in case of SafeQ we send a different user-name
if (($A4Device==0 or $SecurePrint==0) and $SafeQ==0 )
{
  push @pjl_lines, '@PJL SET USERNAME="'.$username.'"'."\n";
}
if ( $SafeQ==1 )
{
  push @pjl_lines, '@PJL SET USERNAME="'.$SafeQName.'"'."\n";
}
push @pjl_lines, '@PJL SET JOBNAME="'.$ARGV[2].'"'."\n";
push @pjl_lines, '@PJL SET DRIVERJOBID="'.$ARGV[0].'"'."\n";
push @pjl_lines, '@PJL SET QTY='.$ARGV[3]."\n";

if (($EncryptionEnable==1)&&($EncryptionSupport==1))
{
  push @pjl_lines, '@PJL SET KMCOETYPE=2'."\n";
}
else
{
  push @pjl_lines, '@PJL SET KMCOETYPE=0'."\n";
}

if ($SecurePrint==1) 
{
    push @pjl_lines, '@PJL SET HOLD = ON'."\n";
    push @pjl_lines, '@PJL SET HOLDTYPE = PRIVATE'."\n";
	if ($A4Device==0)
	{
      push @pjl_lines, '@PJL SET KMJOBID = "'.$SecureID.'"'."\n";
	} 
    else
    {
      push @pjl_lines, '@PJL SET USERNAME = "'.$SecureID.'"'."\n";
    }	

    push @pjl_lines, '@PJL SET HOLDKEY = "'.$SecurePass.'"'."\n";
}
if ($ProofPrint==1) 
{
	if ($A4Device==0)
	{
      push @pjl_lines, '@PJL SET HOLD = KMPROOF'."\n";
	} 
    else
    {
      push @pjl_lines, '@PJL SET HOLD = PROOF'."\n";
    }	
    push @pjl_lines, '@PJL SET HOLDTYPE = PUBLIC'."\n";
}
if ($AccountTrack==1) 
{
	if ($A4Device==0)
	{
      push @pjl_lines, '@PJL SET KMSECTIONNAME = "'.$AccountTrackDepartmentCode.'"'."\n";
      push @pjl_lines, '@PJL SET KMSECTIONKEY2 = "'.$AccountTrackPass.'"'."\n";
	} 
    else
    {
      push @pjl_lines, '@PJL SET KMPSECTIONNAME = "'.$AccountTrackDepartmentCode.'"'."\n";
      push @pjl_lines, '@PJL SET KMPSECTIONKEY2 = "'.$AccountTrackPass.'"'."\n";
    }	
}
if ($IDPrint==1)
{
  push @pjl_lines, '@PJL SET HOLD = KMCERTSTORE'."\n";
  if ($Authentication==0) 
  {
	if ($A4Device==0)
	{
      push @pjl_lines, '@PJL SET KMUSERNAME = "Public"'."\n";
      push @pjl_lines, '@PJL SET KMUSERKEY2 = ""'."\n";
	} 
    else
    {
      push @pjl_lines, '@PJL SET KMPUSERNAME = "Public"'."\n";
      push @pjl_lines, '@PJL SET KMPUSERKEY = ""'."\n";
    }	
    push @pjl_lines, '@PJL SET BOXHOLDTYPE = PUBLIC'."\n";

  }  
}
#MFP Authentication
if ($Authentication==1) 
{
    if ($A4Device==0)
    {
      push @pjl_lines, '@PJL SET KMUSERNAME = "'.$AuthenticationUser.'"'."\n";
      push @pjl_lines, '@PJL SET KMUSERKEY2 = "'.$AuthenticationPass.'"'."\n";
    } 
    else
    {
      push @pjl_lines, '@PJL SET KMPUSERNAME = "'.$AuthenticationUser.'"'."\n";
      push @pjl_lines, '@PJL SET KMPUSERKEY = "'.$AuthenticationPass.'"'."\n";
    }	
    push @pjl_lines, '@PJL SET BOXHOLDTYPE = PRIVATE'."\n";

	push @pjl_lines, '@PJL SET KMCERTSERVTYPE = NONE'."\n";

}
#external Server Authentication
if ($Authentication==3) 
{
    if ($A4Device==0)
    {
      push @pjl_lines, '@PJL SET KMUSERNAME = "'.$AuthenticationUser.'"'."\n";
      push @pjl_lines, '@PJL SET KMUSERKEY2 = "'.$AuthenticationPass.'"'."\n";
    } 
    else
    {
      push @pjl_lines, '@PJL SET KMPUSERNAME = "'.$AuthenticationUser.'"'."\n";
      push @pjl_lines, '@PJL SET KMPUSERKEY = "'.$AuthenticationPass.'"'."\n";
    }	
    push @pjl_lines, '@PJL SET BOXHOLDTYPE = PRIVATE'."\n";

	push @pjl_lines, '@PJL SET KMCERTSERVTYPE = NUMBER'."\n";
	push @pjl_lines, '@PJL SET KMCERTSERVNUM = '.$AuthenticationServer."\n";

}


#create PJL lines for PSES Authentication
if ($Authentication==2) 
{
    #  push @pjl_lines, '@PJL SET KMDRIVER = ON'."\n";
      push @pjl_lines, '@PJL SET KMCERTSELECTTYPE = FLEX'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTNUM = 3'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTID1 = "ExtSvrName"'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTTYPE1 = STRING'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXSTING1 ='."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTID2 = "UsrName"'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTTYPE2 = STRING'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXSTING2 = "'.$AuthenticationUser.'"'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTID3 = "UsrPass"'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXCONTTYPE3 = STRING'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXSTING3 = "'.$AuthenticationPass.'"'."\n";
      push @pjl_lines, '@PJL SET KMCERTFLEXSCREENID = "AUTHBYERIE"'."\n";
}

if ($BoxPrint>=1) 
{
  if ($BoxPrint==1)
  { 
    push @pjl_lines, '@PJL SET BOXHOLD = STORE'."\n";
  }
  else
  {
    push @pjl_lines, '@PJL SET BOXHOLD = STOREANDPRINT'."\n";
  }

  if ($Authentication==0) 
  {
    push @pjl_lines, '@PJL SET BOXHOLDTYPE = PUBLIC'."\n";
  }

  push @pjl_lines, '@PJL SET BOXNUM = '.$BoxNumber."\n";
  push @pjl_lines, '@PJL SET BOXFILENAME = "'.$BoxFileName.'"'."\n";
}

#no A4Device
if ($A4Device==0)
{

# copy security settings

if ($CopySecurityEnable == 1)
{
    my $CharType="FIXED";
    my $CharNumber="1";     

    # security pattern
    $_= $CopySecurityCharacters;
    if ( m/A/ ) 
    {
      $CharType="ARBITRARY";
    }
    if ( m/2/ ) 
    {
      $CharNumber="2";
    }
    if ( m/3/ ) 
    {
      $CharNumber="3";
    }
    if ( m/4/ ) 
    {
      $CharNumber="4";
    }
    if ( m/5/ ) 
    {
      $CharNumber="5";
    }
    if ( m/6/ ) 
    {
      $CharNumber="6";
    }
    if ( m/7/ ) 
    {
      $CharNumber="7";
    }
    if ( m/8/ ) 
    {
      $CharNumber="8";
    }

    my $JIMONMODEHIDE="ON";
    my $COPYGUARD="OFF";
    my $PWDCOPY="OFF";

# default settings required for each copy security mode
    if ( $CopySecurityMode =~ /CopyProtect/ ) 
    {
    }

    if ( $CopySecurityMode =~ /StampReapeat/ ) 
    {
      $JIMONMODEHIDE="OFF"
    }

    if ( $CopySecurityMode =~ /CopyGuard/ ) 
    {
      $COPYGUARD="ON";
      $CopySecurityPatternAngle=0;
      $CharType="FIXED";
      $CopySecurityPatternOverwrite="COMPOSITION1";
      $CopySecurityPatternEmboss="EFFECT2";
    }

    if ( $CopySecurityMode =~ /PasswordCopy/ ) 
    {
      $PWDCOPY="ON";
      $CopySecurityPatternAngle=0;
      $CharType="FIXED";
      $CopySecurityPatternOverwrite="COMPOSITION1";
      $CopySecurityPatternEmboss="EFFECT2";
    }


# security pattern settings
    my $JIMONPATTERN='';
    my $JIMONPATTERNoff='';

    if ($CopySecurityCharacters =~ /None/)
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF";
    }
    else
    {
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN.$CharType;
    }

    if ($CopySecurityDateTime =~ /None/ )
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF,OFF";
    }

    if ( ($CopySecurityDateTime =~ /Date/)and($CopySecurityDateTime !~ /DateTime/) )
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF";
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN."DATE";
    }

    if ($CopySecurityDateTime =~ /DateTime/ )
    {
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN."DATE,TIME";
    }

    if ($CopySecuritySerialNumber==0)
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF";
    }
    else
    {
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN."SERIALNUMBER";
    }

    if ($CopySecurityDistributionControlNumber==0)
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF";
    }
    else
    {
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN."NUMBERING";
    }

    if ($CopySecurityJobNumber==0)
    {
      if ($JIMONPATTERNoff ne '') 
      {
        $JIMONPATTERNoff=$JIMONPATTERNoff.",";
      }
      $JIMONPATTERNoff=$JIMONPATTERNoff."OFF";
    }
    else
    {
      if ($JIMONPATTERN ne '') 
      {
        $JIMONPATTERN=$JIMONPATTERN.",";
      }
      $JIMONPATTERN=$JIMONPATTERN."JOBID";
    }

    if ($JIMONPATTERN ne '') 
    {
      $JIMONPATTERN=$JIMONPATTERN.",";
    }
    $JIMONPATTERN=$JIMONPATTERN.$JIMONPATTERNoff.",OFF,OFF";

    my $JIMONDATETIME='';
    if ( ($CopySecurityDateTime =~ /Date/)and($CopySecurityDateTime !~ /DateTime/) )
    {
      $JIMONDATETIME=$CopySecurityDateFormat.",OFF";
    }
    if ($CopySecurityDateTime =~ /DateTime/ )
    {
      $JIMONDATETIME=$CopySecurityDateFormat.",".$CopySecurityTimeFormat;
    }

# create PJL lines for copy security settings
      push @pjl_lines, '@PJL SET JIMONMODE = ON'."\n";
      push @pjl_lines, '@PJL SET JIMONMODEHIDE = '.$JIMONMODEHIDE."\n";
      push @pjl_lines, '@PJL SET JIMONPATTERN = "'.$JIMONPATTERN."\"\n";
      push @pjl_lines, '@PJL SET JIMONPATTERNINDEX = "'.$CharNumber.",0,0,0,0,0,0,0\"\n";
      if ($CopySecurityDateTime ne "None")
      {
        push @pjl_lines, '@PJL SET JIMONDATETIME = "'.$JIMONDATETIME."\"\n";        
      }
      push @pjl_lines, '@PJL SET JIMONCHARACTER  = "'.$CopySecurityPatternTextSize.",".
         $CopySecurityPatternEmboss.",".$CopySecurityPatternOverwrite.",".
         $CopySecurityPatternColor.",".$CopySecurityPatternDensity.",".
         $CopySecurityPatternContrast.",".$CopySecurityPatternAngle."\"\n"; 

      if ($CopySecurityDistributionControlNumber==1)
      {
        push @pjl_lines, '@PJL SET JIMONNUMBERING = "NUMBER,'.$CopySecurityDCNStart."\"\n";
      }
      push @pjl_lines, '@PJL SET JIMONBACKPATTERN = '.$CopySecurityBackgroundPattern."\n";      
      push @pjl_lines, '@PJL SET COPYGUARD='.$COPYGUARD."\n";
      push @pjl_lines, '@PJL SET PWDCOPY='.$PWDCOPY."\n";     
      if ($PWDCOPY =~ /ON/ )
      {
        push @pjl_lines, '@PJL SET PWDCOPYKEY = "'.$CopySecurityPass."\"\n";
      }
}
else
{
  push @pjl_lines, '@PJL SET JIMONMODE = OFF'."\n";
}

  
# create PJL lines for Date Time Stamp 
    if ( ($StampDateTime =~ /Date/)and($StampDateTime !~ /DateTime/) )
    {
      push @pjl_lines, '@PJL SET DTSTPMODE = ON'."\n";      
      push @pjl_lines, '@PJL SET DTSTPDATE = '.$StampDateFormat."\n";      
      push @pjl_lines, '@PJL SET DTSTPTIME = OFF'."\n";      
      push @pjl_lines, '@PJL SET DTSTPPAGE = '.$StampPages."\n";      
      push @pjl_lines, '@PJL SET DTSTPPOSITION = '.$StampPrintPosition."\n";      
      push @pjl_lines, '@PJL SET DTSTPCOLOR = '.$StampTextColor."\n";      
    }
    if ($StampDateTime =~ /DateTime/ )
    {
		push @pjl_lines, '@PJL SET DTSTPMODE = ON'."\n";      
		push @pjl_lines, '@PJL SET DTSTPDATE = '.$StampDateFormat."\n";      
		push @pjl_lines, '@PJL SET DTSTPTIME = '.$StampTimeFormat."\n";      
		push @pjl_lines, '@PJL SET DTSTPPAGE = '.$StampPages."\n";      
		push @pjl_lines, '@PJL SET DTSTPPOSITION = '.$StampPrintPosition."\n";      
		push @pjl_lines, '@PJL SET DTSTPCOLOR = '.$StampTextColor."\n";      
    }
    if ($StampDateTime =~ /None/ )
    {
      push @pjl_lines, '@PJL SET DTSTPMODE = OFF'."\n";      
    }

# create PJL lines for Page Number Stamp 
    if ($StampPageNumberEnable==1)
    {
	  # if starting number is > 1, it should beginn on first page
      if ($StampPageNumberStartingNumber ne "1" )
	  {
	    $StampPageNumberStartingPage="1";
	  }
	  
	  push @pjl_lines, '@PJL SET PAGESTAMP = "'.$StampPageNumberCoverMode.",".$StampPageNumberStartingPage.",".$StampPageNumberStartingNumber."\"\n";  
	  
	  push @pjl_lines, '@PJL SET PSTPPOSITION = '.$StampPNPrintPosition."\n";      
      push @pjl_lines, '@PJL SET PSTPCOLOR = '.$StampPNTextColor."\n";         
    }
	else
	{
	  push @pjl_lines, '@PJL SET PAGESTAMP = "NONE,1,1"'."\n";
	}

}

push @pjl_lines, "\@PJL ENTER LANGUAGE = POSTSCRIPT\n ";




my $PJLline;
my $tmp_PJLline;
foreach $PJLline (@pjl_lines)
{
$tmp_PJLline=$PJLline;
$tmp_PJLline =~ s/\n//g;
	debug_log("<PJL Header>".$tmp_PJLline);
}



#PJL footer
my $pjlfoot="\n\e\%-12345X\@PJL EOJ\n\e\%-12345X";


# According to the CUPS Software Programmers Manual the job file
# must be printed to STDOUT 

# open inputfile (file handle: INFILE) or create error message
open(INFILE, $inputfile) or die "Can't open file: $inputfile\n";

# Output PJL Header
print @pjl_lines;

if (@output)
{
	print @output;
}
else
{
	my @page=();
	# Loop over $inputfile - line by line and output to STDOUT
	while (<INFILE>)
	{
		print $_;
	
		#for each printed page output PAGE counting information to STDERR
		if ( m/\%\%Page:/ )
		{
			@page=split(/\s/,$_);
			# page counting Syntax: "PAGE:<space><pagenumber><space><number of copies><LF>"
			print STDERR "PAGE: ".$page[1]." ".$ARGV[3]."\n";
		}
	
	}
}

	
# Output PJL footer
print $pjlfoot;

# Close the input file handle
close(INFILE);


# now we are finished completely and can terminate
exit;

