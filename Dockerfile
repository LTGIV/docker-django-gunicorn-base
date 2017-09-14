################################################################################

FROM		ubuntu:xenial

LABEL		maintainer="Louis T. Getterman IV <thad.getterman@gmail.com>"

USER		root
WORKDIR		/root

################################################################################

# Build Arguments
ARG			WSGIPORT=8000

# Environment Variables
ENV			USER django
ENV			HOME /home/django
ENV			DEBIAN_FRONTEND noninteractive
ENV			PATH="/django:${HOME}/.local/bin:${PATH}"

# Port: WSGI - Django and Gunicorn (they both use the same port)
EXPOSE $WSGIPORT

# Related Directories
RUN			mkdir -pv \
				$HOME \
				;

# Create system user
RUN			useradd \
				--system \
				--no-create-home \
				--shell /bin/false \
				$USER \
			&& \
			usermod \
				--lock \
				--home $HOME \
				$USER

################################################################################

# Run
WORKDIR		$HOME

# Prerequisite software packages
RUN			apt-get -y update

# Add requested packages and modules
ADD			packages.txt		/usr/local/src/
ADD			requirements.txt	/usr/local/src/

# Install requested packages : System
RUN			/bin/bash -c "( xargs -a <(awk '! /^ *(#|$)/' "/usr/local/src/packages.txt") -r -- apt-get install -y )"	# Thanks: https://askubuntu.com/questions/252734/apt-get-mass-install-packages-from-a-file
RUN			/bin/bash -c "ln -s $( command -v python || command -v python3 ) /usr/local/bin/python"
RUN			/bin/bash -c "ln -s $( command -v pip || command -v pip3 ) /usr/local/bin/pip"

# Set permissions
RUN			chown -Rv $USER: $HOME

# Install requested packages : PIP
USER		$USER
RUN			/usr/local/bin/pip install --upgrade pip --user >/dev/null 2>&1
RUN			/usr/local/bin/pip install --user -r /usr/local/src/requirements.txt

################################################################################

# Run
ADD			entrypoint.bash			/usr/local/bin/
ENTRYPOINT	[ "bash", "/usr/local/bin/entrypoint.bash" ]

################################################################################
