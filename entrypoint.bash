#!/usr/bin/env bash
: <<'!COMMENT'

Adding Django to Nginx with Docker
https://Thad.Getterman.org/adding-django-to-nginx-with-docker
Louis T. Getterman IV <Thad.Getterman@gmail.com>

!COMMENT

# -------------------------------------------------------------------- FUNCTIONS

# Thanks: https://stackoverflow.com/questions/2990414/echo-that-outputs-to-stderr
echoerr() { echo "$@" 1>&2; }

#/-------------------------------------------------------------------- FUNCTIONS

echo "+---------------------------------------------------------------+"
echo "|              Adding Django to Nginx with Docker               |"
echo "| https://Thad.Getterman.org/adding-django-to-nginx-with-docker |"
echo "|       Louis T. Getterman IV <Thad.Getterman@gmail.com>        |"
echo "+---------------------------------------------------------------+"

# Command(s)
cmds=$#
cmd="${@:1}"

# If commands have been passed, run them and exit.
if [ "$cmds" -gt 0 ]; then
	if [ -d '/django' ]; then cd /django; fi
	echo "Running commands: '${cmd}'"
	/bin/sh -c "${cmd}"
	exit 0
fi

# Check for /django mount by Docker
if [ -d '/django' ]; then
	echo "/django : mounted."
	cd /django
else
	echoerr "Error: /django : not mounted."
	echoerr "Exiting."
	exit 1
fi

# Project found
if [ -f "/django/manage.py" ]; then

	projectName=`cat /django/log/.projectName | awk '{$1=$1};1'`
	echo "Project found : ${projectName}"

	# Thanks: https://www.capside.com/labs/deploying-full-django-stack-with-docker-compose/
	python /django/manage.py makemigrations
	python /django/manage.py migrate

	if [ -d '/static' ] && [ -w '/static' ]; then
		echo "/static : mounted and writable."
		echo "Collecting static files for Django."
		python /django/manage.py collectstatic --clear --verbosity 0 --no-input
		if [ "$?" -ne 0 ]; then
			echoerr "Error with collecting static files.  Aborting run."
			exit 1
		fi
	else
		echoerr "Error: /static : not mounted and writable."
	fi

	# Thanks: https://www.digitalocean.com/community/tutorials/how-to-deploy-python-wsgi-apps-using-gunicorn-http-server-behind-nginx
	workers="$(( ( 2 * `nproc` ) + 1 ))"
	echo "$(nproc) cores found : Gunicorn will launch with ${workers} workers."

	gunicorn \
		"${projectName}.wsgi" \
		--bind 0.0.0.0:8000 \
		--workers=${workers} \
		--log-level info \
		--access-logfile /django/log/gunicorn/access.log \
		--error-logfile /django/log/gunicorn/error.log \
		;

# Project not found
else

	echoerr "No project found, automatically creating one."

	# Loop for alphanumeric-only constraint
	while :; do
		read -p "What would you like to name your project? : " projectName
		if grep '^[-0-9a-zA-Z]*$' <<<$projectName ; then
			break;
		else
			echoerr "Invalid entry, please try again."
		fi
	done # END WHILE LOOP

	echo "Creating project : '${projectName}'"
	django-admin startproject ${projectName} .

	echo "Setting up log paths."
	mkdir -pv \
		/django/log/django/ \
		/django/log/gunicorn/ \
		;
	echo "${projectName}" > /django/log/.projectName

	echo "Setting up static route in /django/${projectName}/settings.py"
	echo "STATIC_ROOT = '/static'" >> "/django/${projectName}/settings.py"

fi

exit 0
