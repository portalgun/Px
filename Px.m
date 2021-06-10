classdef Px < handle & Px_util & Px_git & Px_hist & Px_install
% PERFORMANCE
% combine fd commands
%
% base toools downlaod and compile directory
properties
    root
    %root='~/Code/mat/'
    libDir
    rootWriteDir
    rootWrkDir
    rootPrjDir
    rootSbinDir
    rootHookDir
    rootCompiledDir
    configDir
    curPrjLoc

    ignoreDirs={'AR','_AR','_old','.git','.px','.svn'}

    prjs
    prj
    sbins

    Options  % 1 - paths
    rootconfig
    prjconfig
    prjDir
    prjWDir
    prjCompiledDir
    bHistory=true
    bProjectile=false
    bGtags=false
end
properties(Hidden)
    mode
    selfPath
    hostname
    curWrk
    curCmp
    wrkDirs
    matroot
    PRJS
    home
    installDir
    bases
    linkPrj
end
properties(Constant)
    sep=char(59)
    baseUrl='https://github.com/portalgun/MatBaseTools'
    baseV='master'
end
methods
    function obj=Px(varargin)
        obj.get_self_path();
        bInstalled=obj.get_install_status();

        if length(varargin) > 0
            obj.mode=varargin(1);
        else
            obj.mode='prompt';
        end
        if strcmp(obj.mode,'installPx') && bInstalled
            error('Px already installed');
        elseif strcmp(obj.mode,'installPx')
            obj.install_px(varargin{2:end});
            return
        elseif strcmp(obj.mode,'install2')
            obj.selfPath=varargin{2};
            obj.root=varargin{3};
            obj.rootconfig=varargin{4};
            obj.linkPrj=varargin{5};

            obj.setup_base_tools();
            obj.config_root();
            return
        elseif ~bInstalled
            error('Not installed');
        elseif length(varargin) > 1
            opts=struct(varargin{2:end});
        end

        obj.setup_base_tools();
        obj.config_root();
        % during installPx

        if  ismember(obj.mode,{'install2','reset','startup','get_current'})
            prj=obj.get_current_prj();
        end
        if strcmp(obj.mode,'get_current')
            return
        end

        obj.PRJS =Px.getProjects(obj.rootPrjDir);

        if ~exist('prj','var') || isempty(prj)
            obj.get_prjs();
            obj.disp_prjs();
            obj.prompt_prj();
        else
            obj.prj=prj;
        end
        obj.get_prj_dir();
        obj.prjconfig=[obj.prjDir '.px'];

        obj.save_cur_prj();

        %restoredefaultpath;
        cd(obj.selfPath);

        obj.get_prj_options();
        obj.make_wrk_dir();
        obj.parse_prj_options();

        %GETSBIN
        obj.sbins=Px.getProjects(obj.rootSbinDir,1);
        if ~isempty([obj.Options.rm])
            obj.sbins(ismember(obj.sbins,obj.Options.rm))=[];
        end
        obj.sbins(ismember(obj.sbins,obj.prj))=[];

        if obj.bHistory
            obj.make_history();
        end
        if obj.bGtags
            obj.gen_gtags();
        end
        obj.compile_prj_files();

        % NEEDS TO BE DONE LAST TO NOT DISRUPT BASE TOOLS
        pathlist=obj.get_paths();
        Path.add(pathlist,Path.default());

        obj.run_hooks();

        obj.cd_prj();
        obj.echo();
    end
    function obj=setup_base_tools(obj)
        % BASE TOOLS
        %dire=[obj.parent(obj.self_path) 'cbin' etc;

        obj.bases={obj.selfPath, [userpath filesep '.px' filesep]};
        out=obj.is_base_installed();
        if ~out
            out=obj.find_base_install_dir();
            if ~out
                error('No valid install directory')
            end
            obj.download_base_tools();
        end
        obj.compile_base_tools();
        obj.add_base_tools();
    end
    function obj=config_root(obj);
        obj.hostname=Sys.hostname();
        obj.home=Dir.home();
        obj.get_root();

        obj.find_root_config();
        obj.get_root_configs();
        obj.get_dirs();
        obj.save_settings();
    end
    function get_root(obj,opts)
        obj.root=obj.parent(obj.selfPath);
    end
    function prj=get_current_prj(obj)
        fid=fopen([obj.curPrjLoc '.current_project']);
        tline=fgets(fid);
        fclose(fid);
        prj=strtrim(strrep(tline,char(10),''));
    end
    function obj=find_root_config(obj);
        if ~isempty(obj.rootconfig)
            return
        end
        name='Px.config';

        list={[obj.root 'etc'], obj.home, obj.selfPath};
        for i = 1:length(list)
            fname=[list{i} name];
            if Fil.exist(fname)
                obj.rootconfig=fname;
                break
            end
        end
    end
    function obj=check_deps(obj)
        Sys.isInstalled('fd');
        Sys.isInstalled('find');
        Sys.isInstalled('git');
    end
    function obj=save_settings(obj)
        if ~isempty(obj.rootconfig)
            return
        end
        % XXX TODO
    end
%% BASE
    function out=is_base_installed(obj)
        out=false;
        if ~isempty(obj.installDir) && exist(dire,'dir')
            out=true;
            obj.installDir=dire;
            return
        end

        for i = 1:length(obj.bases)
            dire=[ obj.bases{i} 'MatBaseTools' filesep];
            if exist(dire,'dir')
                out=true;
                obj.installDir=dire;
                return
            end
        end
    end
    function out=find_base_install_dir(obj)
        for i = 1:length(obj.bases)
            dire=[ obj.bases{i} 'MatBaseTools' filesep];
            fname=[dire 'test.tmp'];
            try
                if ~exist(dire,'dir')
                    mkdir(dire);
                    rmdir(dire);
                else
                    fclose(fopen(fname,'w'));
                    delete(fname);
                end
                obj.installDir=dire;
                out=1;
                return
            end
        end
    end
    function obj=download_base_tools(obj)
        if exist(obj.installDir,'dir')
            return
        end

        Px.git_clone(obj.baseUrl,obj.installDir(1:end-1));
        if ~strcmp(obj.baseV,'master')
            Px.git_checkout(obj.installDir,obj.baseV);
        end
    end
    function obj=add_base_tools(obj)
        addpath(obj.installDir);
    end
    function obj=compile_base_tools(obj)
        list={'home_cpp','hostname_cpp','isinstalled_cpp','ln_cpp','readlink_cpp','issymlink_cpp','which_cpp'};
        for i = 1:length(list)
            fname=[obj.installDir list{i} '.cpp'];
            obj.mex_compile(fname,obj.installDir);
        end
    end
%% COMPILE
    function obj=mex_compile(obj,fname,outdir,bForce)
        if ~exist('bForce','var') || isempty(bForce)
            bForce=0;
        end

        %[dire,file,ext]=Fil.parts(fname);
        if ismac()
            han='.mexmaci64';
        elseif ispc()
            han='.mexw64';
        else
            han='.mexa64';
        end
        [~,name]=fileparts(fname);

        outfile=[outdir name han];
        if exist(outfile,'file') && ~bForce
            return
        end

        cmd=['mex -outdir ' outdir ' ' fname];
        try
            eval(cmd);
        catch ME
            if ~contains(ME.message,'mexa64'' is not a MEX file. ')
                disp(cmd);
                rethrow(ME);
            end
        end
    end
    function obj=compile_prj_files(obj)
        fnames=Fil.find(obj.prjDir,'.*\.c(pp)?$');
        if isempty(fnames)
            return
        end
        obj.prjCompiledDir=[obj.rootCompiledDir obj.prj filesep];
        Dir.mk_p(obj.prjCompiledDir);
        for i = 1:length(fnames)
            obj.mex_compile(fnames{i}, obj.prjDir);
        end

        % XXX TODO
        % DO THE SAME FOR DEPS

    end
%% ROOT CONFIG
    function obj=get_root_configs(obj)
        fid = fopen(obj.rootconfig);
        l=0;
        while true
            line=fgetl(fid);
            l=l+1;
            if ~ischar(line)
                break;
            elseif isempty(line) || startsWith(line,'#') || startsWith(line,'%')
                continue;
            end


            spl=strsplit(line,Px.sep);
            spl(cellfun(@isempty,spl))=[];
            typ=spl{1};
            typ=[Str.Alph.lower(typ(1)) typ(2:end)];

            blist={'projectile','history'};
            list={'root','rootCompiledDir','rootWriteDir','rootWrkDir','curPrjLoc','configDir'};
            if ismember(typ,blist)
                c=[ 'b' Str.Alph.upper(typ(1)) typ(2:end) ];
            elseif ismember(typ,list)
                c=typ;
            elseif startsWith(typ,'#') || startsWith(typ,'%')
                continue
            else
                error(['Invalid root property typ ' num2str(l) ': ' typ]);
            end

            if length(spl) == 1
                continue
            elseif length(spl) == 2 
                obj.(c)=spl{2};
            elseif length(spl) == 3 && strcmp(spl{2},obj.hostname)
                obj.(c)=spl{3};
            else
                continue
            end
            if Str.RE.ismatch(obj.(c),'^[0-9]+$');
                obj.(c)=str2double(obj.(c));
            end
        end
        fclose(fid);
        if isempty(obj.root)
            obj.root=[userpath filesep '.px' filesep];
        end
        if isempty(obj.rootWriteDir)
            obj.rootWriteDir=obj.root;
        end
    end
    function obj=get_dirs(obj)
        writeList={'rootWrkDir','rootCompiledDir'};
        % NEEDS TO BE WRITE
        if isempty(obj.rootWrkDir)
            obj.rootWrkDir ='bin';
        end
        if isempty(obj.rootCompiledDir)
            obj.rootCompiledDir ='cbin';
        end

        % CAN BE JUST READ
        if isempty(obj.rootPrjDir)
            obj.rootPrjDir ='prj';
        end
        if isempty(obj.rootSbinDir)
            obj.rootSbinDir='sbin';
        end
        if isempty(obj.rootHookDir)
            obj.rootHookDir='hooks';
        end
        if isempty(obj.libDir)
            obj.libDir='lib';
        end
        if isempty(obj.curPrjLoc)
            obj.curPrjLoc=obj.selfPath;
        end
        if isempty(obj.configDir)
            obj.configDir='etc';
        end

        prps={ ...
             ,'rootCompiledDir' ...
             ,'rootWrkDir' ...
             ,'rootPrjDir' ...
             ,'rootSbinDir' ...
             ,'rootHookDir' ...
             ,'libDir' ...
             ,'curPrjLoc' ...
        };
        for i = 1:length(prps)
            obj.(prps{i})=Dir.parse(obj.(prps{i}));
            if ~startsWith(obj.(prps{i}), obj.root) && ~Str.RE.ismatch(obj.(prps{i}),'^([A-Z]:|/)')

                if ismember(prps{i},writeList)
                    obj.(prps{i})=[obj.rootWriteDir obj.(prps{i})];
                else
                    obj.(prps{i})=[obj.root obj.(prps{i})];
                end
                if strcmp(prps{i},'rootPrjDir') &&  ~isempty(obj.linkPrj)
                    FilDir.ln(obj.linkPrj,obj.rootPrjDir);
                elseif ~exist(obj.(prps{i}),'dir')
                    mkdir(obj.(prps{i}));
                end
            end
        end

    end
%% PATH
    function obj=get_self_path(obj)
        obj.selfPath=obj.parent(mfilename('fullpath'));
    end
    function pathlist=get_paths(obj)
        % XXX get dependency prjCompiledDirs
        t=strcat(obj.rootSbinDir,obj.sbins);
        pathlist=transpose({obj.prjCompiledDir obj.selfPath obj.prjWDir t{:}});
        pathlist(cellfun(@isempty,pathlist))=[];
    end
    function obj=get_prjs(obj)
        obj.prjs=obj.PRJS;
        obj.prjs(ismember(obj.prjs,obj.ignoreDirs))=[];
    end
    function obj=disp_prjs(obj)
        disp([newline '  r last open poject']);
        fprintf(['%3.0f Sbin Only' newline newline],0);
        fprintf(['%-31s %-25s' newline],'DEVELOPMENT','STABLE');
        for i = 1:length(obj.prjs)
            if i > length(obj.prjs)
                %fprintf(['    %-25s   %3.0f %-25s' newline],repmat(' ',1,25),i+length(obj.prjs), obj.sprjs{i});
                fprintf(['    %-25s   %3.0f %-25s' newline],repmat(' ',1,25),i+length(obj.prjs), ' ');
            else
                %fprintf(['%3.0f %-25s   %3.0f %-25s' newline],i, obj.prjs{i},i+length(obj.prjs), ' ');
            end
        end
    end
    function obj=cd_prj(obj)
        cd(obj.prjDir);
    end
    function obj=get_prj_dir(obj)
        obj.prjDir=([obj.rootPrjDir obj.prj filesep]);
        obj.prjWDir=[obj.rootWrkDir obj.prj filesep];
    end
    function obj=prompt_prj(obj)
        %PROMPT FOR PROJECT
        val=['12345677890'];
        while true
            resp=input('Which Project?: ','s');
            if strcmp(resp,'r')
                pxr();
                return
            end

            if isempty(resp)
                return
            elseif any(~ismember(resp,val))
                disp('Invalid response')
                continue
            end
            resp=str2double(resp);
            if resp==0
                break
            elseif mod(resp,1)~=0
                disp('Invalid response')
                continue
            elseif resp > length(obj.prjs)
                disp('Invalid response')
                continue
            elseif resp < 1
                disp('Invalid response')
                continue
            end
            break
        end
        if resp==0
            obj.prj='_0_';
        else
            obj.prj=obj.prjs{resp};
        end
    end
    function obj=save_cur_prj(obj)
        fname=[obj.curPrjLoc '.current_project'];
        Fil.rewrite(fname,obj.prj);
        %if isunix()
        %    unix(cmd);
        %else
        %    system(cmd);
        %end
    end
    function obj=run_hooks(obj)
        if exist([obj.rootHookDir obj.prj '.m'])==2
            old=cd(obj.rootHookDir);

            %CHECK WHETHER HOOK IS SCRIPT OR FUNCTION WITH OUTPUT
            fid = fopen([obj.prj '.m'],'r');
            line=fgetl(fid);
            fclose(fid);
            try
                %check if function
                str=['^function *= *' obj.prj '\({0,1}\){0,1}$'];
                isfunc=any(isempty(regexp(line,str)));
                %but not with empty outputs
                str=['^function{1}\s*\[*\s*\]*=.*' prj];
                isfunc=isfunc & any(isempty(regexp(line,str)));
            catch
                isfunc=0;
            end

            %EVAL AS FUNCTION OR SCRIPT
            if isfunc
                out=eval([obj.prj ';']);
            else
                eval([obj.prj ';']);
            end

            cd(old);
        end
    end
    function obj=get_prj_options(obj)
        [obj,exitflag]=obj.get_prj_options_helper(1);
        bEcho=ismember(obj.mode,{'reset','prompt'});
        if exitflag==1 & bEcho
            disp(['No project config file found. Checking root config']);
        elseif isempty(obj.Options)
            if bEcho
                disp(['Config file is empty. Checking root config.']);
            end
            exitflag=1;
        end

        if exitflag==0
            return
        end
        [obj,exitflag]=obj.get_prj_options_helper(0);

        if exitflag==1 && obj.bEcho
            disp('No config file found. Skipping.')
            obj.Options(1).prj=obj.prjDir;
        elseif isempty(obj.Options) && obj.bEcho
            disp('Config entry does not exist. Skipping.')
            obj.Options(1).prj=obj.prjDir;
        end
    end
    function [obj,exitflag]=get_prj_options_helper(obj,bPrjConfig)
        if bPrjConfig
            config=obj.prjconfig;
        else
            config=obj.rootconfig;
        end

        % TODO
        % check for recursion

        %get config file

        exitflag=0;
        if ~exist(config,'file')
            exitflag=1;
            return
        end

        fid=fopen(config);

        %Section into seperate configs & create full paths
        obj.Options=struct();
        obj.Options.prj='';
        obj.Options.add=cell(0,1);
        obj.Options.rm=cell(0,1);
        obj.Options.site=cell(0,1);
        obj.Options.version=cell(0,1);

        bStart=bPrjConfig; % Indicates valid header has been identified
        if bPrjConfig
            obj.Options(1).prj=obj.prjDir;
            obj.Options(1).add{1,1}=obj.prjDir;
        end
        configs={'root','history','projectile'};
        while true
            tline=fgetl(fid);

            % BREAK IF COMPLETE
            if ~ischar(tline); break; end

            % SKIP EMPTY LIMES
            if isempty(tline); continue; end
            if Str.RE.ismatch(tline,'^ *#'); continue; end

            % No indents indicate new block
            bNew=~bPrjConfig && ~Str.RE.ismatch(tline,'^\s') && ~startsWith(tline,configs);

            if ~bNew && ~bStart
                continue
            elseif bNew %header
                [obj,bStart]=get_header(obj,tline);
            elseif ~bNew && bStart %body
                obj=get_body(obj,tline);
            end
        end
        fclose(fid);

        function [obj,bStart]=get_header(obj,tline)
            if Str.RE.ismatch(tline,'^[rR]oot:')  || Str.RE.ismatch(tline,'^curPrjLoc')
                bStart=0;
                return
            end
            bStart=1;
            [code,dire,host,version]=Px.strip_fun(tline,Px.sep,obj.PRJS); % a = s,d,e
            [dest,rdest,site]=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.libDir,obj.hostname);
            if isempty(dest)
                return
            end
            if isempty(obj.prj) || (strcmp(obj.prj,dire(1:end-1)))
                obj.Options(end+1).prj=dest;
                obj.Options(end).add{1,1}=dest;
                obj.Options(end).rm{1,1}=dest;
                obj.Options(end).version{1,1}=dest;
                obj.Options(end).site{1,1}=dest;
            else
                bStart=0;
            end

        end
        function obj=get_body(obj,tline)
            [code,dire,host,version]=Px.strip_fun(tline,Px.sep,obj.PRJS);
            [dest,rdest,site]=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.libDir,obj.hostname);
            obj.Options(end+1).add=dest;
            obj.Options(end).rm=rdest;
            obj.Options(end).version=version;
            obj.Options(end).site=site;
            %obj.Options(end).add{end+1,1}=dest;
            %obj.Options(end).rm{end+1,1}=rdest;
            %obj.Options(end).version{end+1,1}=version;
            %obj.Options(end).site{end+1,1}=site;
        end
    end
    function obj=make_wrk_dir(obj)
        obj.curWrk=[obj.rootWrkDir obj.prj filesep];
        if ~exist(obj.curWrk,'dir')
            mkdir(obj.curWrk);
        end
        if obj.bProjectile && ~exist([obj.curWrk '.projectile'])
            Fil.touch([obj.curWrk '.projectile']);
        end
    end
    function obj=parse_prj_options(obj)
        obj.clone_to_lib();
        obj.rm_removed_symlinks();
        obj.populate_wrk_dir();
    end
    function obj=clone_to_lib(obj);
        for i = 2:length(obj.Options)
            O=obj.Options(i);
            if isempty(O.site)
                return
            end
            Px.git_clone(O.site,O.add);
            if ~isempty(O.version)
                Px.git_checkout(O.add,O.version);
            end

        end
    end
    function obj=rm_removed_symlinks(obj)
        if isempty(obj.Options)
            return
        end
        deps=transpose([obj.Options.add]);
        deps=cellfun(@get_name_fun,deps,'UniformOutput',false);

        dirs=dir(obj.curWrk);
        dirs=dirs(3:end);
        name=transpose({dirs.name});
        full=join([transpose({dirs.folder}) name],filesep);
        bDir=vertcat(dirs.isdir);
        %bDir=bDir(3:end);
        %full=full(3:end);
        %name=name(3:end);
        ind=bDir & ~ismember(name,deps);
        rmdirs=full(ind);
        for i = 1:length(rmdirs)
            delete(rmdirs{i}); % works with symlinks
        end

        function out=get_name_fun(file)
            if endsWith(file,filesep)
                file=file(1:end-1);
            end
            if endsWith(file,'.m')
                ext='.m';
            else
                ext='';
            end
            [~,out]=fileparts(file);
            out=[out ext];

        end
    end
    function obj=populate_wrk_dir(obj);
        %Make sure that projects in each exist, then symlink
        obj.wrkDirs={};
        for i=1:length(obj.Options)
            O=[obj.Options(i)];
            if ~isempty(O.prj)
                m=O.prj; %main project directory
            elseif isempty(O.prj) && ~isempty(O.add)
                m=O.add; %main project directory
            elseif isempty(O.prj) && isempty(O.add)
                continue
            elseif ~exist(m,'dir')
                disp(['Directory ' m ' does not exist']);
                continue
            end
            seen=cell(0,1);
            for j = 1:length(O.add)
                if iscell(O.add)
                    s=O.add{j}; %dependencies
                else
                    s=O.add;
                end
                if ~exist(s,'dir')
                    disp(['Directory ' s ' does not exist']);
                    continue
                end
                if endsWith(s,filesep)
                    s=s(1:end-1);
                end
                if ismember(s,seen)
                    continue
                end
                name=fliplr(strtok(fliplr(s),filesep));
                dest=[obj.curWrk name];

                Px.LN_fun(s,dest,0,obj.home);

                %if (~ispc && ~exist([obj.curWrk name],'dir')) || (ispc && ~exist([obj.curWrk name],'file'))
                seen=[seen; s];
                obj.wrkDirs{end+1,1}=dest;
            end
        end
    end
    function obj=lock_lib_files(obj)
        % TODO make read only -> make readonly
        % chmod -w
    end
    function obj=gen_gtags(obj)
        if isunix()
            unix([obj.selfPath 'gen_gtags.sh']);
        else
            disp('Gtags not yet supported for Windows')
        end
    end
    function obj=echo(obj)
        switch obj.mode
        case {'prompt','startup'}
            display('Done.')
        case 'reset'
            display(['Done reloading project ' obj.prj '.']);
        end
    end
