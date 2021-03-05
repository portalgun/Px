classdef Px < handle
properties
    root
    %root='~/Code/mat/'
    rootWrkdir ='workspaces'
    rootSWrkdir='stableWorkspaces'
    rootPrjDir ='projects'
    rootStbDir ='stableProjects'
    rootTlbxDir='toolboxes'
    rootHookDir='localHooks'

    ignoreDirs={'AR','_AR','_old','.git'}

    prjs
    sprjs
    prj

    Options
end
properties(Hidden)
    selfpath
    stableflag
    hostname
end
methods
    function obj=Px(prj,bStable)
        if ~exist('bStable','var') || isempty(bStable)
            bStable=0;
        end
        obj.config=[obj.selfpath '_config_'];
        obj.hostname=Px.hostname();

        obj.get_root_dir();
        obj.get_dirs();
        obj.add_self_patch();

        if ~exist('prj','var') || isempty(prj)
            obj.get_prjs(bStable);
            obj.disp_prjs();
            obj.prompt_prjs();
        elseif  startsWith(prj,'s:')
            prj=strrep(prj,'s:','');
            obj.stableflag=1;
        end
        if bStable
            obj.stableflag=1;
        end

        obj.save_cur_prj();

        restoredefaultpath;
        obj.add_self_path();

        obj.get_prj_options();
        obj.make_wrk_dir();
        obj.parse_prj_options();

        if obj.stableflag==1 && ~strcmp(obj.prj,'_0_')
            Px.addToPath([obj.rootSWrkdir obj.prj]);
        elseif ~strcmp(prj,'_0_')
            Px.addToPath([obj.rootWrkdir obj.prj]);
        end

        %GETTOOLBOXES
        tlbxs=Px.getProjects(obj.rootTlbxDir,1);

        %ADD DEPENDENCIES/REMOVE EXLUDED TOOLBOXES
        % XXX
        %tlbxs = parseSettings(prj,rootPrjDir,rootStbDir,tlbxs)

        %ADD TOOLBOXES IF NOT ADDED ALREADY, UNLESS EXCLUDED
        for i = 1:length(tlbxs)
            if ~strcmp(prj,tlbxs{i})
               Px.addToPath([obj.rootTlbxDir obj.tlbxs{i}]);
            end
        end

        obj.cd_prj();
        obj.run_hooks();
        display('Done.')
    end
    function obj=get_root_dir(obj)
        fid = fopen(obj.config);
        while true
            line=fgetl(fid);
            if ~ischar(tline); break; end
            if regExp(line,'^[Rr]oot')
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
            filesepc(obj.root);
        end

    end
    function obj=get_paths()
    end
    function obj=add_self_path(obj)
        if isempty(obj.selfpath)
            fname=mfilename;
            fdir=mfilename('fullpath');
            obj.selfpath=strrep(fdir,fname,'');
        end
        addpath(obj.selfpath);
    end
    function obj=get_dirs(obj)
        if isempty(obj.rootWrkDir)
            obj.rootWrkdir ='workspaces';
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
             ,'rootWrkdir' ...
             ,'rootSWrkdir' ...
             ,'rootPrjDir' ...
             ,'rootStbDir' ...
             ,'rootTlbxDir' ...
             ,'rootHookDir' ...
        };
        for i = 1:length(prps)
            obj.(prps{i})=Pxr.filesepc(obj.(prps{i}));
            if ~startsWith(obj.(prps{i}), obj.root) && ~Px.regExp(obj.(prps{i}),'^([A-Z]:|/)')
                obj.(prps{i})=[obj.root obj.(prps{i})];
            end
        end

        if ispc
            % XXX MOVE
            obj.rootWrkdir=strrep(obj.rootWrkdir,'~\Code\mat','E:\matenv');
            obj.rootSWrkdir=strrep(obj.rootStbDir,'~\Code\mat','E:\matenv');
            obj.rootPrjDir =strrep(obj.rootPrjDir,'~\Code','Y:');
            obj.rootStbDir=strrep(obj.rootStbDir,'~\Code','Y:');
            obj.rootTlbxDir=strrep(obj.rootTlbxDir,'~\Code','Y:');
            obj.rootHookDir=strrep(obj.rootHookDir,'~\Code','Y:');

        end
    end
    function obj=get_prjs(obj,bStable)
        if bStable
            prjs=pxGetProjects(rootStbDir);
        else
            prjs=pxGetProjects(rootPrjDir);
        end
        obj.prjs(ismember(prjs,obj.ignoreDirs))=[];
        sprjs=pxGetProjects(obj.rootStbDir);
        obj.sprjs(ismember(sprjs,obj.ignoreDirs))=[];
    end
    function obj=disp_prjs(obj)
        disp([newline '  r last open project']);
        fprintf(['%3.0f Toolboxes Only' newline newline],0);
        fprintf(['%-31s %-25s' newline],'DEVELOPMENT','STABLE');
        for i = 1:length(prjs)
            if i > length(sprjs)
                fprintf(['%3.0f %-25s' newline],i, obj.prjs{i});
            elseif i > length(prjs)
                fprintf(['    %-25s   %3.0f %-25s' newline],repmat(' ',1,25),i+length(obj.prjs), obj.sprjs{i});
            else
                fprintf(['%3.0f %-25s   %3.0f %-25s' newline],i, obj.prjs{i},i+length(obj.prjs), obj.sprjs{i});
            end
        end
    end
    function obj=cd_prj(obj)
        %CHANGE DIRECTORY TO PROJECT DIRECTORY
        if stableflag==1 && ~strcmp(obj.prj,'_0_')
            cd([obj.rootStbDir obj.prj]);
        elseif ~strcmp(prj,'_0_')
            cd([obj.rootPrjDir obj.prj]);
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
        if stableflag==1
            cmd=['echo s:' obj.prj ' > ' obj.selfpath '.current_project'];
        else
            cmd=['echo ' obj.prj ' > ' obj.selfpath '.current_project'];
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
    function obj=get_prj_options()
        %function []=pxs(rootPrjDir,rootStbDir,rootTlbxDir)
        %px symbolic links - handle dependencies
        % TODO
        % check for recursion

        %get config file

        if ~exist(obj.config,'file')
            disp('No config file. Skipping.')
            return
        end

        fid=fopen(file);

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
            bNew=~regExp(tline,'^\s');

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
            if regExp(tline,'[^rR]oot:')
                bStart=0;
                return
            end
            bStart=1;
            [a,b]=strip_fun(tline); % a = s,d,e
            dest=sort_fun(a,b,obj.rootPrjDir,obj.rootStbDir);
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
            [a,b]=strip_fun(tline);
            dest=sort_fun(a,b,obj.rootPrjDir,obj.rootStbDir);
            if isempty(dest)
                return
            end
            obj.Options{end}{end+1}=dest;
        end
    end
    function obj=make_wrk_dir(obj)
        if obj.stableflag==1
            d=[obj.rootSWrkdir obj.prj filesep];
        else
            d=[obj.rootWrkdir obj.prj filesep];
        end
        if ~exist(d,'dir')
            mkdir(d);
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
                if ~exist([d name],'dir')
                    LN(s,d);
                else
                    bTest=0;
                    fixlinkifwrong([d name],s,bTest);
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
        elseif obj.Px.islinux
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
    function hn = hostname()
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
            islink=issymboliclink(dire);
        end
        if islink==0
            error([ 'Unexpected non-symbolic link at ' dire ]);
        end
        if ispc
            cmd=['powershell -Command "(Get-Item ' dire ').Target'];
            [~,src]=system(cmd);
                src=strrep(src,newline,'');
        else
            src=linksource(dire);
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
            gdSrc=linksource(gdSrc);
        end
        if ~bTest && ~strcmp(gdSrc,src)
            warning(['Fixing bad symlink ' src ' to ' gdSrc]);
            delete(dire);
            LN(gdSrc,dire);
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
        b=filesepc(b);
    end

    function dest=sort_fun(a,b,rootPrjDir,rootStbDir)
        switch a
            case 's'
                dest=[rootStbDir b];
            case 'd'
                dest=[rootPrjDir b];
            case 'e'
                [b,c]=strtok(b,':');
                c=c(2:end);
                if strcmp(obj.hostname,b)
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
        ind=tranpose([folder.isdir]);
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
        if ~exist('bEcho','var')        || isempty(bEcho)
            bEcho = 0;
        end
        %^Reloads current or last open project
        prj=Px.get_current();
        Px(prj);
        if bEcho
            display(['Loaded project ' prj]);
        end
    end
    function startup()
        if ismac
            Px('_0_');
        else
            Pxr(1);
        end
    end

end
end
