#!/usr/bin/perl

# KMbeuPS Driver Installation Routine
# Version 3.0
# August 12th 2016
# Jan Heinecke
# Filename:	install.pl
# 

use strict;
use Cwd;


# default cups configuration files folder
my @DefaultCupsConfigFolder=();
$DefaultCupsConfigFolder[0]="/etc/cups"; 

# DataDir and ServerBin are defined in cupsd.conf and since CUPS 1.6 they are defined 
# in the cups-files.conf
# 
# here some default path information, in case DataDir and ServerBin directives cannot be 
# found in cupsd.conf or cups-files.conf

# default DataDir, if not defined in cupsd.conf
my @DefaultDataDir=();
$DefaultDataDir[0]="/usr/share/cups"; 

# default ServerBin, if not defined in cupsd.conf
my @DefaultServerBin=();
$DefaultServerBin[0]="/usr/lib/cups"; 
$DefaultServerBin[1]="/usr/libexec/cups";
$DefaultServerBin[2]="/usr/lib32/cups";

# ini file containing the filter filename for installation
my $inifile="kmdriverini.txt";


my $CupsConfigFolder;
my $CupsFilesConf;
my $CupsDConf;
my $DataDirSearch='DataDir\s+';
my $ServerBinSearch='ServerBin\s+';
my $DataDir;
my $ServerBin;
my $PPDDir;
my $FilterDir;

my $user_input;
my $FolderDetectionEnd=0;
my $i;

my $install_type="shell";
my $txt_msg="";
my $txt_backtitle=" Installation procedure for Konica Minolta drivers";
my $txt_title="";
my $error_txt="";

## check if "whiptail" or "dialog" is available for user friendly dialog input

my $dialog = `dialog --version 2>&1 3>&1`;
if (!($dialog =~ /not found/)) {
	$install_type="dialog";
}else{
	my $whiptail = `whiptail -v 2>&1 3>&1`;
	if ( ! ( $whiptail =~ /not found/ ) ) {
		$install_type="whiptail";
	}
}



print "\nInstallation procedure for Konica Minolta drivers is starting.\n";
print "**************************************************************\n\n";

# detect ServerRoot, DataDir and ServerBin
detect_cups_config();

#if DataDir and ServerBin not known, search default locations for PPD and filter
find_datadir();
find_serverbin();

# check for PDD and Filter destination
check_ppdfolder();
check_filterfolder();

# if write access to folder or folder creation failed, probably "root" credentials missing
# confirm to continue with script in this case
if ($error_txt ne ""){
			$txt_title="Error during folder detection";
			$txt_msg="Following problem(s) occured:\n";
			$txt_msg.=$error_txt;
			$txt_msg.="\nThe install script requires \"root\" credentials.\n";
			$txt_msg.="Continue with the installation?\n";
	$user_input="n";
	if ($install_type eq "whiptail"){
		$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
	}
	if ($install_type eq "dialog"){
		$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
	}
	if ($install_type eq "shell"){
		print "Following problem(s) occured:\n";
		print $error_txt;
		print "\nThe install script requires \"root\" credentials.\n";
		print "To continue with the installation enter: y\n>";
		chomp ($user_input=<STDIN>);
	}
	$user_input =~ s/[ \t\r\n\v\f]+//;
	if ($user_input ne "y"){
		print "Installation aborted ...\n>";
		exit;
	}  
}

#if PPD or Filter folder not detected, ask user for input
set_ppdfolder();
set_filterfolder();

#confirm installation folders or abort
$txt_title="Installation folders";			
$txt_msg="Files will be installed in following folders:\n";
$txt_msg.="PPD folder: $PPDDir\n";
$txt_msg.="Filter folder: $FilterDir\n";
$txt_msg.="\nContinue with the installation?\n";

$user_input="n";
if ($install_type eq "whiptail"){
	$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
}
if ($install_type eq "dialog"){
	$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
}
if ($install_type eq "shell"){
	print "\nFiles will be installed in following folders:\n";
	print "PPD folder: $PPDDir\n";
	print "Filter folder: $FilterDir\n";
	print "To continue with the installation enter: y\n>";
	chomp ($user_input=<STDIN>);
}
$user_input =~ s/[ \t\r\n\v\f]+//;
if ($user_input ne "y"){
	print "Installation aborted ...\n>";
	exit;
}  

