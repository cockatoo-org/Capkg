# -*- coding: utf-8 -*-
# capkg.rb - Capkg core.
#   Capkg is the packager on the Capistrano.
# 
#   Author: hiroaki.kubota@rakuten.co.jp
#   Date: 2011/05/26
require 'open3'
module Capkg
  VERSION = "1.1.12"
  SELF_NAME = 'CAPKG'
  LOCAL_CAPKG_DIR = File.dirname(__FILE__)
  # Log lv
  CAPKG_LOG_DEBUG  = 999
  CAPKG_LOG_NOTICE = 9
  CAPKG_LOG_INFO   = 7
  CAPKG_LOG_MESSAGE= 5
  CAPKG_LOG_WARN   = 3
  CAPKG_LOG_ERROR  = 1

  module DefaultSettings
    CAPKG_LOG_DEFAULT=CAPKG_LOG_MESSAGE
    NAMESPACE                = 'default'
    FETCH_METHOD             = 'ssh'
    REPOSITORY_METHOD        = 'ssh'
    # HTTP-REPOSITORY
    HTTP_PROXY               = nil
    HTTP_REPOSITORY          = nil
    HTTP_REPOSITORY_CERT     = nil
    # SSH-REPOSITORY
    SSH_REPOSITORY_HOST      = 'localhost'
    SSH_REPOSITORY_PATH      = '/usr/local/capkg-rep'
    # TARGET-HOST
    CAPKG_BASE               = '/usr/local/capkg'
    # OWNER
    RUNNER                   = 'root'
    GROUP                    = 'bin'
    # LOG
    LOG_EXPIRE_DATE          = 90      
    # MD5
    MD5_CHECK                = 'no'
    MD5_FETCH_METHOD         = nil
    MD5_REPOSITORY_METHOD    = nil
    MD5_HTTP_REPOSITORY      = nil
    MD5_HTTP_REPOSITORY_CERT = nil
    MD5_SSH_REPOSITORY_HOST  = nil
    MD5_SSH_REPOSITORY_PATH  = nil

    NOARCH='NoArch'
    GET_UNAME_CMD = 'head -1 /etc/issue| sed '+"'"+'s/^\(Fedora\|Ubuntu\|Debian\|CentOS\|Red Hat\)[^0-9]\+\([0-9]\+\).*$/\1\2-/'+"'"+'|tr -d \\\\n[:space:] ;uname -m'
    #GET_UNAME_CMD = 'head -1 /etc/issue| sed '+"'"+'s/^\(Fedora\|Ubuntu\|Debian\|CentOS\|Red Hat\)[^0-9\.]\+\([0-9\.]\+\).*$/\1\2-/'+"'"+'|tr -d \\\\n[:space:] ;uname -m'
    UNAME_RULE = {
      NOARCH => [],
      'Linux' => [NOARCH],
      'Linux-i686' => ['Linux'],
      'Linux-x86_64' => ['Linux'],
      'CentOS' => ['Linux'],
      'CentOS-i686' => ['CentOS','Linux-i686'],
      'CentOS-x86_64' => ['CentOS','Linux-x86_64'],
      'CentOS5' => ['CentOS'],
      'CentOS5-i686' => ['CentOS5','CentOS-i686'],
      'CentOS5-x86_64' => ['CentOS5','CentOS-x86_64'],
      'RedHat' => ['Linux'],
      'RedHat-i686' => ['RedHat','Linux-i686'],
      'RedHat-x86_64' => ['RedHat','Linux-x86_64'],
      'RedHat3' => ['RedHat'],
      'RedHat3-i686' => ['RedHat3','RedHat-i686'],
      'RedHat3-x86_64' => ['RedHat3','RedHat-x86_64'],
      'RedHat4' => ['RedHat'],
      'RedHat4-i686' => ['RedHat4','RedHat-i686'],
      'RedHat4-x86_64' => ['RedHat4','RedHat-x86_64'],
      'RedHat5' => ['RedHat'],
      'RedHat5-i686' => ['RedHat5','RedHat-i686'],
      'RedHat5-x86_64' => ['RedHat5','RedHat-x86_64'],
      'Debian' => ['Linux'],
      'Debian-i686' => ['Debian','Linux-i686'],
      'Debian-x86_64' => ['Debian','Linux-x86_64'],
      'Debian3' => ['Debian'],
      'Debian3-i686' => ['Debian3','Debian-i686'],
      'Debian3-x86_64' => ['Debian3','Debian-x86_64'],
      'Debian4' => ['Debian'],
      'Debian4-i686' => ['Debian4','Debian-i686'],
      'Debian4-x86_64' => ['Debian4','Debian-x86_64'],
      'Debian5' => ['Debian'],
      'Debian5-i686' => ['Debian5','Debian-i686'],
      'Debian5-x86_64' => ['Debian5','Debian-x86_64'],
      'Fedora' => ['Linux'],
      'Fedora-i686' => ['Fedora','Linux-i686'],
      'Fedora-x86_64' => ['Fedora','Linux-x86_64'],
      'Fedora11' => ['Fedora'],
      'Fedora11-i686' => ['Fedora11','Fedora-i686'],
      'Fedora11-x86_64' => ['Fedora11','Fedora-x86_64'],
      'Fedora13' => ['Fedora'],
      'Fedora13-i686' => ['Fedora13','Fedora-i686'],
      'Fedora13-x86_64' => ['Fedora13','Fedora-x86_64'],
      'Ubuntu' => ['Linux'],
      'Ubuntu-i686' => ['Ubuntu','Linux-i686'],
      'Ubuntu-x86_64' => ['Ubuntu','Linux-x86_64'],
    }
    #######################################
    # Definitions
    #######################################
    # Directories
    DIR_BK   = '.bk'
    DIR_INST = 'inst'
    DIR_TMP  = 'tmp'
    DIR_PKG  = 'pkg'
    # Filenames
    FN_ALLTXT= 'all.txt'
    FN_FETCHTXT= 'fetch.txt'
    FN_INSTTXT= 'active.txt'
    FN_TASK_ERROR='error.txt'
    FN_TASK_OUT='out.txt'
    #
    FN_PREACTIVATE = '.preactivate'
    FN_POSTACTIVATE = '.postactivate'
    FN_PREDEACTIVATE = '.predeactivate'
    FN_POSTDEACTIVATE = '.postdeactivate'
    FN_ACTIVATE = '.activate'
    FN_DEACTIVATE = '.deactivate'
    FN_REQUERE = '.require'
    FN_ISSUE='issue.txt'
    FN_LOCK='LOCK'
  end

  module Def
    include DefaultSettings
    # Host config
    HOSTCONFIG=File.expand_path(File.dirname(__FILE__))+'/'+`hostname`.chomp+'.rb'
    begin
      require HOSTCONFIG
      include Settings
      print "Using " + HOSTCONFIG + "\n"
    rescue LoadError
      print "Nothing " + HOSTCONFIG + "\n"
    end
    # Namespace config
    if  ENV['CAPKG_NS']
      NAMESPACE=ENV['CAPKG_NS']
    end
    if NAMESPACE != ''
      NAMESPACE_CONFIG=File.expand_path(File.dirname(__FILE__))+'/'+NAMESPACE+'.rb'
      begin
        require NAMESPACE_CONFIG
        include NamespaceSettings
        print "Using " + NAMESPACE_CONFIG + "\n"
      rescue LoadError
        print "Nothing " + NAMESPACE_CONFIG + "\n"
      end
    end

    SSH_REPOSITORY_PATH     = SSH_REPOSITORY_PATH+'/'+NAMESPACE
    HTTP_REPOSITORY         = HTTP_REPOSITORY ? HTTP_REPOSITORY+'/'+NAMESPACE : nil

    MD5_FETCH_METHOD         = MD5_FETCH_METHOD         ? MD5_FETCH_METHOD         : FETCH_METHOD
    MD5_REPOSITORY_METHOD    = MD5_REPOSITORY_METHOD    ? MD5_REPOSITORY_METHOD    : REPOSITORY_METHOD
    MD5_HTTP_REPOSITORY      = MD5_HTTP_REPOSITORY      ? MD5_HTTP_REPOSITORY+'/'+NAMESPACE      : HTTP_REPOSITORY
    MD5_HTTP_REPOSITORY_CERT = MD5_HTTP_REPOSITORY_CERT ? MD5_HTTP_REPOSITORY_CERT : HTTP_REPOSITORY_CERT
    MD5_SSH_REPOSITORY_HOST  = MD5_SSH_REPOSITORY_HOST  ? MD5_SSH_REPOSITORY_HOST  : SSH_REPOSITORY_HOST 
    MD5_SSH_REPOSITORY_PATH  = MD5_SSH_REPOSITORY_PATH  ? MD5_SSH_REPOSITORY_PATH+'/'+NAMESPACE  : SSH_REPOSITORY_PATH

    CAPKG_BASE=CAPKG_BASE+'/'+NAMESPACE
    BASE_TMP= CAPKG_BASE+'/' + DIR_TMP
    BASE_PKG= CAPKG_BASE+'/' + DIR_PKG
    BASE_INST=CAPKG_BASE+'/' + DIR_INST
    FETCHTXT= BASE_PKG + '/' + FN_FETCHTXT
    INSTTXT = BASE_INST+ '/' + FN_INSTTXT
    LOCKFILE= BASE_TMP + '/' + FN_LOCK
    # local repository
    LOCAL_ROOT= ENV['HOME']+ '/.capkg'
    LOCAL_REP = LOCAL_ROOT + '/' + NAMESPACE
    LOCAL_PKG = LOCAL_REP  + '/pkg'
    LOCAL_HOST= LOCAL_REP  + '/host'
    LOCAL_TMP = LOCAL_REP  + '/tmp'
    LOCAL_LOG = LOCAL_REP  + '/log'
    ALLTXT    = LOCAL_REP  + '/' + FN_ALLTXT

    if HTTP_PROXY != nil
      ENV['HTTP_PROXY']=HTTP_PROXY
      ENV['http_proxy']=HTTP_PROXY
    end
    if HTTP_PROXY == ''
      ENV.delete('HTTP_PROXY')
      ENV.delete('http_proxy')
    end

    if not ENV['CAPKG_LOGLV']
      CAPKG_LOGLV=CAPKG_LOG_DEFAULT
    else
      CAPKG_LOGLV=ENV['CAPKG_LOGLV'].to_i
    end
    # Debug UNAME
    if  ENV['DEBUG_UNAME']
      GET_UNAME_CMD='echo '+ENV['DEBUG_UNAME']
    end
  end  # module Def

  Dir::chdir(ENV['PWD'])

  #######################################
  # LOCAL utils (capistrano host)
  #######################################
  module Logger
    @@LOG=nil
    def self.start_log(pkgname,version,pkguname,fmt,*args)
      now=Time.now.localtime
      expire=(now-60*60*24*Def::LOG_EXPIRE_DATE).strftime('%Y%m%d').to_i
      # expire=(now-60*60*24*3).strftime('%Y%m%d').to_i
      Dir.open(Def::LOCAL_LOG){
        |dp|
        dp.each{
          |f|
          if /^capkg(\d{8})\.log$/ =~ f 
            if ( expire >= $1.to_i ) 
              LocalCmd.rm(Def::LOCAL_LOG+'/'+f)
            end
          end
        }
      }
      @@LOG = File.open(now.strftime(Def::LOCAL_LOG+'/capkg%Y%m%d.log'),'a+')
      @@LOG.print '== START ' + now.strftime('%Y/%m/%d %H:%M:%S') + "==\n"
      msg('LOCAL',pkgname,version,pkguname,fmt,*args)
    end
    def self.end_log(pkgname,version,pkguname,fmt,*args)
      now=Time.now.localtime
      msg('LOCAL',pkgname,version,pkguname,fmt,*args)
      @@LOG.print '== END   ' + now.strftime('%Y/%m/%d %H:%M:%S') + "==\n"
      @@LOG.close
    end
    def self.errmsg(host,pkgname,version,pkguname,fmt,*args)
      estr = 'ERROR :'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_ERROR
        printf('%s',estr)
      end
      log(estr)
      return estr
    end
    def self.warnmsg(host,pkgname,version,pkguname,fmt,*args)
      estr = 'WARN :'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_WARN
        printf('%s',estr)
      end
      log(estr)
      return estr
    end
    def self.notice(host,pkgname,version,pkguname,fmt,*args)
      estr = 'NOTICE:'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_NOTICE
        printf('%s',estr)
      end
      log(estr)
      return estr
    end
    def self.info(host,pkgname,version,pkguname,fmt,*args)
      estr = 'INFO  :'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_INFO 
        printf('%s',estr)
      end
      log(estr)
      return estr
    end
    def self.msg(host,pkgname,version,pkguname,fmt,*args)
      estr = 'MSG   :'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_MESSAGE
        printf('%s',estr)
      end
      log(estr)
      return estr
    end
    def self.debug(host,pkgname,version,pkguname,fmt,*args)
      estr = 'DEBUG   :'+fmt(host,pkgname,version,pkguname,fmt,*args)
      if Def::CAPKG_LOGLV >= CAPKG_LOG_DEBUG
        printf('%s',estr)
      end
      # @@LOG.printf('%s',estr)
      return estr
    end
    def self.echo (line)
      printf("%s\n",line)
      log(line+"\n")
    end
    def log(estr)
      if @@LOG != nil
        @@LOG.printf('%s',estr)
      end
    end
    module_function :log
    def fmt(host,pkgname,version,pkguname,fmt,*args)
      sprintf("[%-15s] %-35s " + fmt + "\n",host,'<'+pkgname+':'+Pkg.v2str(version)+':'+pkguname+'>',*args)
    end
    module_function :fmt
  end # module Logger

  module LocalCmd
    def self.run_system(cmd)
      Logger.debug('LOCAL','*',-1,'','Execute command ! %s',cmd)
      if system(cmd) == false
        raise Logger.errmsg('LOCAL','*',-1,'','Execute command error ! %s',cmd)
      end
    end
    # Todo: Should not be fork ...
    def self.rm(dir)
      run_system('rm -rf \'' + dir + '\'')
    end
    def self.mkdir(dir)
      run_system('mkdir -p \'' + dir + '\'')
    end
    def self.mv(src,dst)
      run_system('mv -fT \'' + src + '\' \'' + dst + '\'')
    end
    def self.cp(src,dst)
      run_system('cp -fT \'' + src + '\' \'' + dst + '\'')
    end
    def self.ln(src,dst)
      run_system('ln -sfn \'' + src + '\' \'' + dst + '\'')
    end
    def self.wget(src,dst)
      run_system(sprintf('wget  --retry-connrefused -q -O %s %s',dst,src))
    end
  end # module LocalCmd

  module RepositorySSH
    def upload_command(src,dst,pkgname='*',version=-1,pkguname='')
      dst = @SSH_REPOSITORY_PATH + '/' + dst
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [upload_ssh] upload by ssh. => %s -> %s:%s',src,@SSH_REPOSITORY_HOST,dst)
      $capself.upload_task(@SSH_REPOSITORY_HOST,src,dst)
    end
    def remove_command(dst,pkgname='*',version=-1,pkguname='')
      dst = @SSH_REPOSITORY_PATH + '/' + dst
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [remove_ssh] remove by ssh. => %s',dst)
      $capself.remove_task(@SSH_REPOSITORY_HOST,dst)
    end
  end
  module RepositoryDAV
    def mkdir_dav(dst,pkgname,version,pkguname)
      if dst == '.'
        return
      end
      d = File.dirname(dst)
      mkdir_dav(d,pkgname,version,pkguname)
      dst=@HTTP_REPOSITORY+'/'+dst
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [mkdir_dav] upload by curl. => %s',dst)
      curl_opt = @HTTP_REPOSITORY_CERT ? '--cacert '+@HTTP_REPOSITORY_CERT : ''
      LocalCmd.run_system(sprintf('curl --retry 3 --retry-delay 2 -f -s %s -o /dev/null -XMKCOL --url %s',curl_opt,dst))
    end
    def upload_command(src,dst,pkgname='*',version=-1,pkguname='')
      mkdir_dav(File.dirname(dst),pkgname,version,pkguname)
      dst=@HTTP_REPOSITORY+'/'+dst
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [upload_dav] upload by curl. => %s -> %s',src,dst)
      curl_opt = @HTTP_REPOSITORY_CERT ? '--cacert '+@HTTP_REPOSITORY_CERT : ''
      LocalCmd.run_system(sprintf('curl --retry 3 --retry-delay 2 -f -s %s -o /dev/null -T %s --url %s',curl_opt,src,dst))
    end
    def remove_command(dst,pkgname='*',version=-1,pkguname='')
      dst=@HTTP_REPOSITORY+'/'+dst
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [remove_dav] remove by curl. => %s',dst)
      curl_opt = @HTTP_REPOSITORY_CERT ? '--cacert '+@HTTP_REPOSITORY_CERT : ''
      LocalCmd.run_system(sprintf('curl --retry 3 --retry-delay 2 -f -s %s -o /dev/null -XDELETE --url %s',curl_opt,dst))
    end
  end

  module RepositoryFetchSSH
    def fetch_command(src,dst,pkgname='*',version=-1,pkguname='')
      src=@SSH_REPOSITORY_PATH+'/'+src
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [fetch_ssh] fetchiby ssh. => %s:%s',@SSH_REPOSITORY_HOST,src)
      $capself.download_task(@SSH_REPOSITORY_HOST,src,dst)
    end
  end
  module RepositoryFetchWGET
    def fetch_command(src,dst,pkgname='*',version=-1,pkguname='')
      src=@HTTP_REPOSITORY+'/'+src
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [fetch_wget] fetch by wget. => %s',src)
      LocalCmd.wget(src,dst)
    end
  end
  module RepositoryFetchCURL
    def fetch_command(src,dst,pkgname='*',version=-1,pkguname='')
      src=@HTTP_REPOSITORY+'/'+src
      Logger.notice('LOCAL',pkgname,version,pkguname,' - [fetch_curl] fetch by curl. => %s',src)
      curl_opt = @HTTP_REPOSITORY_CERT ? '--cacert '+@HTTP_REPOSITORY_CERT : ''
      LocalCmd.run_system(sprintf('curl --retry 3 --retry-delay 2 -f -s %s -o %s --url %s',curl_opt,dst,src))
    end
  end

  class RepositoryAccess
    def initialize(fetch_method,
                   repository_method,
                   http_repository,
                   http_repository_cert,
                   ssh_repository_host,
                   ssh_repository_path)
      @FETCH_METHOD=fetch_method
      @REPOSITORY_METHOD=repository_method
      @HTTP_REPOSITORY = http_repository
      @HTTP_REPOSITORY_CERT = http_repository_cert
      @SSH_REPOSITORY_HOST = ssh_repository_host
      @SSH_REPOSITORY_PATH = ssh_repository_path
      if @FETCH_METHOD == 'ssh'
        self.extend RepositoryFetchSSH
      elsif @FETCH_METHOD == 'http'
        self.extend RepositoryFetchCURL
      elsif @FETCH_METHOD == 'wget'
        self.extend RepositoryFetchWGET
      end
      if @REPOSITORY_METHOD == 'ssh'
        self.extend RepositorySSH
      elsif @REPOSITORY_METHOD == 'http'
        self.extend RepositoryDAV
      end
    end
    def fetch(src,dst,nocache,pkgname='*',version=-1,pkguname='')
      begin
        if File.exist?(dst) and ! $g_nocache and ! nocache
          Logger.notice('LOCAL',pkgname,version,pkguname,' - [fetch_require_local] already fetched. (skip)')
          return
        end
        fetch_command(src,dst,pkgname,version,pkguname)
      rescue => ex
        Logger.errmsg('LOCAL',pkgname,version,pkguname," @ [fetch_command] failure \n    caused by => %s",ex.to_s)
        Capistrano::Logger.plast()
        raise ex
      end
    end
  end # RepositoryAccess

  module Repository
    PKG_ACCESS = RepositoryAccess.new(Def::FETCH_METHOD,
                                      Def::REPOSITORY_METHOD,
                                      Def::HTTP_REPOSITORY,
                                      Def::HTTP_REPOSITORY_CERT,
                                      Def::SSH_REPOSITORY_HOST,
                                      Def::SSH_REPOSITORY_PATH)
    MD5_ACCESS = RepositoryAccess.new(Def::MD5_FETCH_METHOD,
                                      Def::MD5_REPOSITORY_METHOD,
                                      Def::MD5_HTTP_REPOSITORY,
                                      Def::MD5_HTTP_REPOSITORY_CERT,
                                      Def::MD5_SSH_REPOSITORY_HOST,
                                      Def::MD5_SSH_REPOSITORY_PATH)

    def self.fetch_alltxt()
      LocalCmd.run_system("echo '#' > " + Capkg::Def::ALLTXT)
      PKG_ACCESS.fetch(Capkg::Def::FN_ALLTXT,Capkg::Def::ALLTXT,true)
    end

    def self.fetch_md5_local(pkgname,version,pkguname)
      LocalCmd.mkdir(Def::LOCAL_PKG + '/' + pkgname)
      src=Env.p_md5(pkgname,version,pkguname)
      dst=Env.p_local_md5(pkgname,version,pkguname)
      MD5_ACCESS.fetch(src,dst,false,pkgname,version,pkguname)
      return dst
    end

    def md5_check(pkgname,version,pkguname)
      if Def::MD5_CHECK == 'yes'
        md5=fetch_md5_local(pkgname,version,pkguname)
        LocalCmd.run_system(sprintf('cd %s && md5sum -c %s > /dev/null',Def::LOCAL_PKG + '/' + pkgname,md5))
      end
    end
    module_function :md5_check

    def self.fetch_require_local(pkgname,version,pkguname)
      LocalCmd.mkdir(Def::LOCAL_PKG + '/' + pkgname)
      src=Env.p_require(pkgname,version,pkguname)
      dst=Env.p_local_require(pkgname,version,pkguname)
      PKG_ACCESS.fetch(src,dst,false,pkgname,version,pkguname)
      return Require.get(pkgname,version,pkguname)
    end

    def self.fetch_pkg_local(pkgname,version,pkguname)
      LocalCmd.mkdir(Def::LOCAL_PKG + '/' + pkgname)
      src=Env.p_capkg(pkgname,version,pkguname)
      dst=Env.p_local_pkg(pkgname,version,pkguname)
      PKG_ACCESS.fetch(src,dst,false,pkgname,version,pkguname)
      fetch_require_local(pkgname,version,pkguname)
      md5_check(pkgname,version,pkguname)
      return dst
    end

    def self.upload_alltxt()
      PKG_ACCESS.upload_command(Def::ALLTXT,Def::FN_ALLTXT)
    end

    def self.upload_pkg(pkgname,version,pkguname)
      # pkg
      tmp_pkg = Def::LOCAL_TMP + '/' + Env.fn_capkg(pkgname,version,pkguname)
      rep_pkg = Env.p_capkg(pkgname,version,pkguname)
      PKG_ACCESS.upload_command(tmp_pkg,rep_pkg,pkgname,version,pkguname)
      # require
      tmp_req = Def::LOCAL_TMP + '/' + Env.fn_require(pkgname,version,pkguname)
      rep_req = Env.p_require(pkgname,version,pkguname)
      LocalCmd.run_system(sprintf('tar xz -O -f %s %s > %s',tmp_pkg,Def::FN_REQUERE,tmp_req))
      PKG_ACCESS.upload_command(tmp_req,rep_req,pkgname,version,pkguname)
      # md5
      tmp_md5 = Def::LOCAL_TMP + '/' + Env.fn_md5(pkgname,version,pkguname)
      rep_md5 = Env.p_md5(pkgname,version,pkguname)
      LocalCmd.run_system(sprintf('cd %s && ' + 
                                  'md5sum -b %s > %s',
                                  Def::LOCAL_TMP,
                                  Env.fn_capkg(pkgname,version,pkguname),                                  
                                  tmp_md5))
      MD5_ACCESS.upload_command(tmp_md5,rep_md5,pkgname,version,pkguname)
    end

    def self.remove_pkg(pkgname,version,pkguname)
      rep_pkg = Env.p_capkg(pkgname,version,pkguname)
      PKG_ACCESS.remove_command(rep_pkg,pkgname,version,pkguname)
      rep_req = Env.p_require(pkgname,version,pkguname)
      PKG_ACCESS.remove_command(rep_req,pkgname,version,pkguname)
      rep_md5 = Env.p_md5(pkgname,version,pkguname)
      PKG_ACCESS.remove_command(rep_md5,pkgname,version,pkguname)
    end

  end # Repository

  #######################################
  # Path definition
  #######################################
  class Env 
    def self.fn_capkg(pkgname,version,uname)
      if uname == Def::NOARCH
        return sprintf('%s-%s.capkg',pkgname,Pkg.v2str(version))
      else
        return sprintf('%s-%s-%s.capkg',pkgname,Pkg.v2str(version),uname)
      end
    end
    def self.fn_require(pkgname,version,uname)
      if uname == Def::NOARCH
        return sprintf('%s-%s.require',pkgname,Pkg.v2str(version))
      else
        return sprintf('%s-%s-%s.require',pkgname,Pkg.v2str(version),uname)
      end
    end
    def self.fn_md5(pkgname,version,uname)
      if uname == Def::NOARCH
        return sprintf('%s-%s.md5',pkgname,Pkg.v2str(version))
      else
        return sprintf('%s-%s-%s.md5',pkgname,Pkg.v2str(version),uname)
      end
    end
    def self.p_capkg(pkgname,version,uname)
      return pkgname+'/'+fn_capkg(pkgname,version,uname)
    end
    def self.p_require(pkgname,version,uname)
      return pkgname+'/'+fn_require(pkgname,version,uname)
    end
    def self.p_md5(pkgname,version,uname)
      return pkgname+'/'+fn_md5(pkgname,version,uname)
    end
    def self.p_pkgdir(pkgname)
      # return Def::BASE_INST+'/'+pkgname
      return '${CAPKG_BASE}/'+Def::DIR_INST+'/'+pkgname
    end
    def self.p_pkgdirbk(pkgname)
      return p_pkgdir(pkgname)+'/'+Def::DIR_BK
    end
    def self.p_local_pkg(pkgname,version,uname)
      return Def::LOCAL_PKG+'/'+p_capkg(pkgname,version,uname)
    end
    def self.p_local_require(pkgname,version,uname)
      return Def::LOCAL_PKG+'/'+p_require(pkgname,version,uname)
    end
    def self.p_local_md5(pkgname,version,uname)
      return Def::LOCAL_PKG+'/'+p_md5(pkgname,version,uname)
    end
    def self.p_base_pkg(pkgname,version,uname)
      return Def::BASE_PKG+'/'+p_capkg(pkgname,version,uname)
    end
  end

  #######################################
  # Pkg info
  #######################################
  class Pkg
    VMAX = 999999999
    VMIN = 000000000
    def self.v2str(v)
      if v == -1
        return '*'
      end
      return (v/1000000).to_s() + '.' + ((v/1000)%1000).to_s() + '.' + (v%1000).to_s()
    end
    def self.str2v(str)
      if /^\s*([\d]{1,3})\.([\d]{1,3})\.([\d]{1,3})\s*?/ =~ str
        return ($1.to_i()*1000000 + $2.to_i()*1000 + $3.to_i())
      end
      return -1
    end
  end

  def self.uname_rule(pkguname,hostuname)
    if Def::UNAME_RULE[hostuname] == nil
      Logger.errmsg('LOCAL','*',-1,'','Unknow UNAME : %s',hostuname)
      return false
    end
    if pkguname == hostuname or Def::UNAME_RULE[hostuname].include?(pkguname)
      return true
    else
      Def::UNAME_RULE[hostuname].each{
        |uname|
        if uname_rule(pkguname,uname) 
          return true
        end        
      }
    end
    return false
  end

  #######################################
  # Package list control
  #######################################
  class PkgList
    def self.init()
      @@instances = {}
    end
    def self.remote_all_txt()
      if @@instances[Def::ALLTXT] == nil
        @@instances[Def::ALLTXT] = PkgList.new(Def::ALLTXT)
      end
      return @@instances[Def::ALLTXT]
    end
    def self.parse(f)
      if @@instances[f] == nil
        @@instances[f] = PkgList.new(f)
      end
      return @@instances[f]
    end
    def initialize(f)
      @fname = f
      re = /^\s*(\S+)\s+([\.\d]+)(?:\s+(\S+)\s*)?$/
      @data = {}
      File.open(@fname,'r') {
        |fp|
        fp.each { 
          |line|
          if re =~ line
            if @data[$1] == nil
              @data[$1] = []
            end
            v = Pkg.str2v($2)
            if defined? $3
              uname = $3
            else
              uname = Def::NOARCH
            end
            @data[$1] << [v,uname]
          end
        }
      }
      @data.each {
        |k,v|
        @data[k] = @data[k].sort{
          |(av,auname),(bv,buname)|
          av != bv ? av - bv : (Capkg.uname_rule(auname,buname) ? -1 : (auname<=>buname) )
        }.reverse
      }
    end
    attr_accessor :data

    def delete(pkgname,version=nil,pkguname=nil)
      if version==nil
        @data.delete(pkgname)
      else
        if @data[pkgname] != nil
          @data[pkgname].each {
            |v,uname|
            if v == version
              if pkguname == nil or pkguname==uname
                @data[pkgname].delete([v,uname])
              end
            end
          }
          if @data[pkgname].length == 0
            @data.delete(pkgname)
          end
        end
      end
      File.open(@fname,'w') {
        |fp|
        @data.each{
          |pn,vs|
          vs.each{
            |pv,uname|
            fp.print "\n" + pn + ' ' + Pkg.v2str(pv)  + ' ' + uname 
          }
        }
      }
    end
    def add(pkgname,version,uname)
      if @data[pkgname] == nil 
        @data[pkgname] = []
      end
      @data[pkgname] << [version,uname]
      File.open(@fname,'a+') {
        |fp|
        fp.print "\n" + pkgname + ' ' + Pkg.v2str(version) + ' ' + uname
      }
    end
    def capkg()
      if @data[Capkg::SELF_NAME] != nil
        return @data[Capkg::SELF_NAME].first.first
      end
      return nil
    end
    def search(cond,pkguname)
      if cond == '*'
        cre = /.*/
      else
        cre = Regexp.compile(cond)
      end
      ret = {}
      @data.each {
        |k,vss|
        if k == Capkg::SELF_NAME
          next
        end
        if cre =~ k
          vss.each {
            |v,uname|
            if pkguname == '' or Capkg.uname_rule(uname,pkguname)
              if not ret.member?(k)
                ret[k] = []
              end
              ret[k] << [v,uname]
              break
            end
          }
        end
      }
      return ret.sort
    end
    def searchall(cond,pkguname)
      if cond == '*'
        cre = /.*/
      else
        cre = Regexp.compile(cond)
      end
      ret = {}
      @data.each {
        |k,vss|
        if k == Capkg::SELF_NAME
          next
        end
        if cre =~ k  
          vss.each {
            |v,uname|
            if pkguname == '' or Capkg.uname_rule(uname,pkguname)
              if not ret.member?(k)
                ret[k] = []
              end
              ret[k] << [v,uname]
            end
          }
        end
      }
      return ret.sort
    end

    def find_by_name(pname)
      if @data[pname] != nil
        return @data[pname]
      end
      return false
    end

    def find_by_just(pname,pkguname,version)
      if @data[pname] != nil
        @data[pname].each {
          |v,uname|
          if version == v and pkguname == uname
            return true
          end
        }
      end
      return false
    end

    # def find_by_uname_rule(pname,pkguname,version)
    #   if @data[pname] != nil
    #     @data[pname].each {
    #       |v,uname|
    #       if version == v and Capkg.uname_rule(uname,pkguname)
    #         return uname
    #       end
    #     }
    #   end
    #   return nil
    # end

    def find_by_range(pname,vfrom,vto)
      ret = []
      if @data[pname] != nil
        @data[pname].each {
          |v,uname|
          if v >= vfrom and v<= vto
            ret << [v,uname]
          end
        }
      end
      return ret
    end

    def find_by_range_uname_rule(pname,pkguname,vfrom,vto)
      ret = []
      if @data[pname] != nil
        @data[pname].each {
          |v,uname|
          if v >= vfrom and v<= vto and Capkg.uname_rule(uname,pkguname)
            ret << [v,uname]
          end
        }
      end
      return ret
    end
  end
  PkgList.init()

  #######################################
  # Package config parser
  #######################################
  class Capkcf 
    FLG_PRE_ACT   = 1
    FLG_POST_ACT  = 2
    FLG_PRE_DEACT = 3
    FLG_POST_DEACT= 4
    RE_COMMENT    = /^\s*\#/
    RE_EMPTY      = /^\s*$/
    RE_PRE_ACT    = /^\s*=PRE_ACTIVATE=\s*$/
    RE_POST_ACT   = /^\s*=POST_ACTIVATE=\s*$/
    RE_PRE_DEACT  = /^\s*=PRE_DEACTIVATE=\s*$/
    RE_POST_DEACT = /^\s*=POST_DEACTIVATE=\s*$/
    RE_REQUIRE    = /^\s*require\s+(\S+)\s+([\.\d]+)(?:\s+([\.\d]+))?\s*$/
    RE_DIR        = /^\s*dir\s+(-|\d+)\s+(-|(?:\S+:\S+))\s+(-)\s+(\S+)\s*$/
    RE_FILE       = /^\s*file\s+(-|\d+)\s+(-|(?:\S+:\S+))\s+(\S+)\s+(\S+)\s*$/
    RE_LINK       = /^\s*link\s+(-|\d+)\s+(-|(?:\S+:\S+))\s+(\S+)\s+(\S+)\s*$/
    RE_KV         = /^\s*(\S+)\s*=\s*(.+)\s*$/
    RE_PKGNAME    = /^\S+$/
    RE_VERSION    = /^\d{1,3}\.\d{1,3}\.\d{1,3}$/
    RE_DESCRIPTION= /^.+$/
    RE_UNAME      = /^.+$/
    RE_DEFOWN     = /^(\S+:\S+)$/
    # RE_OWN        = /^(\S+):(\S+)$/
    # def self.str2own (str) 
    #   if str == '-'
    #     return '-','-'
    #   elsif RE_OWN =~ str
    #     return $1,$2
    #   end
    #   raise 'Cannot parse as owner ! : ' + str
    # end
    def initialize(f)
      @pre_act = ''
      @post_act = ''
      @pre_deact = ''
      @post_deact = ''
      @version
      @pkgname
      @uname
      @requires  = []
      @defown
      @dirs  = []
      @files = []
      @links = []
      parse(f)
    end
    attr_accessor :pre_act,:post_act,:pre_deact,:post_deact,:version,:pkgname,:uname,:requires,:defown,:dirs,:files,:links

    def getenv(line)
      if RE_KV =~ line
        k = $1
        v = nil
        Open3.popen3(sprintf("%s=%s;echo $%s",$1,$2,$1)){
          |stdin,stdout,stderr|
          v = stdout.read.chomp
        }
        if v != nil
          return k,v
        end
      end
      return nil
    end

    def parse(f)
      File.open(f,'r') {
        |fp|
        flg = 0
        fp.each { 
          |line|
          line = line.chomp
          if    RE_PRE_ACT     =~ line
            flg = FLG_PRE_ACT
            next
          elsif RE_POST_ACT    =~ line
            flg = FLG_POST_ACT
            next
          elsif RE_PRE_DEACT   =~ line
            flg = FLG_PRE_DEACT
            next
          elsif RE_POST_DEACT  =~ line
            flg = FLG_POST_DEACT
            next
          elsif flg == FLG_PRE_ACT
            @pre_act.concat(line+"\n")
            next
          elsif flg == FLG_POST_ACT
            @post_act.concat(line+"\n")
            next
          elsif flg == FLG_PRE_DEACT
            @pre_deact.concat(line+"\n")
            next
          elsif flg == FLG_POST_DEACT
            @post_deact.concat(line+"\n")
            next
          elsif RE_COMMENT     =~ line
            next  
          elsif RE_EMPTY     =~ line
            next  
          elsif RE_REQUIRE     =~ line
            vmax = $3
            if vmax == nil
              vmax = Pkg.v2str(Pkg::VMAX)
            end
            @requires << [$1,$2,vmax]
            next
          elsif RE_DIR         =~ line
            dir = [$4,$3,$1,$2]
            @dirs << dir
            next
          elsif RE_FILE        =~ line
            file = [$4,$3,$1,$2]
            @files << file
            next
          elsif RE_LINK        =~ line
            link = [$4,$3,$1,$2]
            @links << link
            next
          else
            k,v = getenv(line)
            if k == nil
            elsif k == 'PACKAGE_NAME'
              @pkgname = v
              next
            elsif k == 'VERSION'
              if RE_VERSION =~ v
                @version = Pkg.str2v(v)
                next
              end
            elsif k == 'DESCRIPTION'
              @description = v
              next
            elsif k == 'UNAME'
              @uname = v
              next
            elsif k == 'DEFAULT_OWNER'
              if RE_DEFOWN =~ v
                @defown = [$1,$2]
                next
              end
            end
          end
          raise Logger.errmsg('LOCAL','*',-1,'','Cannot parse ! line : %s',line)
        }
      }
    end
  end

  #######################################
  # Require tree leaf
  #######################################
  class Require
    RE_REQV = /^\s*(\S+)\s+([\.\d]+)\s+([\.\d]+)\s*$/
    def self.init()
      @@instances = {}
    end
    def self.get(pkgname,version,uname)
      @name = Env.fn_capkg(pkgname,version,uname)
      if @@instances[@name] == nil
        begin
          @@instances[@name] = Require.new(pkgname,version,uname)
        rescue
          @@instances[@name] = 0
          return nil
        end
      end
      if @@instances[@name] == 0
        return nil
      end
      return @@instances[@name]
    end
    def initialize(pn,pv,uname)
      @pkgname = pn
      @version = pv
      @requires = {}
      local_require_file=Env.p_local_require(pn,pv,uname)
      File.open(local_require_file,'r'){
        |fp|
        fp.each{
          |line|
          if RE_REQV =~ line 
            vfrom = Pkg.str2v($2)!=-1 ? Pkg.str2v($2) : Pkg::VMIN
            vto = Pkg.str2v($3)!=-1 ? Pkg.str2v($3) : Pkg::VMAX
            vs = PkgList.remote_all_txt().find_by_range($1,vfrom,vto)
            if vs.length == 0
              raise Logger.errmsg('LOCAL',pn,pv,uname,' @   fail to find the required package. <%s:%s-%s>',$1,$2,$3)
            end
            @requires[$1] = vs
          end
        }
      }
    end
    attr_accessor :requires
  end
  Require.init()

  #######################################
  # Task top
  #######################################
  def self.lock_host(host)
    # @@@
    # locker =$capself.run_task(host,sprintf('lockfile -l900 -5 -r6 %s && echo $SUDO_USER > %s || cat %s',Def::LOCKFILE,Def::LOCKFILE,Def::LOCKFILE))
    #if locker != ''
    #  raise Logger.errmsg(host,'*',-1,'',' @   Fail to get a lock, The host is already locked by "%s"',locker.chomp)
    #end
  end
  def self.unlock_host(host)
    # @@@
    # $capself.run_task(host,sprintf('rm -f %s',Def::LOCKFILE))
  end
  def self.install_capkg(version)
    $g_nocache = true
    Repository.fetch_pkg_local(Capkg::SELF_NAME,version,Def::NOARCH)
    local_pkg=Env.p_local_pkg(Capkg::SELF_NAME,version,Def::NOARCH)
    dir = Def::LOCAL_ROOT+'/config/'
    fname = 'default.rb'
    LocalCmd.run_system(sprintf('tar xz -O -f %s %s > %s%s',local_pkg,fname,dir,fname))
    fname = 'capkg.rb'
    LocalCmd.run_system(sprintf('tar xz -O -f %s %s > %s%s',local_pkg,fname,dir,fname))
    fname = 'capkg.sh'
    LocalCmd.run_system(sprintf('tar xz -O -f %s %s > %s%s',local_pkg,fname,dir,fname))
    fname = 'deploy.rb'
    LocalCmd.run_system(sprintf('tar xz -O -f %s %s > %s%s',local_pkg,fname,dir,fname))
  end
  def self.setup_hosts(hosts,clean_flg)
    hosts.each {
      |host|
      Logger.info(host,'*',-1,'',' - [setup_host] start')
      begin
        if clean_flg
          $capself.run_task(host,sprintf('rm -rf %s %s',
                                         Def::BASE_PKG, 
                                         Def::BASE_TMP),false)
        end
        $capself.run_task(host,sprintf('mkdir -p %s %s %s && ' + 
                                       'chown %s:%s %s %s %s',
                                       Def::CAPKG_BASE,
                                       Def::BASE_PKG, 
                                       Def::BASE_INST,
                                       Def::RUNNER,Def::GROUP,
                                       Def::CAPKG_BASE,Def::BASE_PKG, Def::BASE_INST ),false)
        # $capself.run_task(host,'mkdir -p ' + Def::BASE + ' ' + Def::BASE_PKG + ' ' + Def::BASE_INST )
        # $capself.run_task(host,'chown ' + Def::RUNNER + ':' + Def::GROUP + ' ' + Def::BASE + ' ' + Def::BASE_PKG + ' ' + Def::BASE_INST )
        # @@@ not secure ( how to use temporary-space with secure )
        $capself.run_task(host,sprintf('mkdir -p %s && ' + 
                                       'chmod 777 %s && ' + 
                                       'chown %s:%s %s',
                                       Def::BASE_TMP,
                                       Def::BASE_TMP,
                                       Def::RUNNER,Def::GROUP,
                                       Def::BASE_TMP ),false)
        # $capself.run_task(host,'mkdir -p -m 777 ' Def::BASE_TMP)
        $capself.run_task(host,sprintf('touch %s %s && ' + 
                                       'chown %s:%s %s %s',
                                       Def::FETCHTXT,Def::INSTTXT,
                                       Def::RUNNER,Def::GROUP,
                                       Def::FETCHTXT,Def::INSTTXT))
        # $capself.run_task(host,'touch ' + Def::FETCHTXT + ' ' + Def::INSTTXT)
        # $capself.run_task(host,'chown ' + Def::RUNNER + ':' + Def::GROUP + ' ' + Def::CAPKG_BASE + ' ' + Def::BASE_TMP + ' ' + Def::BASE_PKG + ' ' + Def::BASE_INST + ' '  + Def::FETCHTXT + ' ' + Def::INSTTXT)
        # $capself.run_task(host,'chmod 644 ' + Def::FETCHTXT + ' ' + Def::INSTTXT)
        get_uname(host)
      rescue => ex
        Logger.errmsg(host,'*',-1,''," @ [setup_host] failure \n    caused by => %s",ex.to_s)
        Capistrano::Logger.plast()
        raise ex
      end
      Logger.info(host,'*',-1,'',' - [setup_host] end')
    }
  end

  def self.search_pkg(pkgname,pkguname,searchall=false)
    Logger.echo(sprintf(" Searching package... (%s:%s)",pkgname,pkguname))
    Logger.echo(sprintf(" %-25s%-13s%s",'PACKAGE NAME' ,'VERSION','UNAME'))
    Logger.echo(sprintf(" %-25s%-13s%s",'------------------------' ,'------------' , '----------'))
    begin
      if searchall
        PkgList.remote_all_txt().searchall(pkgname,pkguname).each{
          |k,vss|
          vss.each {
            |v,uname|
            Logger.echo(sprintf(" %-25s%-13s%s",k ,Pkg.v2str(v),uname))
          }
        }
      else
        PkgList.remote_all_txt().search(pkgname,pkguname).each{
          |k,vss|
          vss.each {
            |v,uname|
            Logger.echo(sprintf(" %-25s%-13s%s",k ,Pkg.v2str(v),uname))
          }
        }
      end
    rescue => ex
      Logger.errmsg('LOCAL',pkgname,-1,''," @ [search_pkg] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
  end

  def self.list_pkg(hosts,pkgname)
    hosts.each {
      |host|
      list_pkg_host(host,pkgname)
    }
  end

  def self.fetch_pkg(hosts,pkgname,version,pkguname)
    # hosts.each {
    #   |host|
    #   fetch_pkg_host(host,pkgname,version,pkguname)
    # }
  end

  def self.activate_pkg(hosts,pkgname,version,pkguname)
    # hosts.each {
    #   |host|
    #   hostuname = get_uname(host)
    #   activate_pkg_host(host,pkgname,version,pkguname,hostuname)
    # }
  end

  def self.deactivate_pkg(hosts,pkgname)
    # hosts.each {
    #   |host|
    #   deactivate_pkg_host(host,pkgname,true)
    # }
  end

  def self.install_pkg(hosts,pkgname,version,libs,yes,downgrade,ignreq)
    hosts.each {
      |host|
      lock_host(host)
      begin
        hostuname = get_uname(host)
        install_pkg_host(host,pkgname,version,hostuname,libs,yes,downgrade,ignreq)
      ensure
        unlock_host(host)
      end
    }
  end

  def self.uninstall_pkg(hosts,pkgname,yes,force,ignreq)
    hosts.each {
      |host|
      uninstall_pkg_host(host,pkgname,yes,force,ignreq)
    }
  end

  def self.generate_pkg (pkgname,root,targets,version,pkguname,requires,preactivate,predeactivate,postactivate,postdeactivate)
    Logger.info('LOCAL',pkgname,version,pkguname,' - [generate_pkg] start')
    begin
      targets.delete('')
      requires.delete('')
      if version < 0
        version=1
      end
      if pkguname == ''
        # pkguname = Def::NOARCH
        pkguname = get_uname('localhost')
      end
      if root =~ /[^\/]$/
        root += '/'
      end
      def self.scandir(fp,r,t,d='')
        fp.printf("dir  %-5s %-15s %-50s %-50s\n",'-','-','-',r+d)
        Dir.open(t+'/'+d){
          |dp|
          dp.each{
            |f|
            if f == '.' || f == '..' || f == '.svn' || f == 'CVS' || f == 'CVSROOT' || f == '.git' || f == '.gitignore'
              next
            end
            path = d+'/'+f
            if t == '.'
              full = path
            else
              full = t+'/'+ path
            end
            st = File.lstat(full)
            if st.directory?()
              # fp.printf("dir  %-5s %-15s %-50s %-50s\n",'-','-','-',r+path)
              scandir(fp,r,t,path)
            elsif st.file?()
              fp.printf("file %-5s %-15s %-50s %-50s\n",'-','-',full,r+path)
            elsif st.symlink?()
              lpath = File.readlink(full) 
              if /^\// =~ lpath
                #
              else
                #lpath = File.dirname(path) + '/' + lpath
                lpath = r+d+'/'+lpath
              end
              fp.printf("link %-5s %-15s %-50s %-50s\n",'-','-',lpath,r+path)
            end
          }
        }
      end
      fp = File.open(pkgname + '.capkcf','w')
      fp.printf("PACKAGE_NAME=%s\n",pkgname)
      fp.printf("VERSION=%s\n",Pkg.v2str(version))
      fp.printf("DESCRIPTION=Generated by Capkg\n")
      fp.printf("UNAME=%s\n",pkguname)
      fp.printf("# require RequirePackage 0.0.0 999.999.999\n")
      requires.each{
        |require|
        fp.printf("require %s\n",require)
      }
      fp.printf("DEFAULT_OWNER=%s:%s\n",Def::RUNNER,Def::GROUP)
      fp.printf("#<type> <permition> <owner> <src> <dst>\n")
      # Dirs/Files/Links
      targets.each{
        |dname|
        scandir(fp,root,File.dirname(dname),File.basename(dname))
      }
      fp.printf("=PRE_ACTIVATE=\n")
      fp.printf("#!/usr/bin/env sh\n")
      fp.printf(preactivate)
      fp.printf("\n# Add shell commands... \n\n")
      fp.printf("=POST_ACTIVATE=\n")
      fp.printf("#!/usr/bin/env sh\n")
      fp.printf(postactivate)
      fp.printf("\n# Add shell commands... \n\n")
      fp.printf("=PRE_DEACTIVATE=\n")
      fp.printf("#!/usr/bin/env sh\n")
      fp.printf(predeactivate)
      fp.printf("\n# Add shell commands... \n\n")
      fp.printf("=POST_DEACTIVATE=\n")
      fp.printf("#!/usr/bin/env sh\n")
      fp.printf(postdeactivate)
      fp.printf("\n# Add shell commands... \n\n")
    rescue => ex
      Logger.errmsg('LOCAL',pkgname,version,pkguname," @ [generate_pkg] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info('LOCAL',pkgname,version,pkguname,' - [generate_pkg] success')
  end

  def self.create_pkg (capkcf)
    Logger.info('LOCAL',capkcf,-1,'',' - [create_pkg] start')
    version = -1
    pkgname = ''
    pkguname = ''
    begin
      # parse
      cf = Capkcf.new(capkcf)
      version = cf.version
      pkgname = cf.pkgname
      pkguname = cf.uname
      # capkg-filepath
      capkg = Def::LOCAL_TMP+'/'+Env.fn_capkg(cf.pkgname,cf.version,cf.uname)
      LocalCmd.rm(capkg)
      # working directory
      tmp_base = Def::LOCAL_TMP+'/'+cf.pkgname+'_'+Pkg.v2str(cf.version)
      LocalCmd.rm(tmp_base)
      LocalCmd.mkdir(tmp_base)
      # install & backup
      p_base_inst_pkg = Env.p_pkgdir(cf.pkgname)
      p_base_inst_bk = Env.p_pkgdirbk(cf.pkgname)
      # require
      File.open(tmp_base + '/' + Def::FN_REQUERE,'w'){
        |fp|
        fp.print "#"
        cf.requires.each {
          |pn,pvmin,pvmax|
          fp.print "\n" + pn + ' ' + pvmin + ' ' + pvmax
        }
      }
      # hooks
      File.open(tmp_base + '/' + Def::FN_PREACTIVATE,'w'){|fp|fp.print cf.pre_act }
      File.open(tmp_base + '/' + Def::FN_POSTACTIVATE,'w'){|fp|fp.print cf.post_act}
      File.open(tmp_base + '/' + Def::FN_PREDEACTIVATE,'w'){|fp|fp.print cf.pre_deact}
      File.open(tmp_base + '/' + Def::FN_POSTDEACTIVATE,'w'){|fp|fp.print cf.post_deact}
      # activate
      activate = File.open(tmp_base + '/' + Def::FN_ACTIVATE,'w')
      activate.printf("#!/usr/bin/env sh\n")
      activate.printf("if [ \"${CAPKG_BASE}\" == \"\" ]; then export %s='%s' ; fi\n",'CAPKG_BASE',Def::CAPKG_BASE)
      activate.printf("%s/%s || exit 1\n",p_base_inst_pkg,Def::FN_PREACTIVATE)
      # dectivate
      deactivate = File.open(tmp_base + '/' + Def::FN_DEACTIVATE,'w')
      deactivate.printf("#!/usr/bin/env sh\n")
      deactivate.printf("if [ \"${CAPKG_BASE}\" == \"\" ]; then export %s='%s' ; fi\n",'CAPKG_BASE',Def::CAPKG_BASE)
      deactivate.printf("%s/%s\n",p_base_inst_pkg,Def::FN_PREDEACTIVATE)
      # 
      cf.dirs.sort.each {
        |dst,src,perm,own|
        LocalCmd.mkdir(tmp_base+'/'+dst)
        # activate
        activate.printf("if [ -d '%s' ];then mkdir -p %s'/%s';fi\n",dst,p_base_inst_bk,dst)
        activate.printf("mkdir -p '%s' || exit 1\n",dst)
        if perm != '-'
          activate.printf("chmod %s '%s' || exit 1\n",perm,dst)
        end
        if own == '-'
          activate.printf("chown %s '%s' || exit 1\n",cf.defown,dst)
	else
          activate.printf("chown %s '%s' || exit 1\n",own,dst)
        end
      }
      cf.files.each {
        |dst,src,perm,own|
        LocalCmd.cp(src,tmp_base+'/'+dst)
        # activate
        activate.printf("mv -fT '%s' %s'/%s' || true\n",dst,p_base_inst_bk,dst)
        activate.printf("cp -T %s'/%s' '%s' || exit 1\n",p_base_inst_pkg,dst,dst)
        if perm != '-'
          activate.printf("chmod %s '%s' || exit 1\n",perm,dst)
        end
        if own == '-'
          activate.printf("chown %s '%s' || exit 1\n",cf.defown,dst)
	else
          activate.printf("chown %s '%s' || exit 1\n",own,dst)
        end
        # dectivate
        deactivate.printf("rm -f '%s' \n",dst)
        deactivate.printf("mv -fT %s'/%s' '%s' \n",p_base_inst_bk,dst,dst)
      }
      cf.links.each {
        |dst,src,perm,own|
        # LocalCmd.ln(src,tmp_base+'/'+dst)
        # activate
        activate.printf("mv -fT '%s' %s'/%s' || true\n",dst,p_base_inst_bk,dst)
        activate.printf("ln -sfn '%s' '%s' || exit 1\n",src,dst)
        # dectivate
        deactivate.printf("rm -f '%s' \n",dst)
        deactivate.printf("mv -fT %s'/%s' '%s' \n",p_base_inst_bk,dst,dst)
      }
      cf.dirs.sort.reverse.each {
        |dst,src,perm,own|
        # deactivate
        deactivate.printf("rmdir '%s' || true\n",dst)
        deactivate.printf("if [ -d %s'/%s' ];then mkdir -p '%s';fi\n",p_base_inst_bk,dst,dst)
      }
      activate.printf("%s/%s || exit 1\n",p_base_inst_pkg,Def::FN_POSTACTIVATE)
      deactivate.printf("%s/%s\n",p_base_inst_pkg,Def::FN_POSTDEACTIVATE)
      activate.close()
      deactivate.close()
      LocalCmd.run_system(sprintf('cd %s && ' + 
                                  'tar czf %s * %s %s %s %s %s %s %s',
                                  tmp_base,
                                  capkg,Def::FN_REQUERE,
                                  Def::FN_ACTIVATE,
                                  Def::FN_PREACTIVATE,
                                  Def::FN_POSTACTIVATE,
                                  Def::FN_DEACTIVATE,
                                  Def::FN_PREDEACTIVATE,
                                  Def::FN_POSTDEACTIVATE))
    rescue => ex
      Logger.errmsg('LOCAL',capkcf,-1,''," @ [create_pkg] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.msg('LOCAL',pkgname,version,pkguname,'CREATE SUCCESS')
    Logger.info('LOCAL',pkgname,version,pkguname,' - [create_pkg] success')
  end

  def self.upload_pkg(pkgname,version,pkguname)
    if pkguname == '' 
      pkguname = Def::NOARCH
    end
    Logger.info('LOCAL',pkgname,version,pkguname,' - [upload_pkg] start')
    begin
      pkg = PkgList.remote_all_txt()
      if pkg.find_by_just(pkgname,pkguname,version)
        raise 'Already uploaded.'
      end
      Repository.upload_pkg(pkgname,version,pkguname)
      pkg.add(pkgname,version,pkguname)
      Repository.upload_alltxt()
    rescue => ex
      Logger.errmsg('LOCAL',pkgname,version,pkguname," @ [upload_pkg] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info('LOCAL',pkgname,version,pkguname,' - [upload_pkg] success')
  end

  def self.invalidate_pkg(pkgname,version,pkguname)
    if pkguname == '' 
      pkguname = Def::NOARCH
    end
    Logger.info('LOCAL',pkgname,version,pkguname,' - [invalidate_pkg] start')
    begin
      pkg = PkgList.remote_all_txt()
      if ! pkg.find_by_just(pkgname,pkguname,version)
        raise 'Not found.'
      end
      pkg.delete(pkgname,version,pkguname)
      Repository.upload_alltxt()
      Repository.remove_pkg(pkgname,version,pkguname)
    rescue => ex
      Logger.errmsg('LOCAL',pkgname,version,pkguname," @ [invalidate_pkg] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info('LOCAL',pkgname,version,pkguname,' - [invalidate_pkg] success')
  end
  #######################################
  # Task per host
  #######################################
  def self.list_pkg_host(host,pkgname)
    Logger.info(host,pkgname,-1,'',' - [list_pkg_host] start')
    begin
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_inst = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_INSTTXT
      $capself.download_task(host,Def::INSTTXT,local_inst)
      Logger.echo(sprintf(" Installed package (%s) at %s",pkgname,host))
      Logger.echo(sprintf(" %-25s%-13s%s",'PACKAGE NAME' ,'VERSION','UNAME'))
      Logger.echo(sprintf(" %-25s%-13s%s",'------------------------' ,'------------' , '----------'))

      PkgList.parse(local_inst).searchall(pkgname,'').each{
        |k,vss|
        vss.each {
          |v,uname|
          Logger.echo(sprintf(" %-25s%-13s%s",k ,Pkg.v2str(v),uname))
        }
      }
    rescue => ex
      Logger.errmsg(host,pkgname,-1,''," @ [list_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info(host,pkgname,-1,'',' - [list_pkg_host] success')
  end

  def self.get_uname(host='')
    Logger.info(host,'*',-1,'',' - [get_uname] start')
    ret = nil
    begin
      if host == ''
        local_fetch = Def::LOCAL_HOST + '/localhost/' + Def::FN_ISSUE
        LocalCmd.run_system('%s > %s' , Def::GET_UNAME_CMD, local_fetch)
      else
        LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
        remote_fetch = Def::BASE_TMP + '/' + Def::FN_ISSUE
        $capself.run_task(host,'('+Def::GET_UNAME_CMD+') > '+remote_fetch)
        local_fetch = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_ISSUE
        $capself.download_task(host,remote_fetch,local_fetch)
      end
      File.open(local_fetch,'r') {
        |fp|
        fp.each { 
          |line|
          ret= line.chomp
          break
        }
      }
      if ret == nil
        raise 'Unexpect error ! ' + local_fetch
      end
    rescue => ex
      Logger.errmsg(host,'*',-1,''," @ [get_uname] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.msg(host,'*',-1,'',' - [get_uname] %s',ret)
    Logger.info(host,'*',-1,'',' - [get_uname] success')
    return ret
  end

  def self.fetch_pkg_host(host,pkgname,version,pkguname)
    Logger.info(host,pkgname,version,pkguname,' - [fetch_pkg_host] start')
    begin
      # pkguname = PkgList.remote_all_txt().find_by_uname_rule(pkgname,hostuname,version)
      Repository.fetch_pkg_local(pkgname,version,pkguname)
      local_pkg=Env.p_local_pkg(pkgname,version,pkguname)
      base_pkg=Env.p_base_pkg(pkgname,version,pkguname)
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_fetch = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_FETCHTXT
      $capself.download_task(host,Def::FETCHTXT,local_fetch)
      fpkg = PkgList.parse(local_fetch)
      if ! fpkg.find_by_just(pkgname,pkguname,version) 
        Logger.notice(host,pkgname,version,pkguname,' - [fetch_pkg_host] fetching.')
        $capself.upload_task(host,local_pkg,base_pkg)
        fpkg.add(pkgname,version,pkguname)
        $capself.upload_task(host,local_fetch,Def::FETCHTXT)
      elsif $g_nocache
        Logger.notice(host,pkgname,version,pkguname,' - [fetch_pkg_host] re-fetching.')
        $capself.upload_task(host,local_pkg,base_pkg)
        fpkg.add(pkgname,version,pkguname)
        $capself.upload_task(host,local_fetch,Def::FETCHTXT)
      else
        Logger.notice(host,pkgname,version,pkguname,' - [fetch_pkg_host] already fetched.(skip)')
      end
      return true
    rescue => ex
      Logger.errmsg(host,pkgname,version,pkguname," @ [fetch_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info(host,pkgname,version,pkguname,' - [fetch_pkg_host] success')
  end

  def self.activate_pkg_host(host,pkgname,version,pkguname,hostuname)
    Logger.info(host,pkgname,version,pkguname,' - [activate_pkg_host] start')
    begin
      base_pkg=Env.p_base_pkg(pkgname,version,pkguname)
      p_base_inst_pkg = Env.p_pkgdir(pkgname)
      p_base_inst_bk = Env.p_pkgdirbk(pkgname)
      # Check
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_inst = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_INSTTXT
      $capself.download_task(host,Def::INSTTXT,local_inst)
      ipkg = PkgList.parse(local_inst)
      if ! ipkg.find_by_name(pkgname)
        if not activate_check(host,pkgname,version,ipkg,pkguname,hostuname)
          raise 'Fail to activate.'
        end
        fetch_pkg_host(host,pkgname,version,pkguname)
        # $capself.run_task(host,'mkdir -p ' + p_base_inst_pkg + ' ' + p_base_inst_bk+sprintf(';tar xz -C %s -f %s',p_base_inst_pkg,base_pkg)+sprintf(';chmod 744 %s/%s %s/%s %s/%s %s/%s %s/%s %s/%s',p_base_inst_pkg,Def::FN_ACTIVATE,p_base_inst_pkg,Def::FN_PREACTIVATE,p_base_inst_pkg,Def::FN_POSTACTIVATE,p_base_inst_pkg,Def::FN_DEACTIVATE,p_base_inst_pkg,Def::FN_PREDEACTIVATE,p_base_inst_pkg,Def::FN_POSTDEACTIVATE)+';'+p_base_inst_pkg+'/'+Def::FN_ACTIVATE)
        $capself.run_task(host,sprintf('mkdir -p %s %s && ' +
                                       'cd %s && '+
                                       'tar xz -f %s && ' +
                                       'chmod 744 %s/%s %s/%s %s/%s %s/%s %s/%s %s/%s && ' +
                                       '%s/%s',
                                       p_base_inst_pkg,p_base_inst_bk,
                                       p_base_inst_pkg,
                                       base_pkg,
                                       p_base_inst_pkg,Def::FN_ACTIVATE,
                                       p_base_inst_pkg,Def::FN_PREACTIVATE,
                                       p_base_inst_pkg,Def::FN_POSTACTIVATE,
                                       p_base_inst_pkg,Def::FN_DEACTIVATE,
                                       p_base_inst_pkg,Def::FN_PREDEACTIVATE,
                                       p_base_inst_pkg,Def::FN_POSTDEACTIVATE,
                                       p_base_inst_pkg,Def::FN_ACTIVATE))
        ipkg.add(pkgname,version,pkguname)
        $capself.upload_task(host,local_inst,Def::INSTTXT)
      else
        Logger.notice(host,pkgname,version,pkguname,' - [activate_pkg_host] already installed. <%s:%s> (skip)',pkgname,Pkg.v2str(version))
      end
      Logger.info(host,pkgname,version,pkguname,' - [activate_pkg_host] success')
      return true
    rescue => ex
      Logger.errmsg(host,pkgname,version,pkguname," @ [activate_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      deactivate_pkg_host(host,pkgname,true)
      raise ex
    end
  end

  def self.deactivate_pkg_host(host,pkgname,force=false)
    Logger.info(host,pkgname,-1,'',' - [deactivate_pkg_host] start')
    begin
      p_base_inst_pkg = Env.p_pkgdir(pkgname)
      
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_inst = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_INSTTXT
      $capself.download_task(host,Def::INSTTXT,local_inst)

      ipkg = PkgList.parse(local_inst)
      if ipkg.find_by_name(pkgname) or force
        begin
          $capself.run_task(host,p_base_inst_pkg+'/'+Def::FN_DEACTIVATE)
        rescue => ex
          Logger.errmsg(host,pkgname,-1,''," @ [deactivate_pkg_host] deactivate \n    caused by => %s",ex.to_s)
        end
        $capself.run_task(host,'rm -rf '+p_base_inst_pkg)
        ipkg.delete(pkgname)
        $capself.upload_task(host,local_inst,Def::INSTTXT)
      else
        Logger.notice(host,pkgname,-1,'',' - [deactivate_pkg_host] not activated. (skip)')
      end
      Logger.info(host,pkgname,-1,'',' - [deactivate_pkg_host] success')
      return true
    rescue => ex
      Logger.errmsg(host,pkgname,-1,''," @ [deactivate_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
  end

  def self.install_pkg_host(host,pkgname,version,hostuname,libs,yes,downgrade,ignreq)
    Logger.info(host,pkgname,version,'',' - [install_pkg_host] start')
    begin
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_inst = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_INSTTXT
      $capself.download_task(host,Def::INSTTXT,local_inst)
      ipkg = PkgList.parse(local_inst)
      installed = {}
      ipkg.data.each{
        |pn,vs|
        installed[pn] = vs.first
      }

      vfrom = version!=-1 ? version : Pkg::VMIN
      vto = version!=-1 ? version : Pkg::VMAX
      versions = PkgList.remote_all_txt().find_by_range_uname_rule(pkgname,hostuname,vfrom,vto)

      if ignreq
        pv = nil
        pu = nil
        versions.each{
          |v,uname|
          if ! uname_rule(uname,hostuname)
            next
          end
          pv = v
          pu = uname
        }
	#p [pkgname,pv,pu]
	res = { pkgname => { pv => pu } }
	ords = [pkgname]
        inst,unst = downgrade_check(host,ords,installed,res,yes,downgrade)
        ords.each{
          |pn|
          if unst[pn] != nil
            deactivate_pkg_host(host,pn)
          end
        }
        ords.reverse.each{
          |pn|
          if inst[pn] != nil
            pv,puname = inst[pn]
            activate_pkg_host(host,pn,pv,puname,hostuname)
          end
        }
      else
        versions.each{
          |v,uname|
          version = v
          pkguname =  uname
          Logger.notice(host,pkgname,version,pkguname,' - [install_pkg_host] trying')
          iversion,iuname = installed[pkgname]
          if installed.member?(pkgname) and iversion == version
            Logger.notice(host,pkgname,version,pkguname,' - [install_pkg_host] already installed.')
            return true
          else
            prlist={pkgname=>[[version,pkguname]]}
            if libs.member?(pkgname) 
              if libs[pkgname] != prlist[pkgname].first
                next
              end
            end
            libs.each {
              |ln,lvs|
              if pkgname != ln
                prlist[ln]=[lvs]
              end
            }
            f,res = install_require_check(pkgname,version,prlist,ipkg.data,hostuname)
            if f
              ords = sort_packages(res)
              inst,unst = downgrade_check(host,ords,installed,res,yes,downgrade)
              ords.each{
                |pn|
                if unst[pn] != nil
                  deactivate_pkg_host(host,pn)
                end
              }
              ords.reverse.each{
                |pn|
                if inst[pn] != nil
                  pv,puname = inst[pn]
                  activate_pkg_host(host,pn,pv,puname,hostuname)
                end
              }
              Logger.info(host,pkgname,version,'',' - [install_pkg_host] success')
              return true
            else
              res.uniq.each{
                |msg|
                # Logger.errmsg(host,pkgname,version,' @ [install_pkg_host] %s',msg)
              }
            end
            Logger.msg(host,pkgname,version,pkguname,' - [install_pkg_host] go to the next candidate')
          end
        }
        raise 'Not found the appropriate package sets.'
      end
    rescue => ex
      Logger.errmsg(host,pkgname,version,''," @ [install_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
  end

  def self.uninstall_pkg_host(host,pkgname,yes,force,ignreq)
    Logger.info(host,pkgname,-1,'',' - [uninstall_pkg_host] start')
    begin
      LocalCmd.mkdir(Def::LOCAL_HOST + '/' + host)
      local_inst = Def::LOCAL_HOST + '/' + host + '/' + Def::FN_INSTTXT
      $capself.download_task(host,Def::INSTTXT,local_inst)
      ipkg = PkgList.parse(local_inst)
      installed = {}
      ipkg.data.each{
        |pn,vs|
        installed[pn] = vs.first
      }
      if  ignreq and installed.include?(pkgname)
	ords = [pkgname]
	downgrade_check(host,ords,installed,{},yes,false)
        deactivate_pkg_host(host,pkgname)
      else
        ords = uninstall_require_check(host,pkgname,ipkg,force).uniq
        inst,unst = downgrade_check(host,ords,installed,{},yes,false)
        ords.each{
          |pn|
          deactivate_pkg_host(host,pn)
        }
      end
    rescue => ex
      Logger.errmsg(host,pkgname,-1,''," @ [uninstall_pkg_host] failure \n    caused by => %s",ex.to_s)
      Capistrano::Logger.plast()
      raise ex
    end
    Logger.info(host,pkgname,-1,'',' - [uninstall_pkg_host] success')
    return true
  end

  #######################################
  # Calc require tree.
  #######################################
  def self.sort_packages(prlist,ords=nil)
    if ords == nil
      ords = prlist.keys
    end
    ords.each {
      |pn|
      v,uname = prlist[pn].to_a.first
      req = Repository.fetch_require_local(pn,v,uname)
      req.requires.each {
        |rpn,rvss|
        target_pos=ords.index(pn)
        require_pos=ords.index(rpn)
        if require_pos < target_pos
          ords.delete(rpn)
          ords.push(rpn)
          return sort_packages(prlist,ords);
        end
      }
    }
    return ords
  end

  def self.install_require_check(pkgname,version,prlist,installed,hostuname)
    Logger.notice('LOCAL',pkgname,version,'',' - [install_require_check] start')
    def self.narrowing_require_list(requires,prlist)
      rlist = prlist.dup
      requires.each{
        |pn,vs|
        # Version range check
        if rlist.member?(pn)
          effective_vs = vs
          if rlist[pn].is_a?(Array)
            effective_vs = (rlist[pn] & vs)
            if effective_vs.length == 0
              return nil
            end
          else
            v,uname = rlist[pn].to_a.first
            if not vs.include?([v,uname])
              return nil
            end
            effective_vs = rlist[pn]
          end
          rlist[pn] = effective_vs
        else
          rlist[pn] = vs
        end
      }
      return rlist
    end

    prlist.each{
      |pn,vss|
      if vss.is_a?(Array)
        errbuf = []
        vss.each{
          |v,uname|
          if ! uname_rule(uname,hostuname)
            next
          end
          req = Repository.fetch_require_local(pn,v,uname)
          if req == nil
            next
          end
          # Narrowing
          rlist = narrowing_require_list(req.requires,prlist)
          if rlist == nil
            next
          end
          # First condition check
          rlist[pn]={v,uname}
          if not prlist[pkgname].is_a?(Array)
            if rlist[pkgname].is_a?(Array) and not rlist[pkgname].include?(prlist[pkgname])
              # errbuf << r
              next
            end
          end
          # Nested check
          f,r,o = install_require_check(pkgname,version,rlist,installed,hostuname)
          if f
            return f,r,o
          end
          errbuf << r
          errbuf = errbuf.flatten
          errbuf.uniq
        }
        if errbuf.length == 0
          v,o = vss.first
          Logger.warnmsg('LOCAL',pkgname,version,'',' - [install_require_check] Check faild due to : %s:%s' , pn , Pkg.v2str(v))
          return false,[pn + ' ' + Pkg.v2str(v)]
        else
          return false,errbuf
        end
      end
    }
    if installed != nil
      return install_require_check(pkgname,version,installed.merge(prlist),nil,hostuname)
    end
    return true,prlist
  end

  def self.activate_check(host,pkgname,version,pkg,pkguname,hostuname)
    req = Repository.fetch_require_local(pkgname,version,pkguname)
    req.requires.each {
      |pn,pvs|
      pvf,pof = pvs.first
      pvl,pol = pvs.last

      if ! pkg.find_by_name(pn)
        Logger.errmsg(host,pkgname,version,pkguname,' - [activate_check] condition error. expects: <%s:%s-%s> => not found',pn,Pkg.v2str(pvf),Pkg.v2str(pvl))
        return false
      end

      if pkg.find_by_range(pn,pvl,pvf).length == 0
        v,o = pkg.find_by_name(pn).first
        Logger.errmsg(host,pkgname,version,pkguname,' - [activate_check] condition error. expects: <%s:%s-%s> => installed: <%s:%s>',pn,Pkg.v2str(pvf),Pkg.v2str(pvl),pn,Pkg.v2str(v))
        return false
      end
    }
    return true
  end

  def self.uninstall_require_check(host,pkgname,pkg,force)
    ret=[pkgname]
    pkg.data.each{
      |pn,vss|
      pv,pkguname = vss.first
      begin
        req = Repository.fetch_require_local(pn,pv,pkguname)
        if req.requires.member?(pkgname)
          ret=uninstall_require_check(host,pn,pkg,force)+ret
          Logger.notice(host,pkgname,-1,'',' - [uninstall_require_check] required by <%s:%s>',pn,Pkg.v2str(pv))
        end
      rescue => ex
        Logger.errmsg(host,pkgname,pv,pkguname," @ [uninstall_require_check] fail to fetch \n    caused by => %s",ex.to_s)
        if force
          return ret
        end
        while true
          type = Capistrano::CLI.ui.ask("Could not fetch the requirement-information !\n Do you continue with violently ? [yes/no]") { |q| q.default = ''}
          if 'yes' == type
            return ret
          elsif 'no' == type
            break
          end
        end
        raise 'Failure to uninstall : ' + ex.to_s
      end
    }
    return ret
  end

  def self.downgrade_check(host,ords,installed,require,yes,downgrade)
    dflg = false
    inst = {}
    unst = {}
    Logger.echo(sprintf(" %-25s%-26s=> %-26s%-11s",'PACKAGE_NAME','INSTALLED','NEW','TYPE'))
    Logger.echo(sprintf(" %-25s%-26s   %-26s%-11s",'------------------------','-------------------------','-------------------------','----------'))
    ords.each{
      |pn|
      if installed.member?(pn)
        ipv,ipkguname = installed[pn]
        if not require.has_key?(pn)
          Logger.echo(sprintf(" %-25s%-13s%-13s=> %-13s%-13s%-11s",pn ,Pkg.v2str(ipv),ipkguname,'nothing','','(uninstall)'))
          unst[pn] = nil
        else
          req= require[pn].to_a.first
          pv,pkguname = req
          if ipv > pv
            Logger.echo(sprintf(" %-25s%-13s%-13s=> %-13s%-13s%-11s",pn ,Pkg.v2str(ipv),ipkguname,Pkg.v2str(pv),pkguname,'(downgrade)'))
            dflg = true
            inst[pn] = req
            unst[pn] = pv
          elsif ipv < pv
            Logger.echo(sprintf(" %-25s%-13s%-13s=> %-13s%-13s%-11s",pn ,Pkg.v2str(ipv),ipkguname,Pkg.v2str(pv),pkguname,'(update)'))
            inst[pn] = req
            unst[pn] = pv
          end
        end
      else
        req= require[pn].to_a.first
        if req == nil
          raise 'Not installed'
        end
        pv,pkguname = req
        Logger.echo(sprintf(" %-25s%-13s%-13s=> %-13s%-13s%-11s",pn ,'nothing','',Pkg.v2str(pv),pkguname,'(install)'))
        inst[pn] = req
      end
    }
    if dflg and ! downgrade
      raise 'Including downgrade. Please use -d option if you want to continue.'
    end
    if yes
      return inst,unst
    end
    while true
      type = Capistrano::CLI.ui.ask('Continue ? [yes/no]') { |q| q.default = ''}
      if 'yes' == type
        return inst,unst
      elsif 'no' == type
        break
      end
    end
    raise 'Process is interrupted by user.'
  end
end # module Capkg

#######################################
#  Code charms
#######################################
Signal.trap(:INT) do
  abort "\n[cap] Inturrupted..."
end
class HighLine::Question
  def append_default()
    @question << "(default: #{@default.inspect} ): "
  end
end
module Capistrano
  # class Configuration
  #   module Actions
  #     module Invocation
  #       def sudo(*parameters, &block)
  #         options = parameters.last.is_a?(Hash) ? parameters.pop.dup : {}
  #         command = parameters.first
  #         user = options[:as] && "su #{options.delete(:as)}"
  #         #user = options[:as] && "#{options.delete(:as)}"
  #         sudo_prompt_option = "-p '#{sudo_prompt}'" unless sudo_prompt.empty?
  #         sudo_command = [fetch(:sudo, "sudo"), sudo_prompt_option, user].compact.join(" ")
  #         if command
  #           command = sudo_command + " " + command
  #           run(command, options, &block)
  #         else
  #           return sudo_command
  #         end
  #       end
  #     end
  #   end
  # end
  class Logger
    alias_method :org_log, :log
    @@msg = []
    def log(level, message, line_prefix=nil) #:nodoc:
      if level == 0
        @@msg << sprintf('[%s]:%s', line_prefix.to_s,message)
      end
    end
    def self.msg
      return @@msg
    end
    def self.plast(n=4)
      @@msg.last(n).each{
        |l|
        printf("%s\n",l.chomp)
      }
    end
  end
end
