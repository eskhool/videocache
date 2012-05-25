#!/bin/bash
#
# (C) Copyright White Magnet Software Private Limited
# Company Website : http://whitemagnet.com/
# Product Website : http://cachevideos.com/
#

MESSAGE_LENGTH=70
MESSAGE_STR='.........................................................................................................'

setuptools_url='https://github.com/kulbirsaini/videocache-dependencies/blob/master/setuptools.tar.gz?raw=true'
netifaces_url='https://github.com/kulbirsaini/videocache-dependencies/blob/master/netifaces.tar.gz?raw=true'
iniparse_url='https://github.com/kulbirsaini/videocache-dependencies/blob/master/iniparse.tar.gz?raw=true'
ctypes_url='https://github.com/kulbirsaini/videocache-dependencies/blob/master/ctypes.tar.gz?raw=true'

blue_without_newline() { #{{{
  echo -en "\033[0;34m${1}\033[0m"
}

red_without_newline() {
  echo -en "\033[0;31m${1}\033[0m"
}

green_without_newline() {
  echo -en "\033[0;32m${1}\033[0m"
}

blue() {
  blue_without_newline "$1"; echo
}

red() {
  red_without_newline "$1"; echo
}

green() {
  green_without_newline "$1"; echo
}

strlen() {
  echo `expr "${1}" : '.*'`
}

message_with_padding() {
  str_len=`strlen "${1}"`
  dots=`expr ${MESSAGE_LENGTH} - ${str_len}`
  blue_without_newline "${1}${MESSAGE_STR:0:${dots}}"
} #}}}

