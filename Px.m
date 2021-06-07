classdef Px < handle & Px_util & Px_git & Px_hist
% unix            29%     getlinksource(19) LN(4)
% ln
% issymbolic link
% hostname
% isunix
% islinux
properties
    root
    %root='~/Code/mat/'
    libDir
    rootWrkDir
    rootSWrkDir
    rootPrjDir
    rootStbDir
    rootTlbxDir
    rootHookDir

    ignoreDirs={'AR','_AR','_old','.git'}

    prjs
    sprjs
    prj
    tlbxs

    Options  % 1 - paths
    rootconfig
    prjconfig
    prjDir
    prjWDir
    bHistory=1
    bProjectile=0
    bGtags=0
end
properties(Hidden)
    bEcho
    selfPath
    selfCompiledDir
    stableflag
    hostname
    curWrk
    curCmp
    wrkDirs
    matroot
    PRJS
    SPRJS
    home
end
properties(Constant)
    sep=char(59)
end
methods
    function obj=Px(prj,bStable,bEcho)
        if ~exist('bStable','var') || isempty(bStable)
            bStable=0;
        end
        if ~exist('bEcho') || isempty(bEcho)
            obj.bEcho=1;
        else
            obj.bEcho=bEcho;
        end

        obj.hostname=Px.get_hostname();
        obj.home=Px.gethome();
        obj.get_self_path();
        obj.rootconfig=[obj.selfPath '.config'];
        if ~exist(obj.rootconfig,'file')
            obj.setup();
        end

        obj.get_root_configs();
        obj.get_dirs();
        if exist('prj','var') && ~isempty(prj) && (isnumeric(prj) || strcmp(prj,'_0_'))
            prj=Px.get_current();
        end

        obj.sprjs=Px.getProjects(obj.rootStbDir);
        obj.PRJS =Px.getProjects(obj.rootPrjDir);

        if ~exist('prj','var') || isempty(prj)
            obj.get_prjs(bStable);
            obj.disp_prjs();
            obj.prompt_prj();
        elseif  startsWith(prj,'s:')
            obj.prj=strrep(prj,'s:','');
            obj.stableflag=1;
        else
            obj.prj=prj;
            obj.stableflag=0;
        end
        if bStable
            obj.stableflag=1;
        end
        obj.get_prj_dir();
        obj.prjconfig=[obj.prjDir '.px'];

        obj.save_cur_prj();

        %restoredefaultpath;
        cd(obj.selfPath);

        obj.get_prj_options();
        obj.make_wrk_dir();
        obj.parse_prj_options();

        %GETTOOLBOXES
        obj.tlbxs=Px.getProjects(obj.rootTlbxDir,1);
        if ~isempty([obj.Options.rm])
            obj.tlbxs(ismember(obj.tlbxs,obj.Options.rm))=[];
        end
        obj.tlbxs(ismember(obj.tlbxs,obj.prj))=[];

        %ADD TOOLBOXES IF NOT ADDED ALREADY, UNLESS EXCLUDED

        defpath=Px.get_default_path();
        t=strcat(obj.rootTlbxDir,obj.tlbxs);
        pathlist=transpose({obj.selfPath obj.prjWDir t{:}});

        obj.add_path(pathlist,defpath);

        obj.cd_prj();

        if obj.bHistory
            obj.make_history();
        end
        if obj.bGtags
            obj.gen_gtags();
        end

        obj.run_hooks();
        if obj.bEcho
            display('Done.')
        end
    end
    function obj=init(obj);
        obj.hostname=Px.get_hostname();
        obj.home=Px.gethome();
        obj.get_self_path();
        obj.rootconfig=[obj.selfPath 'Px.config'];
        if ~exist(obj.rootconfig,'file')
            obj.setup();
        end

        obj.get_root_configs();
        obj.get_dirs();

        % XXX
        %obj.make_root_compiled_dir();
        %obj.compile_root_mex();
    end
    function obj=setup(obj)
    end
    function obj=compile_root_mex(obj)
        srcs={'issymlink','readlink'};
        sHandle='.cpp';

        if Px.islinux
            cHandle='.mexa64';
        elseif ismac
            cHandle='.mexmaci64';
        elseif ispc
            cHandle='.mexw64';
        end

        for i = 1:length(srcs)
            src=srcs{i};
            outfile=[obj.selfCompiledDir src cHandle];

            if ~exist(outfile,'file')
                infile=[obj.selfPath src sHandle];
                cmd=['mex -outdir ' obj.seflCompiledDir infile];
                eval(cmd);
            end
        end
    end
    function obj=get_root_configs(obj)
        fid = fopen(obj.rootconfig);
        while true
            line=fgetl(fid);
            if ~ischar(line); break; end

            if Px.regExp(line,'^[Rr]oot;')
                c='root';
            elseif Px.regExp(line,'^[Pp]rojectile')
                c='bProjectile';
            elseif Px.regExp(line,'^[Pp]rojectile')
                c='bGtags';
            elseif Px.regExp(line,'^[Hh]istory')
                c='bHistory';
            elseif Px.regExp(line,'^rootWrkDir')
                c='rootWrkDir';
            elseif Px.regExp(line,'^rootSWrkDir')
                c='rootSWrkDir';
            elseif Px.regExp(line,'^curPrjLoc')
                c='curPrjLoc';
            elseif Px.regExp(line,'^configDir')
                c='configDir';
            elseif Px.regExp(line,'^rootCompiledDir')
                c='rootCompiledDir';
            else
                continue
            end
            spl=strsplit(line,Px.sep);
            spl(cellfun(@isempty,spl))=[];

            if length(spl) == 1
                continue
            elseif length(spl) == 2 && exist(spl{2},'dir')
                obj.(c)=spl{2};
            elseif length(spl) == 3 && strcmp(spl{2},obj.hostname)
                obj.(c)=spl{3};
            else
                continue
            end
            if Px.regExp(obj.(c),'[0-9]+');
                obj.(c)=str2double(obj.(c));
            end
        end
        fclose(fid);
        if ~isempty(obj.root)
            Px.filesepc(obj.root);
        else
            error('No root directory found in config');
        end

    end
    function obj=get_paths()
    end
    function obj=get_self_path(obj)
        fname=mfilename;
        fdir=mfilename('fullpath');
        dir=[obj.rootStbDir obj.prj];
        obj.selfPath=strrep(fdir,fname,'');
    end
    function obj=add_self_path(obj)
    end
    function obj=get_dirs(obj)
        if isempty(obj.rootWrkDir)
            obj.rootWrkDir ='workspaces';
        end
        if isempty(obj.rootSWrkDir)
            obj.rootSWrkDir='stableWorkspaces';
        end
        if isempty(obj.rootPrjDir)
            obj.rootPrjDir ='projects';
        end
        if isempty(obj.rootStbDir)
            obj.rootStbDir ='stableProjects';
        end
        if isempty(obj.rootTlbxDir)
            obj.rootTlbxDir='toolboxes';
        end
        if isempty(obj.rootHookDir)
            obj.rootHookDir='localHooks';
        end
        if isempty(obj.libDir)
            obj.libDir='lib';
        end

        prps={ ...
             ,'rootWrkDir' ...
             ,'rootSWrkDir' ...
             ,'rootPrjDir' ...
             ,'rootStbDir' ...
             ,'rootTlbxDir' ...
             ,'rootHookDir' ...
             ,'libDir' ...
        };
        for i = 1:length(prps)
            obj.(prps{i})=Px.filesepc(obj.(prps{i}));
            if ~startsWith(obj.(prps{i}), obj.root) && ~Px.regExp(obj.(prps{i}),'^([A-Z]:|/)')
                obj.(prps{i})=[obj.root obj.(prps{i})];
                if ~exist(obj.(prps{i}),'dir')
                    mkdir(obj.(prps{i}));
                end
            end
        end

    end
    function obj=get_prjs(obj,bStable)
        if bStable
            obj.prjs=obj.sprjs;
        else
            obj.prjs=obj.PRJS;
        end
        obj.prjs(ismember(obj.prjs,obj.ignoreDirs))=[];
        obj.sprjs(ismember(obj.sprjs,obj.ignoreDirs))=[];
    end
    function obj=disp_prjs(obj)
        disp([newline '  r last open project']);
        fprintf(['%3.0f Toolboxes Only' newline newline],0);
        fprintf(['%-31s %-25s' newline],'DEVELOPMENT','STABLE');
        for i = 1:length(obj.prjs)
            if i > length(obj.sprjs)
                fprintf(['%3.0f %-25s' newline],i, obj.prjs{i});
            elseif i > length(obj.prjs)
                fprintf(['    %-25s   %3.0f %-25s' newline],repmat(' ',1,25),i+length(obj.prjs), obj.sprjs{i});
            else
                fprintf(['%3.0f %-25s   %3.0f %-25s' newline],i, obj.prjs{i},i+length(obj.prjs), obj.sprjs{i});
            end
        end
    end
    function obj=cd_prj(obj)
        cd(obj.prjDir);
    end
    function obj=get_prj_dir(obj)
        %CHANGE DIRECTORY TO PROJECT DIRECTORY
        if obj.stableflag==1 && ~strcmp(obj.prj,'_0_')
            obj.prjDir=[obj.rootStbDir obj.prj filesep];
            obj.prjWDir=[obj.rootSWrkDir obj.prj filesep];
        elseif ~strcmp(obj.prj,'_0_')
            obj.prjDir=([obj.rootPrjDir obj.prj filesep]);
            obj.prjWDir=[obj.rootWrkDir obj.prj filesep];
        end
    end
    function obj=prompt_prj(obj)
        %PROMPT FOR PROJECT
        val=['12345677890'];
        obj.stableflag=0;
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
            elseif resp > length(obj.prjs) && resp <= (length(obj.prjs) + length(obj.sprjs))
                obj.stableflag=1;
                break
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
        elseif obj.stableflag==1
            obj.prj=obj.sprjs{resp-length(obj.prjs)};
        else
            obj.prj=obj.prjs{resp};
        end
    end
    function obj=save_cur_prj(obj)
        % TODO different for PC
        if obj.stableflag==1
            cmd=['echo s:' obj.prj ' > ' obj.curPrjLoc '.current_project'];
        else
            cmd=['echo ' obj.prj ' > ' obj.curPrjLoc '.current_project'];
        end
        if isunix()
            unix(cmd);
        else
            system(cmd);
        end
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
        if exitflag==1 & obj.bEcho
            disp(['No project config file found. Checking root config']);
        elseif isempty(obj.Options)
            if obj.bEcho
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

        %function []=pxs(rootPrjDir,rootStbDir,rootTlbxDir)
        %px symbolic links - handle dependencies
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
        configs={'root','history'};
        while true
            tline=fgetl(fid);

            % BREAK IF COMPLETE
            if ~ischar(tline); break; end

            % SKIP EMPTY LIMES
            if isempty(tline); continue; end

            % No indents indicate new block
            bNew=~bPrjConfig && ~Px.regExp(tline,'^\s') && ~startsWith(tline,configs);

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
            if Px.regExp(tline,'^[rR]oot:')
                bStart=0;
                return
            end
            bStart=1;
            [code,dire,host,version]=Px.strip_fun(tline,Px.sep,obj.PRJS,obj.sprjs); % a = s,d,e
            [dest,rdest,site]=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.rootStbDir,obj.libDir,obj.hostname);
            if isempty(dest)
                return
            end
            if isempty(obj.prj) || (strcmp(obj.prj,dire(1:end-1)) && ((obj.stableflag==1 && code=='s') || ((obj.stableflag==0 && code=='d'))))
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
            [code,dire,host,version]=Px.strip_fun(tline,Px.sep,obj.PRJS,obj.sprjs);
            [dest,rdest,site]=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.rootStbDir,obj.libDir,obj.hostname);
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
        if obj.stableflag==1
            obj.curWrk=[obj.rootSWrkDir obj.prj filesep];
        else
            obj.curWrk=[obj.rootWrkDir obj.prj filesep];
        end
        if ~exist(obj.curWrk,'dir')
            mkdir(obj.curWrk);
        end
        if obj.bProjectile && ~exist([obj.curWrk '.projectile'])
            Px.touch([obj.curWrk '.projectile']);
        end
    end
    function obj=make_root_compiled_dir(obj)
        if ~exist(obj.rootCompiledDir,'dir')
            mkdir(obj.rootCompiledDir);
        end
        obj.selfCompiledDir=[obj.rootCompiledDir '.Px' filesep];
        if ~exist(obj.selfCompiledDir)
            mkdir(obj.selfComipledDir);
        end
        addpath(obj.selfCompiledDir);
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
        deps=obj.Options(1).add;
        deps=cellfun(@get_name_fun,deps,'UniformOutput',false);

        dirs=dir(obj.curWrk);
        name=transpose({dirs.name});
        full=join([transpose({dirs.folder}) name],filesep);
        ind=vertcat(dirs.isdir) & ~ismember(name,[{'.'; '..'}; deps]);
        rmdirs=full(ind);
        for i = 1:length(rmdirs)
            delete(rmdirs{i}); % works with symlinks
        end

        function out=get_name_fun(file)
            if endsWith(file,'/')
                file=file(1:end-1);
            end
            [~,out]=fileparts(file);

        end
    end
    function obj=populate_wrk_dir(obj);
        %Make sure that projects in each exist, then symlink
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
    function obj=gen_gtags(obj)
        if isunix()
            unix([obj.selfPath 'gen_gtags.sh']);
        else
            disp('Gtags not yet supported for Windows')
        end
    end
end
methods(Static, Access=private)
    function [code,dire,host,version]=strip_fun(tline,sep,prjs,sprjs)
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
            elseif ismember(filesep,str) || ismember(str,[prjs sprjs]) || (~isempty(code) && code=='l')
                dire=Px.filesepc(str);
            elseif ismember(i,[3,4])
                version=str;
            end
        end
    end

    function [dest,rdest,site]=sort_fun(code,dire,host,version,rootPrjDir,rootStbDir,libDir,hostname)
        dest=[];
        rdest=[];
        site=[];
        if ~isempty(host) && ~strcmp(host,hostname)
            return
        end

        switch code
            case 's'
                dest=[rootStbDir dire];
            case 'd'
                dest=[rootPrjDir dire];
            case 'e'
                dest=dire;
            case 'i'
                rdest=dire;
            case 'l'
                site=dire;
                dire=Px.get_version_dire_name(version,dire);
                dest=[libDir dire];
            otherwise
                error(['Invalid label ' code ]);
        end
        if ~isempty(dest)
            dest=Px.filesepc(dest);
        end
        if ~isempty(rdest)
            rdest=Px.filesepc(rdest);
        end
    end
end
end