installFilterfiles();
installPPDfiles();


	$txt_title="Installation procedure finished!\n";
			$txt_msg="The installation procedure has finished.\n";
			$txt_msg.="Please restart CUPS deamon now.\n Depending on OS you may use:\n";
			$txt_msg.="  # service cups restart\n";
			$txt_msg.="  # /etc/init.d/cups restart\n";
			$txt_msg.="  # /etc/init.d/cupsys restart\n";
			$txt_msg.="  # /etc/rc.d/rc.cups restart\n";
			$txt_msg.="\nAfter restarting CUPS deamon, printers can be installed using the
CUPS web interface or any CUPS printer administration tool.\n";
			$user_input="n";
			if ($install_type eq "whiptail"){
				`whiptail --backtitle "$txt_backtitle" --title "$txt_title" --msgbox "$txt_msg" 14 78  3>&1 1>&2 2>&3`;
			}
			if ($install_type eq "dialog"){
				`dialog --backtitle "$txt_backtitle" --title "$txt_title" --msgbox "$txt_msg" 14 78  3>&1 1>&2 2>&3`
			}
			if ($install_type eq "shell"){
				print $txt_title;
				#create model folder
				print $txt_msg;
			}



exit;
####################
# End of main script
####################




# detect ServerRoot, DataDir and ServerBin
sub detect_cups_config{
  
	# get ServerRoot, DataDir and ServerBin from environment (cups-config command)
	my $ServerRootEnv=`cups-config --serverroot`;
	my $DataDirEnv=`cups-config --datadir`;
	my $ServerBinEnv=`cups-config --serverbin`;

	$ServerRootEnv =~ s/[ \t\r\n\v\f]+//;
	$DataDirEnv =~ s/[ \t\r\n\v\f]+//;
	$ServerBinEnv =~ s/[ \t\r\n\v\f]+//;

	if(-d "$ServerRootEnv"){
		$CupsConfigFolder = $ServerRootEnv;
	}
	if(-d "$DataDirEnv"){
		$DataDir = $DataDirEnv;
		if(-d "$ServerBinEnv"){
			$ServerBin = $ServerBinEnv;
			$FolderDetectionEnd=1;
		}
	}

	# check if if cups configuration files folder is accessible
	# only executed if ServerRoot cannot be found using cups-config command
	if(!(defined($CupsConfigFolder))){
	  print "Search for Cups Configuration files.\n";
	  for ($i=0; $i<@DefaultCupsConfigFolder;$i++)
	  {
	    if(-d "$DefaultCupsConfigFolder[$i]"){
	      $CupsConfigFolder = $DefaultCupsConfigFolder[$i];
	      last;
	    }
	  }
	}

	# search for cups-files.conf and cupsd.conf
	# try to get DataDir and ServerBin information from cups-files.conf (first priority) 
	# or from cupsd.conf 
	# only executed if DataDir or ServerBin cannot be found using cups-config command
	$user_input=$DefaultCupsConfigFolder[0];
	while ($FolderDetectionEnd==0) {
		if(!(defined($CupsConfigFolder))){
			print "Cannot determine the Cups configuration folder [default: /etc/cups], containing ";
			print "[cupsd.conf / cups-files.conf] ! \n";
		}
		if(defined($CupsConfigFolder)){
			$CupsFilesConf="$CupsConfigFolder\/cups-files.conf";
			if ( (-e $CupsFilesConf) && (-r $CupsFilesConf)){
				print "Search in $CupsFilesConf for DataDir and ServerBin directives.\n";
				if (open (CUPSCONF, $CupsFilesConf)) {
					while (<CUPSCONF>)	{
						if (m/$DataDirSearch/i)		{
							chomp $_;
							my($tmp1 , $tmp2) = split /\s+/,$_,2;
							$DataDir = $tmp2;
							#$PPDDir="$DataDir\/model";
						}
						if(m/$ServerBinSearch/i){
							chomp $_;
							my($tmp1 , $tmp2) = split /\s+/,$_,2;
							$ServerBin = $tmp2;
							#$FilterDir="$ServerBin\/filter";
						}				
					}
				}
				else{	
					print "Can't open file: $CupsFilesConf\n";
				}
			}
			else
			{
				print "Can't find file: $CupsFilesConf\n";
				print "$CupsFilesConf has been introduced with Cups 1.6\n";
			}
			if (!(defined($DataDir) && defined($ServerBin))){
				$CupsDConf="$CupsConfigFolder\/cupsd.conf";
				if ( (-e $CupsDConf) && (-r $CupsDConf)){
					print "Search in $CupsDConf for DataDir and ServerBin directives.\n";
					if (open (CUPSCONF, $CupsDConf)) {
						while (<CUPSCONF>)	{
							if (m/$DataDirSearch/i)		{
								chomp $_;
								my($tmp1 , $tmp2) = split /\s+/,$_,2;
								$DataDir = $tmp2;
								#$PPDDir="$DataDir\/model";
							}
							if(m/$ServerBinSearch/i){
								chomp $_;
								my($tmp1 , $tmp2) = split /\s+/,$_,2;
								$ServerBin = $tmp2;
								#$FilterDir="$ServerBin\/filter";
							}				
						}
					}
					else{	
						print "Can't open file: $CupsDConf\n";
					}
				}
				else
				{
					print "Can't find file: $CupsDConf\n";
				}		
			}
			
		}
		if (!(defined($DataDir) && defined($ServerBin))){
	
			$txt_title="Detecting CUPS configuration failed";
			$txt_msg="Can't find DataDir and ServerBin directives.\n";
			$txt_msg.="Please input location where to find the CUPS configuration files \n";
			$txt_msg.="(cups-files.conf or cupsd.conf). Default location: /etc/cups\n";
			$txt_msg.="<cancel> to skip the folder detection.\n";
			$txt_msg.="(You may be asked later where to install PPD files and filter.)\n";

			if ($install_type eq "whiptail"){
				if (!($user_input=`whiptail --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`)) {
					$FolderDetectionEnd=1;
				}else{
					$CupsConfigFolder=$user_input;
				}
			}
			if ($install_type eq "dialog"){
				if (!($user_input=`dialog --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`)) {
					$FolderDetectionEnd=1;
				}else{
					$CupsConfigFolder=$user_input;
				}
			}

			if ($install_type eq "shell"){
				print "Can't find DataDir and ServerBin directives.\n";
				print "Please input location where to find the CUPS configuration files \n";
				print "(cups-files.conf or cupsd.conf). Default location: /etc/cups\n";
				print "To skip the folder detection, type: skip\n";
				print "(You may be asked later where to install PPD files and filter.)\n>";
				chomp ($user_input=<STDIN>);
				if ($user_input eq "skip"){
					$FolderDetectionEnd=1;
				}else{
					$CupsConfigFolder=$user_input;
				}
			}
		}
	
		if ((defined($DataDir) && defined($ServerBin))){
			$FolderDetectionEnd=1;
			print "DataDir: $DataDir\n";
			print "ServerBin: $ServerBin\n";
	
		}
	} 

}