end
methods(Static, Access=?Px_install)
    function [code,dire,host,version]=strip_fun(tline,sep,prjs)
        code=[];
        dire=[];
        host=[];
        version=[];
        %if Px.regexprep(tline,'^[a-z,A-Z]:')
        strs=strsplit(tline,sep);

        bVers=0;
        for i = 1:length(strs)
            str=strs{i};
            if ischar(str) && numel(str)==1 && i==1
                code=str;
            elseif i==2 && length(strs)==3
                host=str;
            elseif ismember(filesep,str) || ismember(str,prjs) || (~isempty(code) && code=='l')
                dire=Dir.parse(str);
            elseif ismember(i,[3,4])
                version=str;
            end
        end
    end

    function [dest,rdest,site]=sort_fun(code,dire,host,version,rootPrjDir,libDir,hostname)
        dest=[];
        rdest=[];
        site=[];
        if ~isempty(host) && ~strcmp(host,hostname)
            return
        end

        code
        switch code
            case 'd'
                dest=[rootPrjDir dire];
            case 'e'
                dest=dire;
            case 'i'
                rdest=dire;
            case 'l'
                site=dire;
                if ~isempty(version)
                    dire=Px.get_version_dire_name(version,dire);
                end
                dest=[libDir dire];
            otherwise
                error(['Invalid label ' code ' for ' dire]);
        end
        if ~isempty(dest)
            dest=Dir.parse(dest);
        end
        if ~isempty(rdest)
            rdest=Dir.parse(rdest);
        end
    end
    function out=parent(dire)
        if endsWith(dire,filesep)
            dire=dire(1:end-1);
        end
        spl=strsplit(dire,filesep);
        out=strjoin(spl(1:end-1),filesep);
        if ~endsWith(out,filesep)
            out=[out filesep];
        end
    end
end
end
