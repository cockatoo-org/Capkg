#!/usr/bin/env bash
# capkg.sh - The script to kick the Capkg.
# 
#   Author: hiroaki.kubota@rakuten.co.jp
#   Date: 2010/12/28
#   Version: 1.0.0

DEPLOY=`dirname $0`/deploy.rb
if [ "$CAP" == "" ];then
    CAP=cap
fi
usage (){
cat<<USAGE
Usage    :
     capkg.sh <Operation> [options]

Operation:
  Setup environment:
     self      : Setup capkg base host.
                 Valid options --clean
     setup     : Setup capkg environment.
                 Valid options -r --clean
     createrep : Create remote repository.

  Operation:
     search    : Search package by name from remote repository.
                 Valid options (-p -a)
     list      : View installed packages into the specified host.
                 Valid options -r (-p)
     install   : Install or update the specified package to target host.
                 Valid options -r -p (-v -n -d -y -f --ignore-require )
     uninstall : Unnstall the specified package from target host.
                 Valid options -p -r (-y -f --ignore-require )
     shell     : Run shell command at target hosts.
                 Valid options --cmd --cmd-file -r 
  Developer's operation:
     create    : Create the package.
                 Valid options -c
     upload    : Upload the package to remote repository.
                 Valid options  -c -p -v
     invalidate: Invalidate the updated package.
                 Valid options  -c -p -v
     generate  : Generate the package-config skelton.
                 Valid options -p -s -i (-v --require --pre-activate --post-activate --pre-deactivate --post-deactivate)

Options  :
     -h, --help                     : This message.
     -N, --namespace                : Namespace
     -r, --remote=<hostname>        : Remote target host.
                                         Multi-specifiable
     -l, --host-list=<hostlist>     : Specify file of remote host list.
                                         Separated by changing line
     -p, --package-name=<name>      : Package name.
     -v, --version=<version>        : Package version.
     -u, --uname=<uname>            : Target uname
     -c, --capkcf=<config file>     : Package config file.
                                         [ Create , Upload , Invalidate ]
     -y, --yes                      : Auto yes answer.
                                         [ Install , Uninstall ]
     -d, --downgrade                : Allow downgrade.
                                         [ Install ]
     -n, --ignore-cache             : Ignore fetched package.
                                         [ Install ]
     -a, --search-all               : Search all version.
                                         [ Search ]
     -f, --force                    : Force uninstall. 
                                         [ Uninstall ]
     --ignore-req                   : Ignore require requiring tree.
                                         [ Install , Uninstall ]
     --clean                        : Clean all cache.
                                         [ Self , Setup ]
     -s, --scan-dir=<file or dir>   : Scan directory.
                                         [ Generate ]
                                       (Multi-specifiable) 
     -i, --install-root=<path>      : Install root path.
                                         [ Generate ]
     --require=<require definition> : Require definitions. ( '<package-name> <min-version> <max-version>' )
                                         [ Generate ]
                                       (Multi-specifiable) 
     --pre-activate=<script>        : Pre-activate script.
                                         [ Generate ]
     --post-activate=<script>       : Post-activate script.
                                         [ Generate ]
     --pre-deactivate=<script>      : Pre-deactivate script.
                                         [ Generate ]
     --post-deactivate=<script>     : Post-deactivate script.
                                         [ Generate ]
     --cmd                          : Command
                                         [ Shell ]
     --cmd-file                     : Shell script.
                                         [ Shell ]
USAGE
    exit $1
}


OP=$1
shift
HOSTS=
HLIST=
PKG=
VERSION=
UNAME=
CLEAN=
LIBS=
IROOT=
TARGETS=
CF=
YES=
FORCE=
IGNREQ=
DOWNGRADE=
NOCACHE=
SEARCHALL=
NAMESPACE=
REQUIRES=
PREACTIVATE=
POSTACTIVATE=
PREDEACTIVATE=
POSTDEACTIVATE=
CMD=
CMDFILE=
OPTIONS=`getopt -o hr:l:p:v:u:c:s:i:yfdnaN: --long help,remote:,host-list:,package-name:,version:,uname:,clean,lib:,install-root:,scan-dir:,capkcf:,yes,force,ignore-req,downgrade,ignore-cache,search-all,namespace:,require:,pre-activate:,post-activate:,pre-deactivate:,post-deactivate:,cmd:,cmd-file:, -- "$@"`
if [ $? != 0 ] ; then
 exit 1