sub find_datadir{
	#search default PPD location
	if(!(defined($DataDir))){
		print "Search known default locations for installing PPD files.\n";
		for ($i=0; $i<@DefaultDataDir;$i++){
			print "search $DefaultDataDir[$i]\/model\n";
			if(-d "$DefaultDataDir[$i]\/model"){
				if(-w "$DefaultDataDir[$i]\/model"){
					$PPDDir = "$DefaultDataDir[$i]\/model";
					print ("PPD folder $PPDDir found\n");
					last;
				}else{
					#print ("No write access to PPD folder: $DefaultDataDir[$i]\/model\n");
					$error_txt.="No write access to PPD folder: $DefaultDataDir[$i]\/model\n";
				}
			}
		}
	}
}

sub find_serverbin{
	#search default filter location
	if(!(defined($ServerBin))){
		print "Search known default locations for installing PPD files.\n";
		for ($i=0; $i<@DefaultServerBin;$i++){
			print "search $DefaultServerBin[$i]\/filter\n";
			if(-d "$DefaultServerBin[$i]\/filter"){
				if(-w "$DefaultServerBin[$i]\/filter"){
					$FilterDir = "$DefaultServerBin[$i]\/filter";
					print ("Filter location $FilterDir found\n");
					last;
				}else{
					#print ("No write access to filter location: $DefaultServerBin[$i]\/filter\n");
					$error_txt.="No write access to filter location: $DefaultServerBin[$i]\/filter\n";						
				}
			}
		}
	}
}


