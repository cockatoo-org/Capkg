# -*- coding: utf-8 -*-
# deploy.rb - Capistrano recipe of the Capkg.
# 
#   Author: hiroaki.kubota@rakuten.co.jp
#   Date: 2010/12/28
#   Version: 1.0.0

require File.expand_path(File.dirname(__FILE__))+'/capkg.rb'

$capself = self

#######################################
#  Args
#######################################
# Package name
set :a_pkg do  pkg end
# Package version
set :a_version do version end
# UNAME
set :a_uname do uname end
# CLEAN
set :a_clean do clean end
# Target hosts
set :a_hosts do
  ret=hosts.split(/,/)
  begin
    File.open(hlist,'r'){
      |fp|
      fp.each { 
        |line|
        if /([\S]+)/ =~ line
          ret << $1
        end
      }
    }
  rescue => ex
  end
  ret
end
# Package configuration file ( for capkg:create )
set :a_capkcf do capkcf end
set :a_targets do targets.split(/,/) end
set :a_downgrade  do (downgrade==true) ? true : false end
# @@@ Huuumm...
$g_nocache = instance_eval do (nocache==true) ? true : false end
set :a_yes do (yes==true) ? true : false end
set :a_force do (force==true) ? true : false end
set :a_ignreq do (ignreq==true) ? true : false end
set :a_searchall do (searchall==true) ? true : false end
set :a_libs do
  ret = {}
  ( libs.length==0 ? [] : libs.split(/,/)).each{
    |line|
    if /^([^:]+):([\d\.]+):(\S+)$/ =~ line
      ret[$1]=[Capkg::Pkg.str2v($2),$3]
    end
  }
  ret
end
# Target hosts
set :a_cmd do cmd end
set :a_cmdfile do cmdfile end
# Generate
set :a_root do root end
set :a_requires do (requires.length==0) ? [] : requires.split(/,/) end
set :a_preactivate do eval('"'+preactivate+'"') end
set :a_postactivate do eval('"'+postactivate+'"') end
set :a_predeactivate do eval('"'+predeactivate+'"') end
set :a_postdeactivate do eval('"'+postdeactivate+'"') end

#######################################
#  Capkg owner 
#######################################
set :runner, Capkg::Def::RUNNER
set :group, Capkg::Def::GROUP

#######################################
#  Actions
#######################################

