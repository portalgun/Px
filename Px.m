classdef Px < handle
properties
    root
    %root='~/Code/mat/'
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

    Options
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
        obj.get_self_path();
        obj.rootconfig=[obj.selfPath '.config'];
        if ~exist(obj.rootconfig,'file')
            obj.setup();
        end

        obj.get_root_configs();
        obj.get_dirs();
        addpath(obj.selfPath);
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

        restoredefaultpath;
        addpath(obj.selfPath);

        obj.get_prj_options();
        obj.make_wrk_dir();
        obj.parse_prj_options();


        Px.addToPath(obj.prjWDir);


        %GETTOOLBOXES
        obj.tlbxs=Px.getProjects(obj.rootTlbxDir,1);

        %ADD DEPENDENCIES/REMOVE EXLUDED TOOLBOXES
        % XXX
        %tlbxs = parseSettings(prj,rootPrjDir,rootStbDir,tlbxs)

        %ADD TOOLBOXES IF NOT ADDED ALREADY, UNLESS EXCLUDED
        for i = 1:length(obj.tlbxs)
            if ~strcmp(obj.prj,obj.tlbxs{i})
               Px.addToPath([obj.rootTlbxDir obj.tlbxs{i}]);
            end
        end

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
            if ~exist(mHist,'file')
                error(['History file ' name 'does not exist']);
            end
            if ~exist(pHist,'file')
                Px.touch(pHist);
            end
            bSym=Px.issymboliclink(mHist);
            if bSym && strcmp(Px.linksource(mHist),pHist);
                return
            elseif bSym
                delete(mHist);
            else
                movefile(mHist,[mHist '_bak']);
            end

            Px.LN(pHist,mHist);


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

        prps={ ...
             ,'rootWrkDir' ...
             ,'rootSWrkDir' ...
             ,'rootPrjDir' ...
             ,'rootStbDir' ...
             ,'rootTlbxDir' ...
             ,'rootHookDir' ...
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
        if obj.stableflag==1
            cmd=['echo s:' obj.prj ' > ' obj.selfPath '.current_project'];
        else
            cmd=['echo ' obj.prj ' > ' obj.selfPath '.current_project'];
        end
        system(cmd);
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
                out=eval([prj ';']);
            else
                eval([prj ';']);
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
            obj.Options{1}={obj.prjDir};
        elseif isempty(obj.Options) && obj.bEcho
            disp('Config entry does not exist. Skipping.')
            obj.Options{1}={obj.prjDir};
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
        obj.Options=cell(0);
        bStart=bPrjConfig; % Indicates valid header has been identified
        if bPrjConfig
            obj.Options{1}={obj.prjDir};
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
            dest=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.rootStbDir,obj.hostname);
            if isempty(dest)
                return
            end
            if isempty(obj.prj) || (strcmp(obj.prj,dire(1:end-1)) && ((obj.stableflag==1 && code=='s') || ((obj.stableflag==0 && code=='d'))))
                obj.Options{end+1}{1}=dest;
            else
                bStart=0;
            end
        end
        function obj=get_body(obj,tline)
            [code,dire,host,version]=Px.strip_fun(tline,Px.sep,obj.PRJS,obj.sprjs);
            dest=Px.sort_fun(code,dire,host,version,obj.rootPrjDir,obj.rootStbDir,obj.hostname);
            if isempty(dest)
                return
            end
            obj.Options{end}{end+1}=dest;
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
        obj.rm_removed_symlinks();
        obj.populate_wrk_dir();
    end
    function obj=rm_removed_symlinks(obj)
        if isempty(obj.Options)
            return
        end
        deps=obj.Options{1};
        deps=cellfun(@get_name_fun,deps,'UniformOutput',false);

        dirs=dir(obj.curWrk);
        name=transpose({dirs.name});
        full=join([transpose({dirs.folder}) name],filesep);
        ind=vertcat(dirs.isdir) & ~ismember(name,[{'.','..'}, deps]);
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
            O=obj.Options{i};
            m=O{1}; %main project directory
            if ~exist(m,'dir')
                disp(['Directory ' m ' does not exist']);
                continue
            end
            for j = 1:length(O)
                s=O{j}; %dependencies
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
                    Px.fix_link([obj.curWrk name],s,bTest);
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
    function out=rephome(in)
        if ~ispc()
            [~,home]=system('echo $HOME');
            home=strrep(home,newline,'');
        else
            home='Y:'; % XXX ADD TO CONFIG
        end
        out=strrep(in,'~',home);
    end
    function out= issymboliclink(dire)
        if ispc
            cmd=['powershell -Command "((Get-Item ' dire ' -Force -ea SilentlyContinue).Attributes)'] %;-band [IO.FileAttributes]::ReparsePoint)"'];
            [~,islink]=system(cmd);
            islink=strrep(islink,newline,'');
            out=strcmp(islink,'True');
        else
            out=~unix(['test -L ' dire]);
        end
    end
    function out = islinkbroken(dire)
        out=~unix(['[[ ! -e ' dire ' ]] && echo 1']);
    end

    function out =linksource(dire)
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
        [bS,out]=system(str);
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
        else
            cmd=['ln -s ' origin ' ' destination];
        end

        [bSuccess]=system(cmd);
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
        [~,hn]=system('hostname');
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
    function []=fix_link(dire,gdSrc,bTest)
        if ~exist('bTest','var') || isempty(bTest)
            bTest=0;
        end
        gdSrc=Px.rephome(gdSrc);

        islink=Px.issymboliclink(dire);
        if islink==0
            error([ 'Unexpected non-symbolic link at ' dire ]);
        end

        src=Px.linksource(dire);
        if isnan(src)
            error('Something went wrong');
        end

        if ~ispc
            gdSrc=Px.linksource(gdSrc);
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

    function dest=sort_fun(code,dire,host,version,rootPrjDir,rootStbDir,hostname)
        dest=[];
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
        end
        est=Px.filesepc(dest);
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

    function oldPath=addToPath(rootFolder)
    % ADD DIRECTORIES AND SUBDIRECTORIES TO PATH CLEANLY
        allFolders = genpath(rootFolder);
        %allFolders
        try
            cleanFolders = Px.cleanPath(allFolders);
            oldPath = addpath(cleanFolders, '-end');
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

end
end