#if DataDir and ServerBin are known, check locations for PPD and filter 	
#search model folder based on DataDir location
sub check_ppdfolder{
	if ((defined($DataDir))){
		print ("check PPD folder: $DataDir\/model\n");
		if(-d "$DataDir\/model"){
			if(-w "$DataDir\/model"){
				$PPDDir = "$DataDir\/model";
				print ("PPD folder $PPDDir found\n");
			}else{
				#print ("No write access to PPD folder: $DataDir\/model\n");
				$error_txt.="No write access to PPD folder: $DataDir\/model\n";
			}
		}else{
			$txt_title="Folder detection failed\n";
			$txt_msg="Can't find folder for PPD files: $DataDir\/model\n";
			$txt_msg.="Create folder $DataDir\/model now?\n";
			$user_input="n";
			if ($install_type eq "whiptail"){
				$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
			}
			if ($install_type eq "dialog"){
				$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
			}
			if ($install_type eq "shell"){
				print "Can't find folder for PPD files: $DataDir\/model\n";
				#create model folder
				print "To create folder $DataDir\/model now enter: y\n>";
				chomp ($user_input=<STDIN>);
			}
			$user_input =~ s/[ \t\r\n\v\f]+//;
			if ($user_input eq "y"){
				if (mkdir "$DataDir\/model"){
					print "$DataDir\/model folder created\n";
					$PPDDir = "$DataDir\/model";				
				}else{
					#print "Could not create folder: $DataDir\/model\n";
					$error_txt.="Could not create folder: $DataDir\/model\n";
				}
			}
		}
	}
}

#search filter folder based on ServerBin location
sub check_filterfolder{
	if (defined($ServerBin)){
		print ("check filter folder: $ServerBin\/filter\n");
		if(-d "$ServerBin\/filter"){
			if(-w "$ServerBin\/filter"){
				$FilterDir = "$ServerBin\/filter";
				print ("filter folder $FilterDir found\n");
			}else{
				#print ("No write access to filter folder: $ServerBin\/filter\n");
				$error_txt.="No write access to filter folder: $ServerBin\/filter\n";
			}
		}else{

			$txt_title="Folder detection failed\n";
			$txt_msg="Can't find folder for filter files: $ServerBin\/filter\n";
			$txt_msg.="Create folder $ServerBin\/filter now?\n";
			$user_input="n";
			if ($install_type eq "whiptail"){
				$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
			}
			if ($install_type eq "dialog"){
				$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
			}
			if ($install_type eq "shell"){
				print "Can't find folder for filter files: $ServerBin\/filter\n";
				#create model folder
				print "To create folder $ServerBin\/filter now enter: y\n>";
				chomp ($user_input=<STDIN>);
			}

			$user_input =~ s/[ \t\r\n\v\f]+//;
			if ($user_input eq "y"){
				if (mkdir "$ServerBin\/filter"){
					print "$ServerBin\/filter folder created\n";
					$FilterDir = "$ServerBin\/filter";				
				}else{
					#print "Could not create folder: $ServerBin\/filter\n";
					$error_txt.="Could not create folder: $ServerBin\/filter\n";
				}
			}

		}
	}
}


sub set_ppdfolder{
	#If PPDDir not known, ask for it
	if (!(defined($PPDDir))){
		my $PPDDirFound=0;
		$error_txt="";
		while ($PPDDirFound==0){
			$user_input=$PPDDir;
			$txt_title="PPD Folder";
			$txt_msg=$error_txt;
			$txt_msg.="Please input where the PPD files should be installed.\n";
			$txt_msg.="<cancel> will abort the installation.\n";
			$error_txt=""; #reset error message
			if ($install_type eq "whiptail"){
				if (!($user_input=`whiptail --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`))
				{
					print "Installation aborted ...\n";
					exit;
				}
			}
			if ($install_type eq "dialog"){
				if (!($user_input=`dialog --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`))
				{
					print "Installation aborted ...\n";
					exit;
				}
			}
			if ($install_type eq "shell"){
				print "\nPlease input where the PPD files should be installed.\n";
				print "To abort installation process enter: exit\n>";
				chomp ($user_input=<STDIN>);
			}

			if ($user_input eq "exit"){
				print "Installation aborted ...\n";
				exit;
			}
			
			if ($user_input ne ""){
				$PPDDir=$user_input;
				if(-d "$PPDDir"){
					if(-w "$PPDDir"){
						$PPDDirFound=1;
					}
					else{
						print ("No write access to PPD folder: $PPDDir\n");
						$error_txt="No write access to PPD folder: $PPDDir\n";
					}
				}
				else{


					
					$txt_msg="Can't find folder for PPD files: $PPDDir\n";
					$txt_msg.="Create folder $PPDDir now?\n";
					$user_input="n";
					if ($install_type eq "whiptail"){
						$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
					}
					if ($install_type eq "dialog"){
						$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
					}
					if ($install_type eq "shell"){
						print "Can't find folder for PPD files: $PPDDir\n";
						print "To create folder $PPDDir now enter: y\n>";
						chomp ($user_input=<STDIN>);
					}

					$user_input =~ s/[ \t\r\n\v\f]+//;
					if ($user_input eq "y"){
						if (mkdir "$PPDDir"){
							print "$PPDDir folder created\n";
							$PPDDirFound=1;				
						}else{
							print "Could not create folder: $PPDDir\n";
							$error_txt="Could not create folder: $PPDDir\n";
						}
					}

				}
			}	
			
		}
	}
}