fi
eval set -- "$OPTIONS"
while true; do
    OPT=$1
    OPTARG=$2
    case $1 in
	-h|--help) usage 0 ;;
	-r|--remote) HOSTS=$HOSTS,$OPTARG;shift;;
	-l|--host-list) HLIST=$OPTARG;shift;;
	-p|--package-name) PKG=$OPTARG;shift;;
	-v|--version) VERSION=$OPTARG;shift;;
	-u|--uname) UNAME=$OPTARG;shift;;
	--lib) LIBS=$LIBS,$OPTARG;shift;;
	-i|--install-root) IROOT=$OPTARG;shift;;
	-s|--scan-dir) TARGETS=$TARGETS,$OPTARG;shift;;
	-c|--capkcf) CF=$OPTARG;shift;;
	-y|--yes) YES='1' ;;
	-f|--force) FORCE='1' ;;
	--ignore-req) IGNREQ='1' ;;
	-d|--downgrade) DOWNGRADE='1' ;;
	-n|--ignore-cache) NOCACHE='1' ;;
	-a|--search-all) SEARCHALL='1' ;;
	-N|--namespace) NAMESPACE=$OPTARG;shift;;
	--clean) CLEAN=1 ;;
	--require) REQUIRES=$REQUIRES,$OPTARG;shift;;
	--pre-activate) PREACTIVATE=$OPTARG;shift;;
	--post-activate) POSTACTIVATE=$OPTARG;shift;;
	--pre-deactivate) PREDEACTIVATE=$OPTARG;shift;;
	--post-deactivate) POSTDEACTIVATE=$OPTARG;shift;;
	--cmd) CMD=$OPTARG;shift;;
	--cmd-file) CMDFILE=$OPTARG;shift;;
	--) shift;break;;
	*) echo "Internal error! " >&2; exit 1 ;;
    esac
    shift
done

S_PKG="-S pkg=*"
if [ ! "$PKG" == "" ];then
    S_PKG="-S pkg=$PKG"
fi
#echo $S_PKG $PKG
S_HOSTS="-S hosts="
if [ ! "$HOSTS" == "" ];then
    S_HOSTS="-S hosts=`sed 's/^,//' <<< $HOSTS`"
fi
S_HLIST="-S hlist="
if [ ! "$HLIST" == "" ];then
    S_HLIST="-S hlist=$HLIST"
fi
S_VERSION="-S version=*"
if [ ! "$VERSION" == "" ];then
    S_VERSION="-S version=$VERSION"
fi
S_UNAME="-S uname="
if [ ! "$UNAME" == "" ];then
    S_UNAME="-S uname=$UNAME"
fi
S_CLEAN="-S clean=false"
if [ ! "$CLEAN" == "" ];then
    S_CLEAN="-S clean=true"
fi
S_LIBS="-S libs="
if [ ! "$LIBS" == "" ];then
    S_LIBS="-S libs=`sed 's/^,//' <<< $LIBS`"
fi
S_YES="-S yes=false"
if [ ! "$YES" == "" ];then
    S_YES="-S yes=true"
fi
S_FORCE="-S force=false"
if [ ! "$FORCE" == "" ];then
    S_FORCE="-S force=true"
fi
S_IGNREQ="-S ignreq=false"
if [ ! "$IGNREQ" == "" ];then
    S_IGNREQ="-S ignreq=true"
fi
S_DOWNGRADE="-S downgrade=false"
if [ ! "$DOWNGRADE" == "" ];then
    S_DOWNGRADE="-S downgrade=true"
fi
S_NOCACHE="-S nocache=false"
if [ ! "$NOCACHE" == "" ];then
    S_NOCACHE="-S nocache=true"
fi
S_CF="-S capkcf="
if [ ! "$CF" == "" ];then
    S_CF="-S capkcf=$CF"
