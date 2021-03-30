classdef Px < handle
% genpath         50%     dir
% unix            29%     getlinksource(19) LN(4)
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
end
properties(Hidden)
    bEcho
    selfPath
    stableflag
    hostname
    curWrk
    matroot
    PRJS
    SPRJS
    home
end
properties(Constant)
    sep=';';
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

        obj.run_hooks();
        if obj.bEcho
            display('Done.')
        end
    end
    function obj=setup(obj)
    end
    function obj=get_root_configs(obj)
        fid = fopen(obj.rootconfig);
        while true
            line=fgetl(fid);
            if ~ischar(line); break; end

            if Px.regExp(line,'^[Rr]oot;')
                c='root';
            elseif Px.regExp(line,'^[Hh]istory')
                c='bHistory';
            elseif Px.regExp(line,'^rootWrkDir')
                c='rootWrkDir';
            elseif Px.regExp(line,'^rootSWrkDir')
                c='rootSWrkDir';
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
    function obj=make_history(obj)
        obj.save_history();
        %/home/dambam/.matlab/java/jar/mlservices.jar
        %% MAKE history files
        prjdir=obj.prjDir;
        mdir=Px.filesepc(prefdir);

        names={'history.m','History.xml','History.bak'};
        % History.xml = desktop command history

        for i = 1:length(names)
            history_fun(names{i},prjdir,mdir);
        end

        obj.reload_history();

        function history_fun(name,prjdir,mdir)
            pHist=[prjdir '.' name];
            mHist=[mdir name];
            if ~exist(mHist,'file') % XXX SLOW 1
                error(['History file ' name 'does not exist']);
            end
            if ~exist(pHist,'file') % XXX SLOW 5
                Px.touch(pHist);
            end
            bSym=Px.issymboliclink(mHist); % XXX SLOW 3
            if bSym && strcmp(Px.getlinksource(mHist),pHist); % XXX SLOW 2
                return
            elseif bSym
                delete(mHist);
            else
                movefile(mHist,[mHist '_bak']);
            end

            Px.LN(pHist,mHist); % XXX SLOW 4


        end
    end
    function obj=history2string(obj,dire)
        history = string(fileread(fullfile(dire, 'History.xml')));
    end
    function obj=clear_history(obj)
        com.mathworks.mlservices.MLCommandHistoryServices.removeAll;
    end
    function obj=save_history(obj)
        com.mathworks.mlservices.MLCommandHistoryServices.save;
    end
    function obj=reload_history(obj)
        file=java.io.File(com.mathworks.util.FileUtils.getPreferencesDirectory, "History.xml");
        com.mathworks.mde.cmdhist.AltHistory.load(file,false);
    end
    function obj=load_history_from_file(obj)
        mdir=Px.filesepc(prefdir);
        mHist=[mdir 'history.m'];
    end
    function obj=restore_original_history(obj)
        dire=prefdir;
        mHistM=[dire 'history.m'];
        mHistX=[dire 'History.xml'];
        mHistB=[dire 'History.bak'];

        % DELETE SYMS
        if issymboliclink(mHistM)
            delete(mHistM);
        end
        if issymboliclink(mHistX)
            delete(mHistX);
        end
        if issymboliclink(mHistB)
            delete(mHistB);
        end

        % Restore OLD
        movefile([mHistM '_bak'],mHistM);
        movefile([mHistX '_bak'],mHistX);
        movefile([mHistB '_bak'],mHistB);
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

        if ispc
            % XXX MOVE
            %obj.rootWrkDir=strrep(obj.rootWrkDir,'~\Code\mat','E:\matenv');
            %obj.rootSWrkDir=strrep(obj.rootSWrkDir,'~\Code\mat','E:\matenv');
            obj.rootWrkDir

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
        if ispc
            %system(cmd);
        else
            if obj.stableflag==1
                cmd=['echo s:' obj.prj ' > ' obj.selfPath '.current_project'];
            else
                cmd=['echo ' obj.prj ' > ' obj.selfPath '.current_project'];
            end
            unix(cmd);
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
                [~,name]=fileparts(s(1:end-1));
                s=s(1:end-1);
                
                %if (~ispc && ~exist([obj.curWrk name],'dir')) || (ispc && ~exist([obj.curWrk name],'file'))
                if ~exist([obj.curWrk name],'dir')
                    Px.LN(s,obj.curWrk);
                else
                    bTest=0;
                    Px.fix_link([obj.curWrk name],s,bTest,obj.home);
                end
            end
        end
    end