sub set_filterfolder{
	#If FilterDir not known, ask for it
	if (!(defined($FilterDir))){
		my $FilterDirFound=0;
		$error_txt="";
		while ($FilterDirFound==0){
			$user_input=$FilterDir;
			$txt_title="Filter Folder";
			$txt_msg=$error_txt;
			$txt_msg.="Please input where the PPD files should be installed.\n";
			$txt_msg.="<cancel> will abort the installation.\n";
			$error_txt=""; #reset error message
			if ($install_type eq "whiptail"){
				if (!($user_input=`whiptail --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`))
				{
					print "Installation aborted ...\n";
					exit;
				}
			}
			if ($install_type eq "dialog"){
				if (!($user_input=`dialog --backtitle "$txt_backtitle" --title "$txt_title" --inputbox "$txt_msg" 12 78 "$user_input" 3>&1 1>&2 2>&3`))
				{
					print "Installation aborted ...\n";
					exit;
				}
			}
			if ($install_type eq "shell"){
				print "\nPlease input where the PPD files should be installed.\n";
				print "To abort installation process enter: exit\n>";
				chomp ($user_input=<STDIN>);
			}

			if ($user_input eq "exit"){
				print "Installation aborted ...\n";
				exit;
			}
			
			if ($user_input ne ""){
				$FilterDir=$user_input;
				if(-d "$FilterDir"){
					if(-w "$FilterDir"){
						$FilterDirFound=1;
					}
					else{
						print ("No write access to Filter folder: $FilterDir\n");
						$error_txt="No write access to Filter folder: $FilterDir\n";
					}
				}
				else{


					
					$txt_msg="Can't find folder for Filter files: $FilterDir\n";
					$txt_msg.="Create folder $FilterDir now?\n";
					$user_input="n";
					if ($install_type eq "whiptail"){
						$user_input=`if (whiptail --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`;
					}
					if ($install_type eq "dialog"){
						$user_input=`if( dialog --backtitle "$txt_backtitle" --title "$txt_title" --yesno "$txt_msg" 12 78  3>&1 1>&2 2>&3) then echo "y" \nfi`
					}
					if ($install_type eq "shell"){
						print "Can't find folder for Filter files: $FilterDir\n";
						print "To create folder $FilterDir now enter: y\n>";
						chomp ($user_input=<STDIN>);
					}

					$user_input =~ s/[ \t\r\n\v\f]+//;
					if ($user_input eq "y"){
						if (mkdir "$FilterDir"){
							print "$FilterDir folder created\n";
							$FilterDirFound=1;				
						}else{
							print "Could not create folder: $FilterDir\n";
							$error_txt="Could not create folder: $FilterDir\n";
						}
					}

				}
			}	
			
		}
	}
}

