#!/bin/bash
### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner='deploy'
sitesEnable='/etc/nginx/sites-enabled/'
sitesAvailable='/etc/nginx/sites-available/'
userDir='/home/deploy/'

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g.dev,staging"
	read domain
done

if [ "$rootDir" == "" ]; then
	rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain already exists.\nPlease Try Another one"
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $userDir$rootDir ]; then
			### create the directory
			mkdir $userDir$rootDir

			### give permission to root dir
			chmod 755 $userDir$rootDir
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $userDir$rootDir/phpinfo.php
				then
					echo $"ERROR: Not able to write in file $userDir/$rootDir/phpinfo.php. Please check permissions."
					exit;
			else
					echo $"Added content to $userDir$rootDir/phpinfo.php."
			fi

			exit 1
		fi

		### create virtual host rules file		
		cp -rf /opt/h5bp-nginx/sites-available/example.com $sitesAvailable$domain;
		sudo sed -i  "s#server_name www.example.com#server_name www.$domain#" $sitesAvailable$domain
		sudo sed -i  "s#scheme://example.com#scheme://$domain#" $sitesAvailable$domain
		sudo sed -i  "s#server_name example.com#server_name $domain#" $sitesAvailable$domain
		sudo sed -i  "s#root /sites/example.com/public#root $userDir$rootDir#" $sitesAvailable$domain
		

		### Add domain in /etc/hosts
		if ! echo "127.0.0.1	$domain" >> /etc/hosts
			then
				echo $"ERROR: Not able write in /etc/hosts"
				exit;
		else
				echo -e $"Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == "" ]; then
			chown -R $(whoami):www-data $userDir$rootDir
		else
			chown -R $owner:$owner $userDir$rootDir
		fi

		### enable website
		ln -s $sitesAvailable$domain $sitesEnable$domain

		### restart Nginx
		service nginx restart

		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $userDir$rootDir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain dont exists.\nPlease Try Another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			rm $sitesEnable$domain

			### restart Nginx
			service nginx restart

			### Delete virtual host rules files
			rm $sitesAvailable$domain
		fi

		### check if directory exists or not
		if [ -d $userDir$rootDir ]; then
			echo -e $"Delete host root directory ? (s/n)"
			read deldir

			if [ "$deldir" == 's' -o "$deldir" == 'S' ]; then
				### Delete the directory
				#rm -rf $userDir$rootDir
				#echo -e $"Directory deleted"
				echo ""
			else
				#echo -e $"Host directory conserved"
				echo ""
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed Virtual Host $domain"
		exit 0;
fi