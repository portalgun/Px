classdef Px < handle
properties
    root
    %root='~/Code/mat/'
    rootWrkDir
    rootSWrkdir
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
end
properties(Hidden)
    bEcho
    selfPath
    stableflag
    hostname
    curWrk
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

        obj.get_root_dir();
        obj.get_dirs();
        addpath(obj.selfPath);
        if ~isempty(prj) && (isnumeric(prj) || strcmp(prj,'_0_'))
            prj=Px.get_current();
        end

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
        obj.run_hooks();
        if obj.bEcho
            display('Done.')
        end
    end
    function obj=setup(obj)
    end
    function obj=get_root_dir(obj)
        fid = fopen(obj.rootconfig);
        while true
            line=fgetl(fid);
            if ~ischar(line); break; end
            if Px.regExp(line,'^[Rr]oot')
                spl=strsplit(line,':');
                spl(cellfun(@isempty,spl))=[];

                if length(spl) == 1
                    continue
                elseif length(spl) == 2 && exist(spl{2},'dir')
                    obj.root=spl{2};
                elseif length(spl) == 3 && strcmp(spl{2},obj.hostname) && exist(spl{3},'dir')
                    obj.root=spl{3};
                    break
                end
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
        if isempty(obj.rootSWrkdir)
            obj.rootSWrkdir='stableWorkspaces';
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
             ,'rootSWrkdir' ...
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
            obj.rootWrkDir=strrep(obj.rootWrkDir,'~\Code\mat','E:\matenv');
            obj.rootSWrkdir=strrep(obj.rootStbDir,'~\Code\mat','E:\matenv');
            obj.rootPrjDir =strrep(obj.rootPrjDir,'~\Code','Y:');
            obj.rootStbDir=strrep(obj.rootStbDir,'~\Code','Y:');
            obj.rootTlbxDir=strrep(obj.rootTlbxDir,'~\Code','Y:');
            obj.rootHookDir=strrep(obj.rootHookDir,'~\Code','Y:');

        end
    end
    function obj=get_prjs(obj,bStable)
        if bStable
            obj.prjs=Px.getProjects(obj.rootStbDir);
        else
            obj.prjs=Px.getProjects(obj.rootPrjDir);
        end
        obj.prjs(ismember(obj.prjs,obj.ignoreDirs))=[];
        obj.sprjs=Px.getProjects(obj.rootStbDir);
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
            obj.prjWDir=[obj.rootSWrkdir obj.prj filesep];
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
        bStart=0; % Indicates valid header has been identified
        while true
            tline=fgetl(fid);

            % BREAK IF COMPLETE
            if ~ischar(tline); break; end

            % SKIP EMPTY LIMES
            if isempty(tline); continue; end

            % No indents indicate new block
            bNew=~Px.regExp(tline,'^\s');

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
            [a,b]=Px.strip_fun(tline); % a = s,d,e
            dest=Px.sort_fun(a,b,obj.rootPrjDir,obj.rootStbDir,obj.hostname);
            if isempty(dest)
                return
            end
            if isempty(obj.prj) || (strcmp(obj.prj,b(1:end-1)) && ((obj.stableflag==1 && a=='s') || ((obj.stableflag==0 && a=='d'))))
                obj.Options{end+1}{1}=dest;
            else
                bStart=0;
            end
        end
        function obj=get_body(obj,tline)
            [a,b]=Px.strip_fun(tline);
            dest=Px.sort_fun(a,b,obj.rootPrjDir,obj.rootStbDir,obj.hostname);
            if isempty(dest)
                return
            end
            obj.Options{end}{end+1}=dest;
        end
    end
    function obj=make_wrk_dir(obj)
        if obj.stableflag==1
            obj.curWrk=[obj.rootSWrkdir obj.prj filesep];
        else
            obj.curWrk=[obj.rootWrkDir obj.prj filesep];
        end
        if ~exist(obj.curWrk,'dir')
            mkdir(obj.curWrk);
        end
    end

    function obj=parse_prj_options(obj)
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
                if ~exist([obj.curWrk name],'dir')
                    Px.LN(s,obj.curWrk);
                else
                    bTest=0;
                    Px.fixlinkifwrong([obj.curWrk name],s,bTest);
                end
            end
        end
    end
end
methods(Static,Access=private)
    function dire=filesepc(dire)
        %function dire=filesepc(dire)
        %adds filesep to end if it doesn't already exist
        strrep(dire,'/',filesep);
        if ~strcmp(dire(end),filesep)
            dire=[dire filesep];
        elseif strcmp(dire(end),filesep) && strcmp(dire(end-1),filesep)
            dire=dire(1:end-1);
        end
    end
    function out= issymboliclink(dire)
        out=~unix(['test -L ' dire]);
    end
    function out = islinkbroken(dire)
        out=~unix(['[[ ! -e ' dire ' ]] && echo 1']);
    end

    function out =linksource(dire)
        if ismac
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
            out=~cell2mat(cellfun( @(x) isempty(regexp(x,exp,'ignorecase')),cell,'UniformOutput',false)');
        else

            out=~cell2mat(cellfun( @(x) isempty(regexp(x,exp)),cell,'UniformOutput',false)');
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
    function []=fixlinkifwrong(dire,gdSrc,bTest)
        if ~exist('bTest','var') || isempty(bTest)
            bTest=0;
        end
        if ispc
            cmd=['powershell -Command "((get-item ' dire ').Attributes.ToString() -match """ReparsePoint"")"'];
            [~,islink]=system(cmd);
            islink=strrep(islink,newline,'');
            islink=strcmp(islink,'True');

        else
            islink=Px.issymboliclink(dire);
        end
        if islink==0
            error([ 'Unexpected non-symbolic link at ' dire ]);
        end
        if ispc
            cmd=['powershell -Command "(Get-Item ' dire ').Target'];
            [~,src]=system(cmd);
                src=strrep(src,newline,'');
        else
            src=Px.linksource(dire);
        end
        if isnan(src)
            error('Something went wrong');
        end
        if ~ispc()
            [~,home]=system('echo $HOME');
            home=strrep(home,newline,'');
        else
            home='Y:'; % XXX
        end
        gdSrc=strrep(gdSrc,'~',home);
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
    function [a,b]=strip_fun(tline)
        [a,b]=strtok(tline,':');
        a=a(end);
        b=b(2:end);
        b=Px.filesepc(b);
    end

    function dest=sort_fun(a,b,rootPrjDir,rootStbDir,hostname)
        switch a
            case 's'
                dest=[rootStbDir b];
            case 'd'
                dest=[rootPrjDir b];
            case 'e'
                [b,c]=strtok(b,':');
                c=c(2:end);
                if strcmp(hostname,b)
                    dest=c;
                else
                    dest=[];
                    return
                end
        end
        if ~strcmp(dest(end),filesep)
            dest=[dest filesep];
        end
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