# Options
# $1 -> Name
install_python_module() { #{{{
  archive=$1.tar.gz
  eval url=\${$1_url}
  message_with_padding "Checking module ${1}"
  output=`python -c "import ${1}" 2>&1`
  if [[ $? != 0 ]]; then
    red 'Missing'

    message_with_padding "Fetching module ${1}"
    output=`wget -q "${url}" -O /tmp/"${archive}" 2>&1`
    if [[ $? == 0 ]]; then
      green 'Done'
    else
      red 'Failed'
      red 'Please check your network connection!'
      red "${output}"
      exit 1
    fi

    mkdir -p "/tmp/${1}"
    message_with_padding "Extracting module ${1}"
    output=`tar -C /tmp/"${1}" -xzf /tmp/"${archive}" 2>&1`
    if [[ $? == 0 ]]; then
      green 'Done'
    else
      red 'Failed'
      red "${output}"
      exit 1
    fi

    message_with_padding "Installing module ${1}"
    cur_dir=`pwd`
    cd /tmp/"${1}"/*
    output=`python setup.py install 2>&1`
    if [[ $? == 0 ]]; then
      green 'Success'
    else
      red 'Failed'
      red "${output}"
      exit 1
    fi
    cd $cur_dir
    rm -rf /tmp/"${1}"
    rm -f /tmp/"${archive}"

    message_with_padding "Testing module ${1}"
    output=`python -c "import ${1}" 2>&1`
    if [[ $? == 0 ]]; then
      green 'Verified'
    else
      red 'Failed'
      red "${output}"
      exit 1
    fi
  else
    green 'Installed'
  fi
} #}}}

check_python_dev() { #{{{
  message_with_padding "Checking Python.h"
  pythonh=`python -c 'import setuptools; print setuptools.distutils.sysconfig.get_python_inc()' 2>&1`
  if [[ $? != 0 ]]; then
    red 'Failed'
    red 'Either python setuptools are not installed on your system or we can not locate them.' 
    red 'Check the error below.'
    red "${pythonh}"
    exit 1
  fi

  if [[ -f ${pythonh}/Python.h ]]; then
    green 'Installed'
    return 0
  else
    red 'Missing'
    red 'Please install python-dev or python-devel package depending on your operating system.'
  fi
  exit 1
} #}}}

install_videocache() { #{{{
  build_setup_command
  message_with_padding "Installing Videocache"
  output=`eval $setup_command`
  if [[ $? == 0 ]]; then
    green 'Installed'
    green "${output}"
  else
    red 'Failed'
    red "${output}"
    exit 1
  fi
} #}}}

get_apache_conf_dir() { #{{{
  for((i = 0; i < 3; i++)); do
    if [[ $apache_config_dir == '' ]]; then
      echo -n "Full path to Apache conf.d or extra directory (example: /etc/httpd/conf.d/): "
    else
      echo -n "Full path to Apache conf.d or extra directory (default: ${apache_config_dir}): "
    fi
    read choice
    choice=`echo $choice`
    if [[ $choice != '' ]]; then
      if [[ -d $choice ]]; then
        apache_config_dir=$choice
      else
        red_without_newline "Directory $choice doesn't exist."
        if [[ $i == 2 ]]; then
          red " Will exit now."
          exit 1
        else
          red " Try again."
          continue
        fi
      fi
    fi
    message_with_padding 'Selected Apache conf.d or extra directory'
    green $apache_config_dir
    return 0
  done
} #}}}

check_apache_with_conf_dir() { #{{{
  which $1 > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    for config_dir in /etc/apache2/conf.d/ /etc/apache/conf.d/ /etc/httpd/conf.d/ /etc/httpd/extra/ /usr/local/etc/apache22/extra/ /etc/apache22/conf.d/ ; do
      if [[ -d $config_dir ]]; then
        green 'Installed'
        apache_config_dir=$config_dir
        return 0
      fi
    done
  fi
  return 1
} #}}}

check_apache() { #{{{
  message_with_padding "Checking apache"
  for command in apachectl apache2ctl httpd apache2 apache; do
    check_apache_with_conf_dir $command
    if [[ $? == 0 ]]; then
      return 0
    fi
  done
  red 'Missing'
  return 1
} #}}}

check_squid_store_log() { #{{{
  for store_log_file in /var/log/squid/store.log /var/log/squid3/store.log /var/logs/squid/store.log /var/logs/squid3/store.log /usr/local/squid/logs/store.log /usr/local/squid3/store.log ; do
    if [[ -f $store_log_file ]]; then
      squid_store_log=$store_log_file
      return 0
    fi
  done
} #}}}

get_squid_store_log() { #{{{
  check_squid_store_log
  if [[ $squid_store_log == '' ]]; then
    squid_store_log='/var/log/squid/store.log'
    echo -n "Full path to Squid store.log file (default: /var/log/squid/store.log): "
  else
    echo -n "Full path to Squid store.log file (default: $squid_store_log): "
  fi
  read choice
  choice=`echo $choice`
  if [[ $choice != '' ]]; then
    squid_store_log=$choice
  fi
  message_with_padding "Selected Squid store.log file"
  green $squid_store_log
} #}}}

check_squid_with_conf_dir() { #{{{
  which $1 > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    for config_file in /etc/squid/squid.conf /etc/squid3/squid.conf /usr/local/etc/squid/squid.conf /usr/local/squid/etc/squid.conf /usr/local/squid3/etc/squid.conf; do
      if [[ -f $config_file ]]; then
        green 'Installed'
        return 0
      fi
    done
  fi
  return 1
} #}}}

check_squid() { #{{{
  message_with_padding "Checking squid"
  for command in squid squid3 /usr/local/sbin/squid /usr/local/sbin/squid3 /usr/local/squid/sbin/squid /usr/local/squid3/sbin/squid; do
    check_squid_with_conf_dir $command
    if [[ $? == 0 ]]; then
      return 0
    fi
  done
  red 'Missing'
  return 1
} #}}}

check_command() { #{{{
  message_with_padding "Checking ${1}"
  which $1 > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    green 'Installed'
  else
    red 'Missing'
    red "${2}"
    exit 1
  fi
} #}}}

check_dependencies() { #{{{
  check_command bash 'Download and install bash from http://www.gnu.org/software/bash/ or check your operating system manual for installing the same.'
  check_command which 'Download and install `which` utility from http://www.gnu.org/software/which/ or check your operating system manual for installing the same.'
  check_command python 'Download and install python from http://www.python.org/ or check your operating system manual for installing the same.'
  check_command wget 'Download and install wget from http://www.gnu.org/software/wget/ or check your operating system manual for installing the same.'
  check_command tar 'Download and install tar from http://www.gnu.org/software/tar/ or check your operating system manual for installing the same.'
  check_command gcc 'Download and install gcc from http://gcc.gnu.org/ or check your operating system manual for installing the same.'
} #}}}

check_root() { #{{{
  message_with_padding 'Checking root access'
  if [[ $UID != 0 ]]; then
    red 'Missing'
    red 'You must run install.sh as root user or with sudo! Aborting now. Please try again.'
    exit 1
  else
    green 'Granted'
  fi
} #}}}

install_init_script() { #{{{
  message_with_padding "Trying to set default run levels for vc-scheduler"
  which update-rc.d > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    update-rc.d vc-scheduler defaults > /dev/null 2> /dev/null
    if [[ $? == 0 ]]; then
      green 'Done'
      return 0
    fi
  fi

  which chkconfig > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    chkconfig vc-scheduler on > /dev/null 2> /dev/null
    if [[ $? == 0 ]]; then
      green 'Done'
      return 0
    fi
  fi
  red 'Failed'
  red 'Please check the init script related section of your operating system manual.'
  red 'The videocache scheduler init script is located at /etc/init.d/vc-scheduler .'
  return 1
} #}}}

detect_os_from_issue_file() { #{{{
  for file in /etc/issue /etc/issue.net; do
    if [[ -f $file ]]; then
      for os_name in Fedora CentOS RedHat Ubuntu Debian; do
        grep -i $os_name $file > /dev/null 2> /dev/null
        if [[ $? == 0 ]]; then
          OS=$os_name
          return 0
        fi
      done
    fi
  done
  return 1
} #}}}

detect_os_from_release_file() { #{{{
  OS=''
  if [[ -f /etc/fedora-release ]]; then
    OS='Fedora'
  elif [[ -f /etc/redhat-release ]]; then
    for os_name in Fedora CentOS RedHat; do
      grep -i $os_name /etc/redhat-release > /dev/null 2> /dev/null
      if [[ $? == 0 ]]; then
        OS=$os_name
        break
      fi
    done
  elif [[ -f /etc/lsb-release ]]; then
    grep -i Ubuntu /etc/lsb-release > /dev/null 2> /dev/null
    if [[ $? == 0 ]]; then
      OS='Ubuntu'
    fi
  elif [[ -f /etc/debian_version ]] || [[ -f /etc/debian_release ]]; then
    OS='Debian'
  elif [[ -f /etc/slackware-release ]] || [[ -f /etc/slackware-version ]]; then
    OS='Slackware'
  elif [[ -f /etc/mandrake-release ]]; then
    OS='Mandrake'
  elif [[ -f /etc/SUSE-release ]]; then
    OS='Suse'
  elif [[ -f /etc/gentoo-release ]]; then
    OS='Gentoo'
  fi
  if [[ $OS == '' ]]; then
    return 1
  fi
} #}}}

detect_os_using_python() { #{{{
python - <<END
try:
  import sys
  import platform
  os_dict = { 'fedora' : 'Fedora', 'redhat' : 'RedHat', 'centos' : 'CentOS', 'ubuntu' : Ubuntu, 'debian' : 'Debian', 'gentoo' : 'Gentoo', 'suse' : 'Suse', 'slackware' : 'Slackware', 'mandrake' : 'Mandrake', 'bsd' : 'BSD' }
  os_name = platform.dist('Unknown', 'Unknown', 'Unknown')[0].lower()
  if os_name in os_dict:
    print os_dict[os_name]
    sys.exit(0)
except:
  pass
sys.exit(1)
END
} #}}}

detect_os() { #{{{
  OS=$(detect_os_using_python)
  if [[ $? == 0 ]]; then
    return 0
  else
    OS=''
  fi
  detect_os_from_issue_file && return 0
  detect_os_from_release_file && return 0
  return 1
} #}}}

select_os() { #{{{
  declare -a os=('' 'Fedora' 'RedHat' 'CentOS' 'Ubuntu' 'Debian' 'Gentoo' 'Suse' 'Slackware' 'Mandrake' 'BSD' 'Other')
  menu="
  Select your Operating System.\n
  1) ${os[1]} \n
  2) ${os[2]} \n
  3) ${os[3]} \n
  4) ${os[4]} \n
  5) ${os[5]} \n
  6) ${os[6]} \n
  7) ${os[7]} \n
  8) ${os[8]} \n
  9) ${os[9]} \n
  10) ${os[10]}\n
  11) ${os[11]}"
  echo -e $menu
  for((i = 0; i < 3; i++)); do
    echo -n "Operating System Choice (type 0 to quit): "
    read choice
    case $choice in
      0)
      exit 0;;
      1|2|3|4|5|6|7|8|9|10|11)
      OS=${os[$choice]}
      return 0;;
      *)
      if [[ $i == 2 ]]; then
        echo 'You did not enter a valid input for three consecutive times.'
      else
        echo 'Invalid input. Try again.'
      fi
      ;;
    esac
  done
  return 1
} #}}}

detect_or_select_os() { #{{{
  want_to_select_os=0
  detect_os
  if [[ $? == 0 ]]; then
    message_with_padding "Automatically detected Operating System"
    green $OS
    ask_question "Do you want to select your Operating System manually? (y/n): "
    if [[ $? == 1 ]]; then
      want_to_select_os=1
    else
      want_to_select_os=0
    fi
  else
    want_to_select_os=1
  fi
  if [[ $OS == '' ]]; then
    echo 'Could not identify your Operating System automatically.'
  fi
  if [[ $OS == '' || $want_to_select_os == 1 ]]; then
    OS=''
    select_os
  fi
} #}}}

ask_question() { #{{{
  for((i = 1; i <= $tries; ++i)); do
    echo -n "$1"
    read choice
    case $choice in
      [yY] | [yY][eE][sS])
      return 1
      break;;
      [nN] | [nN][oO])
      return 0
      break;;
      *)
      if [[ $i == $tries ]]; then
        echo 'You did not enter a valid input for three consecutive times.'
        return 2
      else
        echo 'Invalid input. Please try again.'
      fi
      ;;
    esac
  done
} #}}}

check_squid_user() { #{{{
  id $1 > /dev/null 2> /dev/null
  if [[ $? == 0 ]]; then
    return 0
  fi
  return 1
} #}}}

guess_squid_user() { #{{{
  for user in squid proxy nobody; do
    check_squid_user $user
    if [[ $? == 0 ]]; then
      squid_user=$user; return 0
    fi
  done
} #}}}

get_squid_user() { #{{{
  guess_squid_user
  for((i = 0; i < 3; i++)); do
    if [[ $squid_user == '' ]]; then
      echo -n "User who run Squid daemon (example: squid or proxy or nobody): "
    else
      echo -n "User who run Squid daemon (default: ${squid_user}): "
    fi
    read choice
    choice=`echo $choice`
    if [[ $choice != '' ]]; then
      check_squid_user $choice
      if [[ $? == 0 ]]; then
        squid_user=$choice
      else
        red_without_newline "User $choice doesn't exist on system."
        if [[ $i == 2 ]]; then
          red " Will exit now."
          exit 1
        else
          red " Try again."
          continue
        fi
      fi
    fi
    message_with_padding 'Selected user who runs Squid daemon'
    green $squid_user
    return 0
  done
} #}}}

os_detection() { #{{{
  detect_or_select_os
  if [[ $? == 0 && $OS != '' ]]; then
    message_with_padding "Selected Operating System"
    green $OS
  else
    red "Operating System not detected or specified. Will continue with defaults."
  fi
} #}}}

squid_code() { #{{{
  check_squid
  if [[ $? != 0 ]]; then
    ask_question 'Installer could not detect Squid on your system. Are you sure you have Squid installed? (y/n): '
    if [[ $? == 1 ]]; then
      echo "Okay, I trust you! Let's move forward."
    else
      red 'Download and install squid from http://www.squid-cache.org/ or check your operating system manual for installing the same.'
      exit 1
    fi
  fi

  get_squid_store_log
  get_squid_user
} #}}}

apache_code() { #{{{
  ask_question 'Do you want to skip Apache configuration? (y/n): '
  if [[ $? == 1 ]]; then
    message_with_padding "Apache configuration"
    green "Skipped"
    skip_apache=1
    apache_config_dir=''
  fi
  if [[ $skip_apache == 0 ]]; then
    check_apache
    if [[ $? != 0 ]]; then
      ask_question "Installer could not detect Apache on your system. Are you sure you have Apache installed? (y/n): "
      if [[ $? == 1 ]]; then
        echo "Sure thing! Let's move forward."
      else
        red 'Download and install apache from http://www.apache.org/ or check your operating system manual for installing the same.'
        exit 1
      fi
    fi
    get_apache_conf_dir
  fi
} #}}}

get_client_email() { #{{{
  for((i = 1; i <= $tries; ++i)); do
    echo -n "Enter the email address using which you purchased Videocache: "
    read choice
    choice=`echo $choice`
    if [[ $choice == '' ]] || [[ ! $choice =~ [^@\ ]@([A-Za-z0-9]+.){1,3}[A-Za-z]{2,5}$ ]]; then
      if [[ $i == $tries ]]; then
        red "A valid email address was not entered. Will exit now."
        exit 1
      else
        echo "Invalid input. Please try again."
        continue
      fi
    else
      client_email=$choice
      message_with_padding 'Selected email address'
      green $client_email
      return 0
    fi
  done
} #}}}

is_valid_ip() { #{{{
  count=0
  for number in `echo $1 | tr '.' '\n'`; do
    number=`echo $number`
    if [[ $number == '' || $number -lt 0 || $number -gt 255 ]]; then
      return 1
    fi
    count=`expr $count + 1`
  done
  if [[ $count != 4 ]]; then
    return 1
  fi
  return 0
} #}}}

is_valid_host_port() { #{{{
  ip=`echo $1 | cut -d\: -f1`
  port=`echo $1 | grep ':' | cut -d\: -f2`
  port=`echo $port`
  is_valid_ip $ip
  if [[ $? != 0 ]]; then
    return 1
  fi
  if [[ $2 == 'check_port' && $port == '' ]]; then
    return 1
  fi
  if [[ $port == '' && $1 =~ [0-9.]+: ]]; then
    return 1
  fi
  if [[ $port != '' ]] && [[ $port -lt 1 || $port -gt 65535 ]]; then
    return 1
  fi
  return 0
} #}}}

get_cache_host() { #{{{
  ips=`ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}' | cut -d\: -f2 | cut -d\  -f1 | paste -sd ' ' -`
  for((i = 1; i <= $tries; ++i)); do
    echo -n "Enter IP address for cache_host option (available: ${ips}): "
    read choice
    choice=`echo $choice`
    is_valid_host_port $choice
    if [[ $? == 0 ]]; then
      cache_host=$choice
      message_with_padding "Selected cache_host"
      green $cache_host
      return 0
    else
      if [[ $i == $tries ]]; then
        echo "Cache host not specified. Will exit now."
        exit 1
      else
        echo "Invalid format for cache host. Please try again."
        continue
      fi
    fi
  done
} #}}}

get_this_proxy() { #{{{
  ips=`ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}' | cut -d\: -f2 | cut -d\  -f1 | paste -sd ' ' -`
  for((i = 1; i <= $tries; ++i)); do
    echo -n "Enter IPADDRESS:PORT combination for Squid proxy on this machine (example: 127.0.0.1:3128): "
    read choice
    choice=`echo $choice`
    is_valid_host_port $choice check_port
    if [[ $? == 0 ]]; then
      this_proxy=$choice
      message_with_padding "Selected proxy server"
      green $this_proxy
      return 0
    else
      if [[ $i == $tries ]]; then
        echo "Squid proxy not specified. Will exit now."
        exit 1
      else
        echo "Invalid format for squid proxy. Please try again."
        continue
      fi
    fi
  done
} #}}}

install_python_modules() { #{{{
  install_python_module setuptools "${SETUPTOOLS_URL}"
  install_python_module iniparse "${INIPARSE_URL}"
  check_python_dev
  install_python_module netifaces "${NETIFACES_URL}"
  install_python_module ctypes "${CTYPES_URL}"
} #}}}

print_info() { #{{{
  echo "Operating System: $OS"
  echo "Squid store.log: $squid_store_log"
  echo "Squid user: $squid_user"
  echo "Apache conf.d: $apache_config_dir"
  echo "Email address: $client_email"
  echo "Cache Host: $cache_host"
  echo "Squid proxy: $this_proxy"
} #}}}

build_setup_command() { #{{{
  setup_command="python setup.py --squid-user $squid_user --client-email $client_email --cache-host $cache_host --this-proxy $this_proxy --squid-store-log $squid_store_log"
  if [[ $skip_apache == 0 ]]; then
    setup_command="$setup_command --apache-dir $apache_config_dir"
  else
    setup_command="$setup_command --skip-apache-conf"
  fi
  setup_command="$setup_command 2>&1"
} #}}}

main() { #{{{
  check_root
  os_detection
  check_dependencies
  install_python_modules
  squid_code
  apache_code
  get_client_email
  get_cache_host
  get_this_proxy
  print_info
  install_videocache
  install_init_script
} #}}}

tries=2
OS=''
squid_store_log=''
squid_access_log=''
squid_user=''
skip_apache=0
apache_config_dir=''
client_email=''
cache_host=''
this_proxy=''
setup_command=''

main

