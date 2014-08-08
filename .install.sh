#!/bin/bash

##
##	CONFIGURATION
##

script="$0"
if [[ "$(echo "/$(ls -ld $0 | cut -d '/' -f 2-)" | grep -)" != "" ]]; then
	script=$(echo "/$(ls -ld $0 | cut -d '/' -f 2-)" | grep - | cut -d '>' -f 2- | cut -c 2-)
fi
script_directory=$(echo `dirname $script`)
username_current="$1"

configfile="$script_directory/media_server.cfg"
if [[ -f "$configfile" ]]; then echo "
Found config file:		$configfile
" >&2 && source "$configfile"; else echo "
Could not find config file. Are all the relevant scripts and files in the right directory?
" >&2 && exit 1; fi

##
##	FUNCTIONS
##

# Checks the OS being used
check_os () {
	if [ "$(uname)" = "Darwin" ]; then
		OS="Mac"
		HandBrakeCLI="$handbrake_location/HandBrakeCLI"
	elif [ "$(uname)" = "Linux" ]; then
		OS="Linux"
		HandBrakeCLI=$(whereis HandBrakeCLI | cut -d ' ' -f 2)
	else
		echo "Your Operating System is not supported. Please request support via GitHub. If you feel there is an issue, please post it on GitHub."
		exit
	fi
}

# Install transmission-daemon for Mac (includes MacPorts, and agreeing to Xcode's license agreement)
install_transmission_daemon_mac () {
# Install Xcode Command-line Tools
wget -O CLITools.dmg http://adcdownload.apple.com/Developer_Tools/command_line_tools_os_x_10.9_for_xcode__late_july_2014/command_line_tools_for_os_x_mavericks_late_july_2014.dmg
hdiutil attach CLITools.dmg
echo "
On your Mac, please now install the Xcode Command-line Tools. The disk image has been mounted. You can find it using Finder.

Once installed successfully, please hit [ENTER]:	">&2
read finished_xcode_install

echo "You will now have to accept the license agreement for Xcode before you can continue.
" >&2
sleep 3
xcodebuild -license

wget -O MacPortsVersion.html http://www.macports.org/install.php
macports_version_number=$(echo $(cat MacPortsVersion.html | grep "MacPorts version " | cut -d '>' -f 2- | cut -d ' ' -f 3))
rm MacPortsVersion.html
macports_latest_url="https://distfiles.macports.org/MacPorts/MacPorts-$macports_version_number.tar.gz"
wget -O MacPortsSource.tar.gz $macports_latest_url
tar -xvf MacPortsSource.tar.gz && rm MacPortsSource.tar.gz
cd MacPorts-*
./configure && make && sudo make install



}

# Installer script for each program
installer_script () {
	case "$1" in
	transmission_daemon_linux)
		if [[ $transmission_daemon ]]; then
		add-apt-repository -y ppa:transmissionbt/ppa
		apt-get update
		apt-get install transmission-common transmission-daemon transmission-cli
		apt-get -f install
		fi
	;;
	handbrakecli_mac)
		if [[ $handbrakecli ]]; then
		wget -O HandBrakeCLI.dmg http://sourceforge.net/projects/handbrake/files/0.9.9/HandBrake-0.9.9-MacOSX.6_CLI_x86_64.dmg/download
		handbrake_image_location=$(hdiutil attach HandBrakeCLI.dmg | grep /Volumes/ | awk -F $'\t' '{print $NF}')
		handbrake_image_raw=$(hdiutil attach HandBrakeCLI.dmg | grep /Volumes/ | awk -F $'\t' '{print $1}')
		cp $handbrake_image_location/HandBrakeCLI /usr/local/bin/
		diskutil unmountDisk $handbrake_image_raw
		rm HandBrakeCLI.dmg
		fi
	;;
	handbrakecli_linux)
		if [[ $handbrakecli ]]; then
		add-apt-repository -y ppa:stebbins/handbrake-releases
		apt-get update
		apt-get install handbrake-cli
		apt-get -f install
		fi
	;;
	openssh_server)
		if [[ $openssh ]]; then
		apt-get install openssh-server
		apt-get -f install
		fi
	;;
	duckdns)
		if [[ $duckdns ]]; then
		echo "
