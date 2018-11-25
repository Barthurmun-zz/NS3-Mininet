#!/bin/bash
#==============================================================================
#title           : install.sh
#RUN THIS SCRIPT WHILE BEING IN ROOT MODE (SU / SUDO SU - ) !!!!!!!!!!!!!!!!!!!
#DONE FOR DEBIAN 8 & NS3.27 
#BASED ON FILES CREATED BY: 
#https://git.fslab.de/mmklab/SDN-SIMULATOR-SDWMN/tree/40040b93945571d8ceb2cbe554d9a4c3c9ed62ed
#https://github.com/dlinknctu/mininet
#https://github.com/mininet/mininet/wiki/Link-modeling-using-ns-3
#OpenNet
#==============================================================================


set -o nounset
set -e


ROOT_PATH=`pwd`
OVS_VERSION='2.4.0'
MININET_VERSION='2.2.1'
NS3_VERSION='3.27'
PYGCCXML_VERSION='1.0.0' #Mozliwa potrzeba zainstalowania nowszej wersji ! 
NETANIM_VERSION='3.108'
DIST=Unknown
RELEASE=Unknown
CODENAME=Unknown
KERNEL=1 #Jesli masz wersje jądra niższa niz 4.4 to zmien na 0


function enviroment {

    echo "Prepare Enviroment"
    apt-get install gcc g++ sudo python python-dev git vim make cmake gcc-4.8-multilib g++-4.8-multilib \
    python-setuptools unzip curl build-essential debhelper autoconf automake \
    patch dpkg-dev libssl-dev libncurses5-dev libpcre3-dev graphviz python-all \
    python-qt4 python-zopeinterface python-twisted-conch uuid-runtime \
    qt4-dev-tools python-networkx
    
	wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python

}

function pygccxml {

    echo "Fetch and install pygccxml"
    cd $ROOT_PATH
    if [ ! -f pygccxml-$PYGCCXML_VERSION.zip ]; then
        wget http://nchc.dl.sourceforge.net/project/pygccxml/pygccxml/pygccxml-1.0/pygccxml-$PYGCCXML_VERSION.zip
    fi
    unzip -o pygccxml-$PYGCCXML_VERSION.zip && cd $ROOT_PATH/pygccxml-$PYGCCXML_VERSION
    python setup.py install
    sed -e "s/gccxml_path=''/gccxml_path='\/usr\/local\/bin'/" -i /usr/local/lib/python2.7/dist-packages/pygccxml/parser/config.py

}

function gccxml {

    echo "Install gccxml"
    cd $ROOT_PATH
    if [ ! -d gccxml ]; then
        git clone https://github.com/gccxml/gccxml.git
    fi
    cd gccxml
    mkdir -p gccxml-build && cd gccxml-build
    cmake ../
    make
    make install
    if [ ! -L /bin/gccxml ]; then
        ln -s /usr/local/bin/gccxml /bin/gccxml
    fi

}

function ns3 {

    echo "Fetch ns-$NS3_VERSION"
    cd $ROOT_PATH
    if [ ! -f ns-allinone-$NS3_VERSION.tar.bz2 ]; then
        curl -O -k https://www.nsnam.org/release/ns-allinone-$NS3_VERSION.tar.bz2
    fi
    tar xf ns-allinone-$NS3_VERSION.tar.bz2
	cd ns-allinone-$NS3_VERSION/
	./build.py
	cd ns-$NS3_VERSION
	./waf configure
	./waf build
}

function netanim {

    echo "Build NetAnim"
    cd $ROOT_PATH/ns-allinone-$NS3_VERSION/netanim-$NETANIM_VERSION
    qmake-qt4 NetAnim.pro
    make
}

function mininet-opennet {

    echo "Fetch dlinknctu/mininet"
    echo "Base on Mininet $MININET_VERSION"
    cd $ROOT_PATH
    if [ ! -d mininet ]; then
        git clone --branch opennet https://github.com/dlinknctu/mininet.git
    fi

    echo "Install mininet"
    cd $ROOT_PATH/mininet/
    ./util/install.sh -n
}