end
methods(Static,Access=private)
    function dire=filesepc(dire)
        %function dire=filesepc(dire)
        %adds filesep to end if it doesn't already exist
        dire=strrep(dire,'/',filesep);
        if ~endsWith(dire,filesep)
            dire=[dire filesep];
        elseif strcmp(dire(end),filesep) && strcmp(dire(end-1),filesep)
            dire=dire(1:end-1);
        end
    end
    function home=gethome()
        if Px.islinux()
            [~,home]=unix('echo $HOME');
            home=strrep(home,newline,'');
        else
            home='Y:'; % XXX ADD TO CONFIG
        end
    end
    function out= issymboliclink(dire)
        if ispc
            cmd=['powershell -Command "((Get-Item ' dire ' -Force -ea SilentlyContinue).Attributes)'] %;-band [IO.FileAttributes]::ReparsePoint)"'];
            [~,islink]=system(cmd);
            islink=strrep(islink,newline,'');
            out=strcmp(islink,'True');
        elseif Px.islinux
            out=issymlink(dire);
        else
            out=~unix(['test -L ' dire]);
        end
    end
    function out = islinkbroken(dire)
        out=~unix(['[[ ! -e ' dire ' ]] && echo 1']);
    end

    function out =getlinksource(dire)
        if ispc
            cmd=['powershell -Command "(Get-Item ' dire ').Target'];
            [~,src]=system(cmd);
            out=strrep(src,newline,'');
            return
        elseif ismac
            str=['readlink ' dire];
        elseif Px.islinux
            str=['readlink -f ' dire];
        end
        [bS,out]=unix(str);
        out=out(1:end-1);
        if bS==1
            out=nan;
        end
    end

    function bSuccess=LN(origin,destination)
    %ln(origin,destination)
    %create symbolic links
        if ispc
            [~,name]=fileparts(origin);
            destination = [ destination name ];
            %if exist(destination,'file')
            %    bSuccess=1;
            %    return
            %end
            %cmd=['runas /user:administrator "mklink ' origin ' ' destination '"'];
            cmd=['mklink /d ' destination ' ' origin];
            [bSuccess]=system(cmd);
        else
            cmd=['ln -s ' origin ' ' destination];
            [bSuccess]=unix(cmd);
        end

    end

    function out = regExp(cell,exp,bIgnoreCase)
    %function out = regExp(cell,exp,bIgnoreCase)
    %version of regexp that works will cells, returning a logical index
        if ~exist('bIgnoreCase','var') || isempty(bIgnoreCase)
            bIgnoreCase=0;
        end
        if ~iscell(cell) && bIgnoreCase==1
            out=~isempty(regexp(cell,exp,'ignorecase'));
        elseif ~iscell(cell)
            out=~isempty(regexp(cell,exp,'ignorecase'));
        elseif bIgnoreCase==1
            out=~cell2mat(transpose(cellfun( @(x) isempty(regexp(x,exp,'ignorecase')),cell,'UniformOutput',false)));
        else

            out=~cell2mat(transpose(cellfun( @(x) isempty(regexp(x,exp)),cell,'UniformOutput',false)));
        end
    end
    function hn = get_hostname()
        if ispc
            [~,hn]=system('hostname');
        else
            [~,hn]=unix('hostname');
        end
        hn=strrep(hn,newline,'');
    end
    function out = islinux()
        switch computer
        case {'GLNXA64','GLNXA32'}
            out=1;
        otherwise
            out=0;
        end
    end
    function []=fix_link(dire,gdSrc,bTest,home)
        if ~exist('bTest','var') || isempty(bTest)
            bTest=0;
        end
        gdSrc=strrep(gdSrc,'~',home);

        islink=Px.issymboliclink(dire);
        if islink==0
            error([ 'Unexpected non-symbolic link at ' dire ]);
        end

        src=Px.getlinksource(dire);
        if isnan(src)
            error('Something went wrong');
        end

        if ~ispc
            gdSrc=Px.getlinksource(gdSrc);
        end
        if ~bTest && ~strcmp(gdSrc,src)
            warning(['Fixing bad symlink ' src ' to ' gdSrc]);
            delete(dire);
            Px.LN(gdSrc,dire);
        elseif bTest
            disp(dire);
            disp(src);
            disp(gdSrc);
        end
    end
    function out=touch(fname)
        out=fclose(fopen(fname,'w'));
    end
    function [code,dire,host,version]=strip_fun(tline,sep,prjs,sprjs)
        code=[];
        dire=[];
        host=[];
        version=[];
        strs=strsplit(tline,sep);


        bVers=0;
        for i = 1:length(strs)
            str=strs{i};
            if ischar(str) && numel(str)==1
                code=str;
            elseif ismember(filesep,str) || ismember(str,[prjs sprjs])
                dire=Px.filesepc(str);
            elseif i==2
                host=str;
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
    function lines=file2cell(fname)
        fid = fopen(fname);
        tline = fgetl(fid);
        lines={};
        while ischar(tline)
            lines{end+1}=tline;
            tline = fgetl(fid);
        end
        fclose(fid);
    end

