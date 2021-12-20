#!/bin/bash

httpd_instances_dir={{ httpd_instances_dir }}
httpd_instances="{{ httpd_instances.stdout | regex_replace('\\n', ' ') }}"
remote_temp_dir_path={{ remote_temp_dir_path }}
remote_temp_dir_name={{ remote_temp_dir_name }}

cd $httpd_instances_dir

for httpd_instance in $httpd_instances
do
  # Get directory ACLs in alphabetical order for the target httpd instance
  find . -maxdepth 1 -type d -iname "$httpd_instance" -print0 | xargs -0 -I{.} find -L {.} -type d -not -path "*/modules" | cut -d'/' -f2- | sort | xargs -I {} getfacl -t {} >> $remote_temp_dir_path/$httpd_instance-getfacl-dirs.txt
  
  # Get file ACLs in alphabetical order for the target httpd instance
  find . -maxdepth 1 -type d -iname "$httpd_instance" -print0 | xargs -0 -I{.} find -L {.} -type f -not -path "*/logs*" | cut -d'/' -f2- | LC_ALL=C sort | xargs -I {} getfacl -t {} >> $remote_temp_dir_path/$httpd_instance-getfacl-files.txt
  
  # Get module listing in alphabetical order for the target httpd instance
  find . -maxdepth 1 -type d -iname "$httpd_instance" -print0 | xargs -0 -I{.} find -L {.} -type f \( -iname "*.so" \) | cut -d'/' -f2- | sort | xargs -I {} echo {} >> $remote_temp_dir_path/$httpd_instance-modules.txt

  # Copy httpd config files etc. to the temp remote directory for the target httpd instance
  rsync -av $httpd_instance $remote_temp_dir_path/ --exclude $httpd_instance/logs --exclude $httpd_instance/tls --exclude $httpd_instance/run --exclude $httpd_instance/www/html
done

cp $httpd_instances_dir/$remote_temp_dir_name.sh $remote_temp_dir_path/
tar -czf $remote_temp_dir_name.tar.gz $remote_temp_dir_name
rm -rf $remote_temp_dir_name

