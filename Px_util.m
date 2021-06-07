classdef Px_util < handle
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

    function prj=get_current()
        fname=mfilename;
        obj=Px('_INIT_ONLY_');

        fid=fopen([obj.curPrjLoc '.current_project']);
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
%% GENERAL
    function oldPath=add_path(pathlist,defpath)
        pathlist=unique(pathlist);

        dirs='';
        if Px.islinux()
            for i = 1:length(pathlist)
                dirs=[dirs Px.gen_path2(pathlist{i})];
            end
            dirs=dirs(1:end-1);
            dirs=[defpath pathsep dirs];
        else
            dirs=Px.gen_path(pathlist);
            dirs=[defpath pathsep dirs];
        end


        try
            %oldPath = addpath(dirs, '-end');
            oldPath = matlabpath(dirs);
        catch
            warning('Problem adding path. Likley a broken sym link.');
        end
    end
    function out = gen_path2(dir)
        if exist('dir','var') && ~isempty(dir)
            old=cd(dir);
        end
        cmd='find -L "$(pwd -P)" -type d -not -path ''*/\.git*'' -not -path ''*/\.svn*'' -not -path ''*/\_old*'' -not -path ''*/private*'' -not -path ''*/.ccls-cache*'' -not -path ''*/_AR*''';
        [~,out]=unix(cmd);
        out=strrep(out,newline,':');


        if exist('cd','var') && ~isempty(cd)
            cd(old);
        end
    end
    function p = gen_path(d)
        % String Adoption
        %try
        %    d = convertStringsToChars(d);
        %end

        if nargin==0,
            p = Px.gen_path(fullfile(matlabroot,'sbin'));
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
                if ~strncmp( dirname,classsep,1) && ~strncmp( dirname,packagesep,1) && ~strcmp( dirname,'private') && isempty(regexp(dirname,'^(_Ar|_old|\.svn|\.git|\.hg|^\.\.$)'))
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
        if isempty(which('matlab.system.internal.executeCommand'))
            bLegacy=1;
        else
            bLegacy=0;
        end

        if strncmp(computer,'PC',2)
            RESTOREDEFAULTPATH_perlPath = [matlabroot '\sys\perl\win32\bin\perl.exe'];
            RESTOREDEFAULTPATH_perlPathExists = exist(RESTOREDEFAULTPATH_perlPath,'file')==2;
        else
            if bLegacy
                [RESTOREDEFAULTPATH_status, RESTOREDEFAULTPATH_perlPath] = unix('which perl');
            else
                [RESTOREDEFAULTPATH_status, RESTOREDEFAULTPATH_perlPath] = matlab.system.internal.executeCommand('which perl');
            end

            RESTOREDEFAULTPATH_perlPathExists = RESTOREDEFAULTPATH_status==0;
            RESTOREDEFAULTPATH_perlPath = (regexprep(RESTOREDEFAULTPATH_perlPath,{'^\s*','\s*$'},'')); % deblank lead and trail
        end

        % If Perl exists, execute "getphlpaths.pl"
        if RESTOREDEFAULTPATH_perlPathExists
            RESTOREDEFAULTPATH_cmdString = sprintf('"%s" "%s" "%s"', ...
                RESTOREDEFAULTPATH_perlPath, which('getphlpaths.pl'), matlabroot);
            if bLegacy
                [RESTOREDEFAULTPATH_perlStat, RESTOREDEFAULTPATH_result] = unix(RESTOREDEFAULTPATH_cmdString);
            else
                [RESTOREDEFAULTPATH_perlStat, RESTOREDEFAULTPATH_result] = matlab.system.internal.executeCommand(RESTOREDEFAULTPATH_cmdString);
            end
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
end
methods(Static, Access={?Px,?Px_hist})
    function LN_fun(src,dest,bTest,home)
            if ~exist('bTest','var') || isempty(bTest)
                bTest=0;
            end

            if ~exist('home','var') || isempty(home)
                home=Px.get_home();
            end
            if endsWith(home,'/')
                home=home(1:end-1);
            end
            src=strrep(src,'~',home);

            % get source of source
            if ~ispc
                src=Px.getlinksource(src);
            end

            % LINK IF DOESNT EXIST
            bExist=exist(dest,'dir') || exist(dest,'file');
            if ~bExist
                Px.LN(src,dest);
                return
            end

            % ERROR IF DEST NOT SYMBOLIC
            bLink=Px.issymboliclink(dest);
            if ~bLink
                error([ 'Unexpected non-symbolic link at ' dest ]);
                return
            end

            % CHECK IF LINK IS BROKEN
            %bBroken=Px.islinkbroken(dest);
            %bBroken
            %33
            %dk
            %if bBroken
            %    delete(dest);
            %    Px.LN(src,dest);
            %    return
            %end

            % CHECK FIX IF EXISTING IS POINTING TO INCORRECT LOCATION
            trueSrc=Px.getlinksource(dest);
            if isnan(src)
                error('Something went wrong');
            end
            if ~bTest && ~strcmp(src,trueSrc)
                warning(['Fixing bad symlink ' trueSrc ' to ' src]);
                delete(dest);
                Px.LN(src,dest);
            elseif bTest
                disp(dire);
                disp(src);
                disp(src);
            end
    end
    function bSuccess=LN(origin,destination)
    %ln(origin,destination)
    %create symbolic links
        if ispc
            [~,name]=fileparts(origin);
            %destination = [ destination name ];
            %destination
            %if exist(destination,'file')
            %    bSuccess=1;
            %    return
            %end
            %cmd=['runas /user:administrator "mklink ' origin ' ' destination '"'];
            cmd=['mklink /d ' destination ' ' origin];
            [bSuccess,out]=system(cmd);
        else
            cmd=['ln -s ' origin ' ' destination];
            [bSuccess,out]=unix(cmd);
        end
        bSuccess=~bSuccess;
        if ~bSuccess
            out
            cmd
        end

    end
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
        if isunix()
            [~,home]=unix('echo $HOME');
            home=strrep(home,newline,'');
        else
            home='Y:'; % XXX ADD TO CONFIG
        end
    end
    function out= issymboliclink(dire)
        if ispc
            cmd=['powershell -Command "((get-item ' dire ' -Force -ea SilentlyContinue).Attributes.ToString())"'];
            [~,out]=system(cmd);
            out=strrep(out,newline,'');
            out=contains(out,'ReparsePoint');
        elseif Px.islinux
            out=issymlink(dire);
        else
            out=~unix(['test -L ' dire]);
        end
    end
    function out = islinkbroken(dire)
        if isunix
            cmd=['[[ ! -e ' dire ' ]] && echo 1'];
            out=~unix(cmd);
        elseif ispc
            cmd=['DIR \a ' dire];
            [bSuccess,out]=system(cmd);
        end
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
            out=readlink(dire);
            return
        end
        [bS,out]=unix(str);
        out=out(1:end-1);
        if (Px.islinux && bS==1) || (ismac && bS==1 && ~isempty(out))
            out=nan;
        elseif ismac && (ismac && bS==1 && isempty(out))
            out=dire;
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
    function out=touch(fname)
        out=fclose(fopen(fname,'w'));
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
end
end