sub installFilterfiles{
	# read filter files from ini
	# read version information from files
	# check existing filter files and read version
	# select filter files to be installed/overwritten
	# copy files

	my @FilterMatrix; #store PPD details in matrix ; for each PPD :filename, model, version, oldversion if exists
	
	my @Filters=getFilterFiles($inifile);
	my $counter=0;
	my $filter;
	foreach $filter (@Filters){
		# filename
		my $temp=$filter;
		$filter =~ s/.*<file>//;
		$filter =~ s/<\/file>.*//;
		$filter =~ s/^\"+//;
		$filter =~ s/^\s+//;
		$filter =~ s/\s+$//;
		$FilterMatrix[$counter][0]=$filter;
		# description
		$temp =~ s/.*<description>//;
		$temp =~ s/<\/description>.*//;
		$temp =~ s/^\"+//;
		$temp =~ s/^\s+//;
		$temp =~ s/\s+$//;
		$FilterMatrix[$counter][1]=$temp;
		#file version
		$FilterMatrix[$counter][2]=getFilterVersion(cwd()."\/$filter");
		if(-e "$FilterDir/$filter"){
			$FilterMatrix[$counter][3]=getFilterVersion("$FilterDir/$filter");
		}
		else{
			$FilterMatrix[$counter][3]=0;
		}
		$counter++;
	}


	$txt_title="Select Filter files";
	$txt_msg="Please select filter files to be installed. \nThe version number in brackets shows already installed filter version.";
	$user_input="";
	#unfortunately whiptail checklist is not scrollable as dialog 
	#depending on number of PPDs checklist may need to be shown multiple times
	if ($install_type eq "whiptail"){
		my $limit=12;
		my $counter2=0;$i=0;
		my $checklist="";
		while ($i<$counter){
			$checklist.=" \"$FilterMatrix[$i][0]\" ";
			if ($FilterMatrix[$i][3]==0){
				$checklist.=" \"$FilterMatrix[$i][1] v$FilterMatrix[$i][2]\" ";
			}else{
				$checklist.=" \"$FilterMatrix[$i][1] v$FilterMatrix[$i][2] (v$FilterMatrix[$i][3])\" ";
			}
			if(($FilterMatrix[$i][3]==0)||($FilterMatrix[$i][2]>$FilterMatrix[$i][3]))
			{
				$checklist.=" ON ";
			}else{
				$checklist.=" OFF ";
			}
			$i++; $counter2++;
			
			if (($i>=$counter)||($counter2>=$limit))
			{
				$checklist="$counter2 $checklist";
				# adding " y" is required, otherwise script will abort if nothin is selected

				if (!($user_input.=`if(whiptail --backtitle "$txt_backtitle" --title "$txt_title" --checklist "$txt_msg" 20 78 $checklist 3>&1 1>&2 2>&3) then echo " y" \nfi`))
				{
					print "Installation aborted ...\n";
					exit;
				}else{
					$user_input.=" ";
				}
				$counter2=0;
				$checklist="";			
			}
		}	
	}

	if ($install_type eq "dialog"){
		my $checklist="$counter";
		for($i=0;$i<$counter; $i++){
			$checklist.=" \"$FilterMatrix[$i][0]\" ";
			if ($FilterMatrix[$i][3]==0){
				$checklist.=" \"$FilterMatrix[$i][1] v$FilterMatrix[$i][2]\" ";
			}else{
				$checklist.=" \"$FilterMatrix[$i][1] v$FilterMatrix[$i][2] (v$FilterMatrix[$i][3])\" ";
			}
			if(($FilterMatrix[$i][3]==0)||($FilterMatrix[$i][2]>$FilterMatrix[$i][3]))
			{
				$checklist.=" ON ";
			}else{
				$checklist.=" OFF ";
			}
		}
		# adding " y" is required, otherwise script will abort if nothin is selected
		if (!($user_input=`if(dialog --backtitle "$txt_backtitle" --title "$txt_title" --checklist "$txt_msg" 18 78 $checklist 3>&1 1>&2 2>&3) then echo " y" \nfi`))
		{
			print "Installation aborted ...\n";
			exit;
		}else{
		}
	}

	if ($install_type eq "shell"){
		print "\nPlease select Filter files to be installed.\n";
		$user_input="";
		for($i=0;$i<$counter; $i++){
			print "$FilterMatrix[$i][0]\t";
			print "$FilterMatrix[$i][1]\t";
			print "v$FilterMatrix[$i][2]\t";
			if ($FilterMatrix[$i][3]!=0){
				print "overwrite v$FilterMatrix[$i][3]";
			}
			print "\n";
			print "Install Filter file ? [y] ";
				my $overwrite_decision="n";
				$overwrite_decision=<STDIN>;
				chomp $overwrite_decision;
				if(($overwrite_decision eq ('y' or 'Y'))or(length($overwrite_decision)==0)){
					$user_input.="$FilterMatrix[$i][0] ";
				}
		}
	}

	$user_input =~ s/\"//g;
	my @filter_inst=split (/\s+/,$user_input);

	foreach my $val (@filter_inst){
		if(($val ne "y")&&($val ne "")){
#print "*$val*\n";
			copyFilter($val,$FilterDir);
		}
	}


	
}


