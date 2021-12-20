#!/bin/bash

siteminder_parent_dir={{ siteminder_parent_dir }}
siteminder_dir_name={{ siteminder_dir_name }}
remote_temp_dir_path={{ remote_temp_dir_path }}
remote_temp_dir_name={{ remote_temp_dir_name }}

cd $siteminder_parent_dir

# Get directory ACLs in alphabetical order for siteminder
#find . -maxdepth 1 -type d -iname "$siteminder_dir_name" -print0 | xargs -0 -I{.} find -L {.} -type d -not -path "*/modules" | cut -d'/' -f2- | sort | xargs -I {} getfacl -t {} >> $remote_temp_dir_path/$siteminder_dir_name-getfacl-dirs.txt

# Get file ACLs in alphabetical order for siteminder
#find . -maxdepth 1 -type d -iname "$siteminder_dir_name" -print0 | xargs -0 -I{.} find -L {.} -type f -not -path "*/logs*" | cut -d'/' -f2- | LC_ALL=C sort | xargs -I {} getfacl -t {} >> $remote_temp_dir_path/$siteminder_dir_name-getfacl-files.txt

# Copy siteminder files etc. to the temp remote directory for siteminder
rsync -av $siteminder_dir_name $remote_temp_dir_path/

cp $siteminder_parent_dir/$remote_temp_dir_name.sh $remote_temp_dir_path/
tar -czf $remote_temp_dir_name.tar.gz $remote_temp_dir_name
rm -rf $remote_temp_dir_name