function mininet-normal {

    echo "Base on Mininet $MININET_VERSION"
    cd $ROOT_PATH
    if [ ! -d mininet ]; then
		git clone git://github.com/mininet/mininet.git
		cd mininet
        git tag
		git checkout $MININET_VERSION
    fi

    echo "Install mininet"
    cd $ROOT_PATH/mininet/
    ./util/install.sh -n
}

function openvswitch {

    cd $ROOT_PATH
    wget http://openvswitch.org/releases/openvswitch-$OVS_VERSION.tar.gz
    tar zxvf openvswitch-$OVS_VERSION.tar.gz && cd openvswitch-$OVS_VERSION
    DEB_BUILD_OPTIONS='parallel=2 nocheck' fakeroot debian/rules binary
    dpkg -i $ROOT_PATH/openvswitch-switch_$OVS_VERSION*.deb $ROOT_PATH/openvswitch-common_$OVS_VERSION*.deb \
    $ROOT_PATH/openvswitch-pki_$OVS_VERSION*.deb

}

function patches {

    echo "Install Mininet-Patch"
    cd $ROOT_PATH
	if [ ! -d NS3-Mininet ]; then
		git clone https://github.com/Barthurmun/NS3-Mininet.git 
	fi
	cp NS3-Mininet/qos-tag.* $ROOT_PATH/ns-allinone-$NS3_VERSION/ns-$NS3_VERSION/src/wifi/model/
    echo "Copy files to Mininet directory"
    cp -r $ROOT_PATH/NS3-Mininet/mininet-patch/examples/* $ROOT_PATH/mininet/examples/
    cp -r $ROOT_PATH/NS3-Mininet/mininet-patch/mininet/* $ROOT_PATH/mininet/mininet/

    echo "Re-build mininet"
    cd $ROOT_PATH/mininet/
    ./util/install.sh -n

    echo "Patch NS3"
    cp $ROOT_PATH/NS3-Mininet/NS3-Patch/*.diff $ROOT_PATH/ns-allinone-$NS3_VERSION/ns-$NS3_VERSION
    cd $ROOT_PATH/ns-allinone-$NS3_VERSION/ns-$NS3_VERSION/
	git apply ns-3-patch-wifi-wds-v322.diff 
	if [ `echo $KERNEL` == 1 ]; then	
		git apply Kernel_440_above_patch.diff
	fi	
    sed -e "s/\['network'\]/\['internet', 'network', 'core'\]/" -i src/tap-bridge/wscript
    
	cd $ROOT_PATH/ns-allinone-$NS3_VERSION/ns-$NS3_VERSION/
    ./waf
}


function waf {

    WAF_SHELL=$ROOT_PATH/waf_shell.sh
    echo "#!/bin/sh" > $WAF_SHELL
    echo "cd $ROOT_PATH/ns-allinone-$NS3_VERSION/ns-$NS3_VERSION/" >> $WAF_SHELL
    echo "./waf shell" >> $WAF_SHELL
    chmod +x $WAF_SHELL

}

function all {

	enviroment
    pygccxml
    gccxml
    ns3
    netanim
    mininet-opennet #Change "mininet-opennet" for "mininet-normal" if you do not want to install OpenNet
    openvswitch
    patches
    waf

}

function description {

	echo "You need to add an argument to succesfully run this script !"
	echo "Possible options:"
	echo "  
		a)  all;;
        p)  pygccxml;;
        g)  gccxml;;
        n)  ns3;;
        i)  netanim;;
        m)  mininet-opennet ;;
        s)  openvswitch;;
        o)  opennet;;
        w)  waf;;  "
}

PARA='amdhenipgoswf'
if [ $# -eq 0 ]
then
    description
else
    while getopts $PARA OPTION
    do
        case $OPTION in
        a)  all;;
        p)  pygccxml;;
        g)  gccxml;;
        n)  ns3;;
        i)  netanim;;
        m)  mininet-opennet;;
        s)  openvswitch;;
        o)  patches;;
        w)  waf;;
        esac
    done
    shift $(($OPTIND - 1))
fi