sub installPPDfiles{
	# read and select PPDs
	# get list of PPDs to be installed
	# read model and version from PPD
	# check existing PPDs and read version
	# select PPDs to be installed/overwritten
	# copy files


	my @PPDMatrix; #store PPD details in matrix ; for each PPD :filename, model, version, oldversion if exists
	
	my @PPDs=getPPDFiles(cwd());
	my $counter=0;
	my $ppd;
	foreach $ppd (@PPDs){
		
		my $newversion=0;
		my $oldversion=0; 
		my $VersionCheck=0;
		$ppd =~ s/^\"+//;
		$ppd =~ s/^\s+//;
		$ppd =~ s/\s+$//;
		$PPDMatrix[$counter][0]=$ppd;
		$PPDMatrix[$counter][1]=getPPDModel($ppd);
		$PPDMatrix[$counter][2]=getPPDVersion($ppd);
		if(-e "$PPDDir/$ppd"){
			$PPDMatrix[$counter][3]=getPPDVersion("$PPDDir/$ppd");
		}
		else{
			$PPDMatrix[$counter][3]=0;
		}
		$counter++;
	}


	$txt_title="Select PPD files";
	$txt_msg="Please select PPD files to be installed. \nThe version number in brackets shows already installed PPD version.\n";
	$user_input="";
	#unfortunately whiptail checklist is not scrollable as dialog 
	#depending on number of PPDs checklist may need to be shown multiple times
	if ($install_type eq "whiptail"){
		my $limit=12;
		my $counter2=0;$i=0;
		my $checklist="";
		while ($i<$counter){
			$checklist.=" \"$PPDMatrix[$i][0]\" ";
			if ($PPDMatrix[$i][3]==0){
				$checklist.=" \"$PPDMatrix[$i][1] v$PPDMatrix[$i][2]\" ";
			}else{
				$checklist.=" \"$PPDMatrix[$i][1] v$PPDMatrix[$i][2] (v$PPDMatrix[$i][3])\" ";
			}
			if(($PPDMatrix[$i][3]==0)||($PPDMatrix[$i][2]>$PPDMatrix[$i][3]))
			{
				$checklist.=" ON ";
			}else{
				$checklist.=" OFF ";
			}
			$i++; $counter2++;
			
			if (($i>=$counter)||($counter2>=$limit))
			{
				$checklist="$counter2 $checklist";
				# adding " y" is required, otherwise script will abort if nothin is selected
				if (!($user_input.=`if(whiptail --backtitle "$txt_backtitle" --title "$txt_title" --checklist "$txt_msg" 20 78 $checklist 3>&1 1>&2 2>&3) then echo " y" \nfi`))
				{
					print "Installation aborted ...\n";
					exit;
				}else{
					$user_input.=" ";
				}
				$counter2=0;
				$checklist="";			
			}
		}
	}


	if ($install_type eq "dialog"){
		my $checklist="$counter";
		for($i=0;$i<$counter; $i++){
			$checklist.=" \"$PPDMatrix[$i][0]\" ";
			if ($PPDMatrix[$i][3]==0){
				$checklist.=" \"$PPDMatrix[$i][1] v$PPDMatrix[$i][2]\" ";
			}else{
				$checklist.=" \"$PPDMatrix[$i][1] v$PPDMatrix[$i][2] (v$PPDMatrix[$i][3])\" ";
			}
			if(($PPDMatrix[$i][3]==0)||($PPDMatrix[$i][2]>$PPDMatrix[$i][3]))
			{
				$checklist.=" ON ";
			}else{
				$checklist.=" OFF ";
			}
		}
		# adding " y" is required, otherwise script will abort if nothin is selected
		if (!($user_input=`if(dialog --backtitle "$txt_backtitle" --title "$txt_title" --checklist "$txt_msg" 18 78 $checklist 3>&1 1>&2 2>&3) then echo " y" \nfi`))
		{
			print "Installation aborted ...\n";
			exit;
		}else{
		}
	}

	if ($install_type eq "shell"){
		print "\nPlease select PPD files to be installed.\n";
		$user_input="";
		for($i=0;$i<$counter; $i++){
			print "$PPDMatrix[$i][0]\t";
			print "$PPDMatrix[$i][1]\t";
			print "v$PPDMatrix[$i][2]\t";
			if ($PPDMatrix[$i][3]!=0){
				print "overwrite v$PPDMatrix[$i][3]";
			}
			print "\n";
			print "Install PPD file ? [y] ";
				my $overwrite_decision="n";
				$overwrite_decision=<STDIN>;
				chomp $overwrite_decision;
				if(($overwrite_decision eq ('y' or 'Y'))or(length($overwrite_decision)==0)){
					$user_input.="$PPDMatrix[$i][0] ";
				}
		}
	}

	$user_input =~ s/\"//g;
	my @ppd_inst=split (/\s+/,$user_input);

	foreach my $val (@ppd_inst){
		if(($val ne "y")&&($val ne "")){
			copyPPD($val,$PPDDir);
		}
	}


}