fi
S_IROOT="-S root=/"
if [ ! "$IROOT" == "" ];then
    S_IROOT="-S root=$IROOT"
fi
S_TARGETS="-S targets=*"
if [ ! "$TARGETS" == "" ];then
    S_TARGETS="-S targets=`sed 's/^,//' <<< $TARGETS`"
fi
S_SEARCHALL="-S searchall=false"
if [ ! "$SEARCHALL" == "" ];then
    S_SEARCHALL="-S searchall=true"
fi
S_NAMESPACE=""
if [ ! "$NAMESPACE" == "" ];then
    S_NAMESPACE="CAPKG_NS=$NAMESPACE"
fi
S_REQUIRES="-S requires="
if [ ! "$REQUIRES" == "" ];then
    S_REQUIRES="-S requires='$REQUIRES'"
fi
S_PREACTIVATE="-S preactivate="
if [ ! "$PREACTIVATE" == "" ];then
    S_PREACTIVATE="-S preactivate='$PREACTIVATE'"
fi
S_POSTACTIVATE="-S postactivate="
if [ ! "$POSTACTIVATE" == "" ];then
    S_POSTACTIVATE="-S postactivate='$POSTACTIVATE'"
fi
S_PREDEACTIVATE="-S predeactivate="
if [ ! "$PREDEACTIVATE" == "" ];then
    S_PREDEACTIVATE="-S predeactivate='$PREDEACTIVATE'"
fi
S_POSTDEACTIVATE="-S postdeactivate="
if [ ! "$POSTDEACTIVATE" == "" ];then
    S_POSTDEACTIVATE="-S postdeactivate='$POSTDEACTIVATE'"
fi
S_CMD="-S cmd="
if [ ! "$CMD" == "" ];then
    S_CMD="-S cmd='$CMD'"
fi
S_CMDFILE="-S cmdfile="
if [ ! "$CMDFILE" == "" ];then
    S_CMDFILE="-S cmdfile=$CMDFILE"
fi

case $OP in
    "createrep" )
	eval $S_NAMESPACE $CAP capkg:createrep  $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY 
	;;
    "self" )
	eval $S_NAMESPACE $CAP capkg:selfsetup  $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "setup" )
	eval $S_NAMESPACE $CAP capkg:setup      $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "fetch" )
	eval $S_NAMESPACE $CAP capkg:fetch      $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "install" )
	# echo $S_NAMESPACE $CAP capkg:install    $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	eval $S_NAMESPACE $CAP capkg:install    $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "uninstall" )
	# echo $S_NAMESPACE $CAP capkg:uninstall  $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	eval $S_NAMESPACE $CAP capkg:uninstall  $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "search" )
	eval $S_NAMESPACE $CAP capkg:search     $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "list" )
	eval $S_NAMESPACE $CAP capkg:list       $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "create" )
	eval $S_NAMESPACE $CAP capkg:create     $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "upload" )
	eval $S_NAMESPACE $CAP capkg:upload     $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "invalidate" )
	eval $S_NAMESPACE $CAP capkg:invalidate $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "generate" )
	eval $S_NAMESPACE $CAP capkg:generate   $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "activate" )
	eval $S_NAMESPACE $CAP capkg:activate   $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "deactivate" )
	eval $S_NAMESPACE $CAP capkg:deactivate $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "shell" )
	eval $S_NAMESPACE $CAP capkg:run_shell  $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    "t1" )
	echo $S_NAMESPACE $CAP capkg:t1         $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	eval $S_NAMESPACE $CAP capkg:t1         $S_PKG $S_VERSION $S_UNAME $S_CLEAN $S_LIBS $S_HOSTS $S_HLIST $S_YES $S_FORCE $S_IGNREQ $S_DOWNGRADE $S_NOCACHE $S_CF $S_IROOT $S_TARGETS $S_SEARCHALL $S_REQUIRES $S_PREACTIVATE $S_POSTACTIVATE $S_PREDEACTIVATE $S_POSTDEACTIVATE $S_CMD $S_CMDFILE -f $DEPLOY
	;;
    *) usage 1;;
esac
