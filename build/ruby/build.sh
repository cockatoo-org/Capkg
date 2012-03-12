#!/usr/bin/env bash
cd `dirname $0`
source ../build.env
# export http_proxy=<set http_proxy if you need to use>
run export HTTP_PROXY=${http_proxy}
run export https_proxy=${http_proxy}
run export HTTPS_PROXY=${http_proxy}

run git --version
if [ "$?" != "0" ];then
    echo 'You need to setup git command !!'
    exit 1;
fi
# check & update cert
curl https://github.com/ -o /dev/null
if [ "$?" = "60" ];then
    echo 'The SSL cert file (OS bundle) is probably obusolute.'
    echo 'Do you update it ? [Y/N]'
    read INPUT
    if [ "$INPUT" != "Y" ];then
	echo 'Interrupted !!'
       	exit 1;
    fi
    run sudo cp /etc/pki/tls/certs/ca-bundle.crt{,.bk}
    run sudo curl http://curl.haxx.se/ca/cacert.pem -o /etc/pki/tls/certs/ca-bundle.crt
fi

# [RUBY]
RVM_PATH=/usr/local/rvm
echo '------------------'
echo "Clean ${RVM_PATH}"
echo '------------------'
run sudo rm -rf ${RVM_PATH}
run sudo rm -rf rvmrc
echo '------------------'
echo "Install RVM to ${RVM_PATH}"
echo '------------------'
run sudo mkdir -p  ${RVM_PATH}
run sudo chmod 777 ${RVM_PATH}
echo "rvm_path=/usr/local/rvm" > rvmrc
run ln -sfT `pwd`/rvmrc ~/.rvmrc
if [ "${http_proxy}" != "" ];then
    run git config --global gitcore.proxy ${http_proxy}
fi
run wget https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer
run bash rvm-installer stable
run source "${RVM_PATH}/scripts/rvm"
run rvm install 1.8.7
run rvm use 1.8.7
run sudo chmod 755 ${RVM_PATH}
run gem install capistrano
run cap --version
#rvm install 1.9.1
#rvm use 1.9.1
run ruby -v
run sudo chown root:bin -R ${RVM_PATH}
#run sudo chmod 755 -R ${RVM_PATH}