Do you have a dynamic address for duckdns.org? [y/n]" >&2
		read answer
		if [[ "$(echo $answer | cut -c 1)" == "y" || "$(echo $answer | cut -c 1)" == "Y" ]]; then
			if [[ -d "/usr/local/bin/duckdns" ]]; then
				rm -rf "/usr/local/bin/duckdns"
				mkdir "/usr/local/bin/duckdns"
			else
				mkdir "/usr/local/bin/duckdns"
			fi
			touch /usr/local/bin/duckdns/duck.sh
			chmod +x /usr/local/bin/duckdns/duck.sh
			echo "
What is your dynamic address for duckdns.org? e.g. for someaddress.duckdns.org type someaddress in below and then hit [ENTER]" >&2
			read dynamicaddress
			echo "
Visit duckdns.org and sign in with your login. On the home screen to the website, there will now be a token shown.
The token is a long sequence of letters, numbers, and hyphons. Copy this and paste it below:

What is your token for duckdns.org?" >&2
			read token
			duckdns_command="echo url=\"https://www.duckdns.org/update?domains=$dynamicaddress&token=$token&ip=\" | curl -k -o /usr/local/bin/duckdns/duck.log -K -"
			echo $duckdns_command >> "/usr/local/bin/duckdns/duck.sh"
			if [[ "$(crontab -u $username_current -l | grep duck.sh)" == "" ]]; then
				line="*/5 * * * * /usr/local/bin/duckdns/duck.sh >/dev/null 2>&1"
				(crontab -u $username_current -l; echo "$line" ) | crontab -u $username_current -
			fi
			/usr/local/bin/duckdns/duck.sh
			if [[ "$(cat /usr/local/bin/duckdns/duck.log)" == "OK" ]]; then echo "DuckDNS installed successfully. Please continue."; else echo "DuckDNS has not been installed correctly, please seek advice on installation from https://www.duckdns.org" >&2; fi
		fi
		
		fi
	;;
	plexmediaserver_mac)
		if [[ $pms ]]; then
		plexmediaserver_version=0.9.9.14.531-7eef8c6
		wget -O PlexMediaServer.zip http://downloads.plexapp.com/plex-media-server/$plexmediaserver_version/PlexMediaServer-$plexmediaserver_version-OSX.zip >/dev/null 2>&1
		tar -xvf PlexMediaServer.zip >/dev/null 2>&1
		rm PlexMediaServer.zip
		if [[ -e "/Applications/Plex Media Server.app" ]]; then rm /Applications/Plex\ Media\ Server.app; fi
		mv Plex\ Media\ Server.app /Applications/Plex\ Media\ Server.app >/dev/null 2>&1
		spctl --add --label "Plex_Media_Server" /Applications/Plex\ Media\ Server.app
		spctl --enable --label "Plex_Media_Server"
		open /Applications/Plex\ Media\ Server.app
		echo "
You can now manage your Plex Media Server at the following address:

http://localhost:32400/web/index.html	(from the computer itself)
http://$ip_address:32400/web/index.html	(from any other computer on the network)
" >&2
		fi
	;;
	plexmediaserver_linux)
		if [[ $pms ]]; then
		add-apt-repository -y "deb http://www.plexapp.com/repo lucid main"
		apt-get update
		apt-get install plexmediaserver
		ip_address="$(ifconfig | grep "Bcast" | grep "inet" | cut -d ":" -f 2 | cut -d ' ' -f 1)"
		echo "
You can now manage your Plex Media Server at the following address:

http://localhost:32400/web/index.html	(from the computer itself)
http://$ip_address:32400/web/index.html	(from any other computer on the network)
" >&2
		fi
	;;
	plexhometheater)
		if [[ $pht ]]; then
		echo "