end
methods(Static)
    function out=getProjects(rootPrjDir,accept)
        if ~exist('accept','var') || isempty(accept)
            accept=0;
        end
    % GET ALL PROJECTS IN PROJECT DIRECTORY
        folder=dir(rootPrjDir);
        ind=transpose([folder.isdir]);
        f=transpose({folder.name});
        folders=f(ind);
        out=cell2mat(transpose(cellfun( @(x) isempty(regexp(x,'^\.')),folders,'UniformOutput',false)));
        out=transpose(folders(out));
        if ~accept
            ind=startsWith(out,'_');
            out(ind)=[];
        end
    end

    function oldPath=add_path(pathlist,defpath)
        dirs=[defpath pathsep Px.gen_path(pathlist)];

        try
            %oldPath = addpath(dirs, '-end');
            oldPath = matlabpath(dirs);
        catch
            warning('Problem adding path. Likley a borken sym link.');
        end
    end

    function cleanPath = cleanPath(originalPath)
    % CLEANUP A GENERATED PATH

        % BREAK THE PATH INTO SEPARATE ENTRIES
        scanResults = textscan(originalPath, '%s', 'delimiter', pathsep());
        pathElements = scanResults{1};

        % LOCATE SVN, GIT, MERCURIAL ENTRIES
        isCleanFun = @(s) isempty(regexp(s, '_Ar|_old|\.svn|\.git|\.hg', 'once'));
        isClean = cellfun(isCleanFun, pathElements);

        % PRINT A NEW, CLEAN PATH
        cleanElements = pathElements(isClean);
        cleanPath = sprintf(['%s' pathsep()], cleanElements{:});
    end
    function prj=get_current()
        fname=mfilename;
        fdir=mfilename('fullpath');
        fdir=strrep(fdir,fname,'');

        fid=fopen([fdir '.current_project']);
        tline=fgets(fid);
        fclose(fid);

        prj=strtrim(strrep(tline,char(10),''));

    end
    function reset(bEcho)
        if ~exist('bEcho','var') || isempty(bEcho)
            bEcho = 1;
        end
        %^Reloads current or last open project
        prj=Px.get_current();
        Px(prj,[],0);
        if bEcho
            display(['Done reloading project ' prj '.']);
        end
    end
    function startup()
        if ismac
            Px('_0_');
        else
            Px(1);
        end
   end
    function p = gen_path(d)
        % String Adoption
        if nargin > 0
            d = convertStringsToChars(d);
        end

        if nargin==0,
            p = Px.gen_path(fullfile(matlabroot,'toolbox'));
        if length(p) > 1, p(end) = []; end % Remove trailing pathsep
            return
        end

        % initialise variables
        classsep = '@';  % qualifier for overloaded class directories
        packagesep = '+';  % qualifier for overloaded package directories
        p = '';           % path to be returned

        % Generate path based on given root directory
        if iscell(d)
            f=cellfun(@dir,d,'UniformOutput',false);
            files=vertcat(f{:});
            p=[p strjoin(d,pathsep) pathsep];
            bCell=1;
        else
            files = dir(d); % XXX BOTTLENECK
            p = [p d pathsep];
            bCell=0;
        end
        if isempty(files)
            return
        end

        % Add d to the path even if it is empty.

        % set logical vector for subdirectory entries in d
        isdir = logical(cat(1,files.isdir));
        %
        % Recursively descend through directories which are neither
        % private nor "class" directories.
        %
        dirs = files(isdir); % select only directory entries from the current listing
        dirs=dirs(3:end);

        if ~bCell
            for i=1:length(dirs)
                dirname = dirs(i).name;
                if ~strncmp( dirname,classsep,1) && ~strncmp( dirname,packagesep,1) && ~strcmp( dirname,'private') && isempty(regexp(dirname,'^(_Ar|_old|.svn|.git|.hg)'))
                    p = [p Px.gen_path([d filesep dirname])]; % recursive calling of this function.
                end
            end
        else
            lastdire='';
            for i=1:length(dirs)
                dirname = dirs(i).name;
                dire    = dirs(i).folder;
                if ~strcmp(dire,lastdire)
                    bAdd=~strcmp( dirname,'.') && ~strcmp( dirname,'..') && ~strncmp( dirname,classsep,1) && ~strncmp( dirname,packagesep,1) && ~strcmp( dirname,'private') && isempty(regexp(dirname,'^(_Ar|_old|.svn|.git|.hg)'));
                end
                if bAdd
                    for j = 1:length(d)
                        p = [p Px.gen_path([ dire filesep dirname]) ]; % recursive calling of this function
                    end
                end
                lastdire=dirname;
            end
        end
    end
    function p=get_default_path()

        if strncmp(computer,'PC',2)
            RESTOREDEFAULTPATH_perlPath = [matlabroot '\sys\perl\win32\bin\perl.exe'];
            RESTOREDEFAULTPATH_perlPathExists = exist(RESTOREDEFAULTPATH_perlPath,'file')==2;
        else
            [RESTOREDEFAULTPATH_status, RESTOREDEFAULTPATH_perlPath] = matlab.system.internal.executeCommand('which perl');
            RESTOREDEFAULTPATH_perlPathExists = RESTOREDEFAULTPATH_status==0;
            RESTOREDEFAULTPATH_perlPath = (regexprep(RESTOREDEFAULTPATH_perlPath,{'^\s*','\s*$'},'')); % deblank lead and trail
        end

        % If Perl exists, execute "getphlpaths.pl"
        if RESTOREDEFAULTPATH_perlPathExists
            RESTOREDEFAULTPATH_cmdString = sprintf('"%s" "%s" "%s"', ...
                RESTOREDEFAULTPATH_perlPath, which('getphlpaths.pl'), matlabroot);
            [RESTOREDEFAULTPATH_perlStat, RESTOREDEFAULTPATH_result] = matlab.system.internal.executeCommand(RESTOREDEFAULTPATH_cmdString);
        else
            error(message('MATLAB:restoredefaultpath:PerlNotFound'));
        end

        % Check for errors in shell command
        if (RESTOREDEFAULTPATH_perlStat ~= 0)
            error(message('MATLAB:restoredefaultpath:PerlError',RESTOREDEFAULTPATH_result,RESTOREDEFAULTPATH_cmdString));
        end

        % Check that we aren't about to set the MATLAB path to an empty string
        if isempty(RESTOREDEFAULTPATH_result)
            error(message('MATLAB:restoredefaultpath:EmptyPath'));
        end

        % Set the path, adding userpath if possible
        if exist( 'userpath.m', 'file' ) == 2
            p=[userpath ';' RESTOREDEFAULTPATH_result];
        else
            p=RESTOREDEFAULTPATH_result;
        end
    end