sub getPPDFiles{
	my @files=();
	my $folder=shift @_;
	if ((-e $folder) && (-r $folder)){
		if (opendir my($fh), $folder){
			while (defined(my $file= readdir ($fh) )){
				next if $file=~ /^\.\.?$/;
				next if $file!~ /\.[pP][pP][dD]$/;
				if(-f "$folder\/$file")
				{
					push @files,"$file";
				}
			}
			closedir $fh;
		}
		else{
			print "Cannot access current working directory."
		}
	}	
    return @files;
}

sub getPPDModel{ 
	my $ppd=shift @_;
	my $version="";
	open(PPD,$ppd) or die "Cannot open $ppd: $!";
	while(<PPD>){
		if(m/ModelName/){


			s/\*//;
			s/[ \t\r\n\v\f]+//; # remove any whitespace 
			s/\"//;
			s/\"//;

			s/^\"+//;
			s/^\s+//;
			s/\s+$//;
			
			my($versionmarker,$versionnumber)=split/:/,$_,2;
			$version=$versionnumber;
			last;
		}
					
	}
	close(PPD);
	return $version;
				
}

sub getPPDVersion{ 
	my $ppd=shift @_;
	my $version="";
	open(PPD,$ppd) or die "Cannot open $ppd: $!";
	while(<PPD>){
		if(m/FileVersion/){
			s/\*//;
			s/[ \t\r\n\v\f]+//; # remove any whitespace 
			s/\s+$//;			
			s/\"//;
			s/\"//;
			my($versionmarker,$versionnumber)=split/:/,$_,2;
			$version=$versionnumber;
			last;
		}
					
	}
	close(PPD);
	return $version;
				
}

sub copyPPD{
	my $PPD=@_[0];
	my $PPDDir=@_[1];
        $PPD =~ s/^\s+//;
        $PPD =~ s/\s+$//;

	`cp $PPD $PPDDir`;	
    chmod (0644,$PPDDir."/".$PPD);
}

sub getFilterFiles{
	my $inifile= shift @_;
	my @filterfiles=();
	open(INIFILE,$inifile);
	while(<INIFILE>){
		if(m/<filterfile>/){
#			s/<filterfile>//;
#			s/<\/filterfile>//;
#			s/\s//;
#			s/\n//;
			push (@filterfiles,$_);
		}
	}
	return @filterfiles;		
}

sub getFilterVersion{ 
	my $filter=@_[0];
	my $version="";
	open(FILTER,$filter) or die "Cannot open $filter: $!";
	while(<FILTER>){
		if(m/Version/){
			s/\#//;			
			s/[ \t\r\n\v\f]+//; # remove any whitespace 
			s/\s+//;			
			s/\s+//;			

			my($versionmarker,$versionnumber)=split/:/,$_,2;
			$version=$versionnumber;
			last;
		}
					
	}
	close(FILTER);
	return $version;
				
}


sub copyFilter{
	my $filter=@_[0];
	my $FilterDir=@_[1];
        $filter =~ s/^\s+//;
        $filter =~ s/\s+$//;

	`cp $filter $FilterDir`;	
    chmod (0755,$FilterDir."/".$filter);
}