namespace :capkg do
  task :t1 do
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( t1 ) ')
    # Capkg::Repository.fetch_alltxt()
    # Capkg::Repository.upload_alltxt()
    # Capkg::Repository.upload_pkg('base',3,'CentOS')
    begin
      # run_task(Capkg::Def::SSH_REPOSITORY_HOST,'date;ps;echo $CAPKG_BASE')
      # Capkg.lock_host('localhost')
      # Capkg::Repository.fetch_command(Capkg::Def::FN_ALLTXT,Capkg::Def::ALLTXT,true)
      # pkg = PkgList.remote_all_txt()
      # pkg.add('AAAA',1,'Linux')
      # pkg.add('AAAA',2,'Linux')
      # pkg.delete('AAAA',2)
      # pkg.delete('AAAA',1,'Linux')
      # Capkg.unlock_host('localhost')
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( t1 ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( t1 ) ')
  end
  #------------------------------
  #  Create repository
  task :createrep do
    pre_selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( createrep ) ')
    Capkg.setup_hosts([Capkg::Def::SSH_REPOSITORY_HOST],a_clean)
    run_task(Capkg::Def::SSH_REPOSITORY_HOST,sprintf('mkdir -p -m 775 %s && chown %s:%s %s',Capkg::Def::SSH_REPOSITORY_PATH,Capkg::Def::RUNNER,Capkg::Def::GROUP,Capkg::Def::SSH_REPOSITORY_PATH ))
    run_task(Capkg::Def::SSH_REPOSITORY_HOST,sprintf('touch %s/%s && chown %s:%s %s/%s && chmod 664 %s/%s',Capkg::Def::SSH_REPOSITORY_PATH,Capkg::Def::FN_ALLTXT,Capkg::Def::RUNNER,Capkg::Def::GROUP,Capkg::Def::SSH_REPOSITORY_PATH,Capkg::Def::FN_ALLTXT,Capkg::Def::SSH_REPOSITORY_PATH,Capkg::Def::FN_ALLTXT))
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( createrep ) ')
  end
  #------------------------------
  #  Capistrano base host initialize
  task :pre_selfsetup do
    if a_clean
      Capkg::LocalCmd.rm(Capkg::Def::LOCAL_PKG)
      Capkg::LocalCmd.rm(Capkg::Def::LOCAL_HOST)
      Capkg::LocalCmd.rm(Capkg::Def::LOCAL_TMP)
    end
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_ROOT)
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_REP)
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_TMP)
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_HOST)
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_PKG)
    Capkg::LocalCmd.mkdir(Capkg::Def::LOCAL_LOG)
    dir = File.expand_path(File.dirname(__FILE__))
    if File.ftype(dir) == 'link'
      dir=File.expand_path(File.readlink(dir))
    end
    Capkg::LocalCmd.ln(dir,Capkg::Def::LOCAL_ROOT+'/config')
  end
  task :selfsetup do
    #selfsetup
    begin
      pre_selfsetup
      Capkg::Logger.start_log('*',-1,a_uname,'CMD START ( selfsetup ) ')
      # check
      Capkg::Repository.fetch_alltxt()
      v  = Capkg::PkgList.remote_all_txt().capkg()
      if ( v and v > Capkg::Pkg.str2v(Capkg::VERSION) )
        while true
          type = Capistrano::CLI.ui.ask("New CAPKG is available !\n Want to install new CAPKG ? ( "+Capkg::VERSION+" => "+Capkg::Pkg.v2str(v)+" )\n [yes/no]") { |q| q.default = ''}
          if 'yes' == type
            Capkg.install_capkg(v)
            Capkg::Logger.msg('LOCAL','*',-1,'','Install CAPKG success ')
            Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( selfsetup ) ')
            exit(0)
          elsif 'no' == type
            break
          end
        end
      end
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( selfsetup ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( selfsetup ) ')
  end
  #------------------------------
  #  Target hosts initialize
  task :setup do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( setup ) ')
    begin
      Capkg.setup_hosts(a_hosts,a_clean)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( setup ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( setup ) ')
  end
  #------------------------------
  #  Search registed package on repository
  task :search do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( search ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      Capkg.search_pkg(a_pkg,a_uname,a_searchall)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( search ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( search ) ')
  end
  #------------------------------
  #  Search installed package on target hosts
  task :list do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( list ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      Capkg.list_pkg(a_hosts,a_pkg)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( list ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( list ) ')
  end
  #------------------------------
  #  Install package with require packages to target hosts
  task :install do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( install ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      Capkg.install_pkg(a_hosts,a_pkg,Capkg::Pkg.str2v(a_version),a_libs,a_yes,a_downgrade,a_ignreq)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( install ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( install ) ')
  end
  #------------------------------
  #  Uninstall package with require packages from target hosts
  task :uninstall do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( uninstall ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      Capkg.uninstall_pkg(a_hosts,a_pkg,a_yes,a_force,a_ignreq)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( uninstall ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( uninstall ) ')
  end
  #------------------------------
  #  Generate configuration of package by scaning source FS.
  task :generate do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( generate ) ')
    begin
      Capkg.generate_pkg(a_pkg,a_root,a_targets,Capkg::Pkg.str2v(a_version),a_uname,a_requires,a_preactivate,a_predeactivate,a_postactivate,a_postdeactivate)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( generate ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( generate ) ')
  end
  #------------------------------
  #  Create package by configuration file.
  task :create do
    selfsetup
    Capkg::Logger.start_log(a_capkcf,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( create ) ')
    begin
      Capkg.create_pkg(a_capkcf)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_capkcf,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( create ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_capkcf,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( create ) ')
  end
  #------------------------------
  #  Upload package to repository.
  task :upload do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( upload ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      pkg     = a_pkg
      version = a_version
      uname   = a_uname
      if a_capkcf != ''
         cf = Capkg::Capkcf.new(capkcf)
         pkg     = cf.pkgname
         version = Capkg::Pkg.v2str(cf.version)
         uname   = cf.uname
      end
      Capkg.upload_pkg(pkg,Capkg::Pkg.str2v(version),uname)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( upload ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( upload ) ')
  end
  #------------------------------
  #  Invalidate a uploaded package to repository.
  task :invalidate do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( invalidate ) ')
    begin
      Capkg::Repository.fetch_alltxt()
      pkg     = a_pkg
      version = a_version
      uname   = a_uname
      if a_capkcf != ''
         cf = Capkg::Capkcf.new(capkcf)
         pkg     = cf.pkgname
         version = Capkg::Pkg.v2str(cf.version)
         uname   = cf.uname
      end
      Capkg.invalidate_pkg(pkg,Capkg::Pkg.str2v(version),uname)
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( invalidate ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( invalidate ) ')
  end
  #------------------------------
  #  Run shell at target hosts
  task :run_shell do
    selfsetup
    Capkg::Logger.start_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD START ( shell ) ')
    begin
      cmdfile = ''
      cmd = a_cmd
      if not a_cmdfile == ''
        cmdfile = '/tmp/' + File.basename(a_cmdfile)
        if not a_cmd == ''
          cmd = a_cmd + ';'
        end
        cmd += 'chmod 700 ' + cmdfile + ';'
        cmd += cmdfile + ';'
      end
      a_hosts.each {
        |host|
        begin
          if not a_cmdfile == ''
            upload_task(host,a_cmdfile,cmdfile)
          end
          Capkg::Logger.msg(host,a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'RUN SHELL :%s',cmd)
          msg = run_task(host,cmd)
          Capkg::Logger.msg(host,a_pkg,Capkg::Pkg.str2v(a_version),a_uname,"RESULT :\n%s",msg)
          if not a_cmdfile == ''
            remove_task(host,cmdfile)
          end
        rescue => msg
          Capkg::Logger.errmsg(host,a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'RUN SHELL FAILURE : %s',msg)
          begin
          rescue => msg
            if not a_cmdfile == ''
              remove_task(host,cmdfile)
            end
          end
        end
      }
    rescue => msg
      Capkg::Logger.errmsg('LOCAL',a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD FAILURE ( shell ) ')
      exit(1)
    end
    Capkg::Logger.end_log(a_pkg,Capkg::Pkg.str2v(a_version),a_uname,'CMD SUCCESS ( shell ) ')
  end
end

#######################################
#  Task runners
#######################################
def run_task(host,impl,eflg=true)
  Capkg::Logger.debug(host,'*',-1,'',impl)
  env_cmd  = sprintf("export %s='%s';",'CAPKG_BASE',Capkg::Def::CAPKG_BASE);
  impl = env_cmd + impl;
  su_task(host,impl,eflg)
end

def download_task(host,src,dst)
  role host.to_s do host end
  task :capkg_task, :roles => host.to_s do
    download src, dst
  end
  capkg_task
end

def upload_task(host,src,dst)
  role host.to_s do host end
  task :capkg_task, :roles => host.to_s do
    tmp = Capkg::Def::BASE_TMP + '/' + File.basename(dst)
    begin
      upload src, tmp
    rescue => ex
      raise '[upload_task] ' + ex.to_s + "\n      host : "+host+"\n        "+src+"\n     => "+ dst
    end
    run_task(host,sprintf('rm -f %s && mkdir -p %s && chown %s:%s %s && cp -f %s %s && chown %s:%s %s && rm -f %s',dst,File.dirname(dst),Capkg::Def::RUNNER,Capkg::Def::GROUP,File.dirname(dst),tmp,dst,Capkg::Def::RUNNER,Capkg::Def::GROUP,dst,tmp))
  end
  capkg_task
end
def remove_task(host,src)
  role host.to_s do host end
  task :capkg_task, :roles => host.to_s do
    run_task(host,'rm -f ' + src)
  end
  capkg_task
end

def su_task(host,impl,eflg)
  role host.to_s do host end
  task :capkg_task, :roles => host.to_s do
    err = Capkg::Def::BASE_TMP + '/' + Capkg::Def::FN_TASK_ERROR
    local_err = Capkg::Def::LOCAL_TMP + '/' + Capkg::Def::FN_TASK_ERROR
    out = Capkg::Def::BASE_TMP + '/' + Capkg::Def::FN_TASK_OUT
    err_msg=''
    msg = ''
    begin
      if eflg
        su_run '('+impl+') 2>' + err + ' >' + out , :as => runner
        local_out = Capkg::Def::LOCAL_TMP + '/' + Capkg::Def::FN_TASK_OUT
        download out, local_out
        File.open(local_out,'r') {
          |fp|
          msg = fp.read();
        }
      else
        su_run impl , :as => runner
      end
      return msg
    rescue => ex
      err_msg='[su_task] ' + ex.to_s + "\n      host : "+host+"\n      => "+impl+"\n"
      begin
        if eflg
          download err, local_err
          File.open(local_err,'r') {
            |fp|
            err_msg = fp.read();
          }
        end
      rescue => ex
        err_msg = ex.to_s
      end
      raise err_msg
    end
  end
  capkg_task
end
def sudo_task(host,impl,eflg)
  role host.to_s do host end
  task :capkg_task, :roles => host.to_s do
    sudo impl
  end
  capkg_task
end

class Net::SSH::Connection::Channel
  module RequestPtyWithGlobalModes
    def self.included(base)
	 #base.extend(ClassMethods)
	 base.send :alias_method, :request_pty_without_global_modes, :request_pty
	 base.send :alias_method, :request_pty, :request_pty_with_global_modes
    end

    def request_pty_with_global_modes(opts = {}, &block)
	 gmode = NET_SSH_PTY_MODES.dup rescue {}
	 opts[:modes] = gmode.merge(opts[:modes] || {})
	 request_pty_without_global_modes(opts, &block)
    end
  end
  include RequestPtyWithGlobalModes
end
NET_SSH_PTY_MODES = {
  Net::SSH::Connection::Term::ECHO => 0,
}

def su_run_block(cmd, passwd_var, passwd_prompt_patt, passwd_err_patt, tag_patt, callback)
  cmd_lines = cmd.scan(/\n/).size if cmd
  resp_buff = {}
  states = {}
  prompt_host = nil
  ps1_patt = /[$#>] $/ 
  #ps2_patt = /^[>] /  
  z_buff={}
  proc do |ch, stream, out|
    srv = ch[:server]
    password_resp = false
    unless states[srv]
      if out =~ passwd_err_patt
        password_resp = true
        if prompt_host.nil? || prompt_host == srv
          prompt_host = srv
          logger.important out, "#{stream} :: #{srv}"
          reset! passwd_var
        end
      end
      if out =~ passwd_prompt_patt
        password_resp = true
        ch.send_data "#{self[passwd_var]}\n"
      end
    end

    if cmd && !password_resp
      case states[srv]
      when nil
	if stream == :out && ps1_patt =~ out
	  ch.send_data "exec #{self['/bin/bash']}\n"
	  states[srv] = :first
	end
      when :first
	if stream == :out && ps1_patt =~ out
	  ch.send_data cmd
	  resp_buff[srv] = ''
	  states[srv] = :second
	end
      when :second
	if stream == :out
	  resp_buff[srv] << out
	  if resp_buff[srv].scan(tag_patt).size == 2
	    states[srv] = :third
	  end
	end
      when :third
	if callback == :no_log
	  self.class.default_io_proc.call(ch, stream, out) if stream == :err
	elsif callback == :default || !callback
	  self.class.default_io_proc.call(ch, stream, out)
	else
	  callback.call(ch, stream, out)
	end
      end
    end
  end
end

def su_run(cmd, options = {}, &block)
  opts = options.dup
  cmd = cmd.strip
  logger.debug "real command: #{cmd}"
  as = opts.delete(:as) || 'root'
  shell = opts.delete(:shell) || self[:default_shell] || '/bin/bash'
  env = opts.delete(:env) || {}
  pty = opts.include?(:pty) ? opts.delete(:pty) : true

  tag = Time.now.strftime("___%%Y_%%m_%%d__%%H_%%M_%%S__%04d___"%rand(9999))
  tag_patt = /#{Regexp.quote(tag)}\s*$/
  env = env.inject("") {|c, (n, v)| c + %Q!#{n}='#{v.gsub(/'/, "'\"'\"'").gsub(/[\\`$]/){"\\#{$&}"}}'; export #{n}\n! }
  cmd = cmd.gsub(/[\\`$]/) { "\\#{$&}" }
  cmd = "exec #{shell} <<#{tag}\n#{env}#{cmd}\nexit\n#{tag}\n"

  passwd_prompt_patt = /^#{Regexp.escape(sudo_prompt)}/
  passwd_err_patt = /^Sorry, try again/
  passwd_var = :password

  block_base_opts = [passwd_var, passwd_prompt_patt, passwd_err_patt, tag_patt]

  sudo_cmd = %Q!#{fetch(:sudo, "sudo")}  -p  "#{sudo_prompt}"! # XXX: to avoid to call internal sudo_behavior_callback
  #real_block = su_run_block(*[nil, block_base_opts, :no_log].flatten)
  #run("#{sudo_cmd} -l >/dev/null", :shell => false, :pty => true, &real_block)

  real_block = su_run_block(*[cmd, block_base_opts, block].flatten)
  run("#{sudo_cmd} su #{as}",opts.merge({:shell => false, :pty => pty}), &real_block)
end