Please understand that running Plex Home Theater on the same machine as the server is NOT recommended. All resources should be given to the server.

Roku sell extremely cheap Plex clients. Roku's Roku 3 is the best solution at around £70/\$100.

Are you certain you wish to install it? [y/n]"
		read plexht_answer
		if [[ "$(echo $plexht_answer | cut -c 1)" == "y" || "$(echo $plexht_answer | cut -c 1)" == "Y" ]]; then
			echo "Would be installing PHT here" >&2
		fi
		fi
	;;
	filebot_mac)
		if [[ $filebot ]]; then
		wget -O filebot.html http://www.filebot.net >/dev/null 2>&1
		filebot_version=$(cat filebot.html | grep ".app" | awk -F 'type=app' '{print $2}' | awk -F '_' '{print $NF}' | awk -F '.app' '{print $1}' | tail -n 1)
		rm filebot.html
		filebot_url="http://sourceforge.net/projects/filebot/files/filebot/FileBot_$filebot_version""/FileBot_$filebot_version"".app.tar.gz/download"
		wget -O filebot.app.tar.gz $filebot_url >/dev/null 2>&1
		tar -xvf filebot.app.tar.gz >/dev/null 2>&1
		rm filebot.app.tar.gz
		if [[ -e "/Applications/FileBot.app" ]]; then rm "/Applications/FileBot.app"; fi
		mv FileBot.app /Applications/FileBot.app >/dev/null 2>&1
		spctl --add --label "FileBot" /Applications/FileBot.app
		spctl --enable --label "FileBot"
		fi
	;;
	filebot_linux)
		if [[ $filebot ]]; then
		wget -O filebot.html http://www.filebot.net
		filebot_version=$(cat filebot.html | grep deb | awk -F 'amd64' '{print $(NF-1)}' | awk -F '_' '{print $(NF-1)}')
		rm filebot.html
		filebot_url="http://sourceforge.net/projects/filebot/files/filebot/FileBot_$filebot_version""/filebot_$filebot_version""_amd64.deb/download"
		wget -O filebot.deb $filebot_url
		dpkg -i filebot.deb
		apt-get -f -y install
		rm filebot.deb
		fi
	;;
	makemkv_mac)
		if [[ $makemkv ]]; then
		echo "Would be installing MakeMKV here" >&2
		fi
	;;
	makemkv_linux)
		if [[ $makemkv ]]; then
		echo "Would be installing MakeMKV here" >&2
		fi
	;;
	avahi_daemon)
		if [[ $avahi ]]; then
		apt-get install avahi-daemon
		fi
	;;
	ssh_daemon)
		if [[ $openssh ]]; then
		systemsetup -setremotelogin on
		fi
	;;
	esac
}

##
##	SCRIPT
##

# Checks the operating system being used to determine which script to run
check_os

# Warns the user of any issues, known constraints of using their OS
warning_message

# Installer for each OS
if [[ "$OS" == "Mac" ]]; then
	installer_script handbrakecli_mac
	installer_script filebot_mac
	installer_script plexmediaserver_mac
	installer_script plexhometheater
	installer_script duckdns
	installer_script ssh_daemon
	echo "

The installation has finished. Please enjoy your server! Download and watch responsibly!

" >&2
elif [[ "$OS" == "Linux" ]]; then
	installer_script handbrakecli_linux
	installer_script filebot_linux
	installer_script plexmediaserver_linux
	installer_script transmission_daemon_linux
	installer_script duckdns
	installer_script avahi_daemon
	installer_script openssh_server
	echo "

The installation has finished. Please enjoy your server! Download and watch responsibly!

You may have to update the permissions of your media directories by running the following commands on them:
\`sudo chown $username_current:plex -R [YOUR MEDIA DIRECTORY HERE]\`
\`sudo chmod 770 -R [YOUR MEDIA DIRECTORY HERE]\`

To update and upgrade your system, please run the following command regularly:

\`sudo apt-get update && sudo apt-get -y upgrade\` 

" >&2
fi