%% GIT
    function version = parse_version(version)
    end
    function direName=get_version_dire_name(version,site)
        %site__prj__versionORhash
        site=regexprep(site,'https*://','');
        site=regexprep(site,'\..*?/','/');
        if endsWith(site,'/')
            site=site(1:end-1);
        end
        direName=strrep(site,'/','__');
        if ~isempty('version')
            direName=[direName '@' version];
        end
    end
    function status=git_checkout(dire,version)
        %checkout -> into lib
        %dire stable -> lib
        oldDir=cd(dire);
        if isunix
            [~,msg]=unix(['git checkout ' version ' --quiet']);
        else
            [~,msg]=system(['git checkout ' version ' --quiet']);
        end
        cd(oldDir);
    end
    function status=git_clone(site,direName)
        out=Px.git_local_state(direName);
        if out==1
            'out equals 1'
            % TODO
        elseif out==2
            'out equals 2'
            % TODO
        elseif out==3
            origin=Px.git_get_origin(direName);
            if ~strcmp(origin,site)
               % TODO
               'origin does not match site'
            end
        end

        if out==0 && isunix
            [status,msg]=unix(['git clone -q ' site ' ' direName ]);
        elseif out==0
            [status,msg]=system(['git clone ' site ' ' direName ]);
        end
    end
    function hash=git_hash(dire)
        if exist('dire','var') && ~isempty(dire)
            oldDir=cd(dire);
            bRestore=1;
        else
            bRestore=0;
        end
        if isunix
            [~,hash]=unix('git rev-parse HEAD');
            hash=strsplit(hash,newline);
            hash(cellfun(@isempty,hash))=[];
            hash=branch{1};
        else
            [~,hash]=system('git rev-parse HEAD');
        end
        if bRestore
            cd(oldDir);
        end
    end
    function branc=git_get_branch(dire)
        if exist('dire','var') && ~isempty(dire)
            oldDir=cd(dire);
            bRestore=1;
        else
            bRestore=0;
        end
        if isunix
            [~,branch]=unix('git rev-parse --abbrev-ref HEAD');
            branch=strsplit(branch,newline);
            branch(cellfun(@isempty,branch))=[];
            branch=branch{1};
        else
            [~,branch]=system('git rev-parse --abbrev-ref HEAD');
        end
        if bRestore
            cd(oldDir);
        end
    end
    function origin=git_get_origin(dire)
        if exist('dire','var') && ~isempty(dire)
            oldDir=cd(dire);
            bRestore=1;
        else
            bRestore=0;
        end
        if isunix
            [~,origin]=unix('git config --get remote.origin.url');
            origin=strsplit(origin,newline);
            origin(cellfun(@isempty,origin))=[];
            origin=origin{1};
        else
            system('git config --get remote.origin.url');
        end
        if bRestore
            cd(oldDir);
        end
    end
    function [out]=git_local_state(direName)
        % 0 dire doesn't exist
        % 1 empty
        % 2 not empty with files, no .git
        % 3 has git
        if ~exist(direName,'dir')
            out=0;
        elseif ~exist([direName '.git'],'dir') && length(dir(dirName)) == 2
            out=1;
        elseif ~exist([direName '.git'],'dir') && length(dir(dirName)) > 2
            out=2;
        else
            out=3;
        end
    end

end
end
