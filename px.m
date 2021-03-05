function varargout=px(prj,bStable,bVarsOnly)
%{

  ██▓███  ▒██   ██▒
 ▓██░  ██▒▒▒ █ █ ▒░
 ▓██░ ██▓▒░░  █   ░
 ▒██▄█▓▒ ▒ ░ █ █ ▒
 ▒██▒ ░  ░▒██▒ ▒██▒
 ▒▓▒░ ░  ░▒▒ ░ ░▓ ░
 ░▒ ░     ░░   ░▒ ░
 ░░        ░    ░
           ░    ░
% [rootPrjDir,rootStbDir,rootTlbxDir,rootHookDir]=px(prj,bStable,bVarsOnly)

 Project Switcher
    Manages your Matlab project paths dynamically and with ease
    Inspired by toolboxtoolbox

 example call:
           px
           (then return a number corresponding to a project)

 SETUP INSTRUCTIONS:
    1. PLACE BELOW IN YOUR STARTUP FILE
          pxPath='/some/path/to/this/file'
          run(pxPath)
    2. SET THESE VARIABLES BELOW
       rootPrjDir
          Specifies a directory where all your projects will be
       rootTlbxDir
          Specifies a directory where toolboxes are located
          Toolboxes will always load with all projects, but projects given priority

    Optional variables:
       rootStbDir
          Specifies a directory where all your projects will be
       rootHookDir
          Specifies a directory where project hooks are located
          To create a hook, create a .m file with the same name as the project directory

          Hook can be script or function. If function, can px will return one of its outputs as 'out'

     Set per project dependencies
          In project directory create .px file
          d:projectName - development
          s:projectName - stable
          e:toolboxName - exclude a particular toolbox
          eAll:

%}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rootWrkdir='~/Code/mat/workspaces/';
rootSWrkdir='~/Code/mat/stableWorkspaces/';
rootPrjDir ='~/Code/mat/projects/';
rootStbDir='~/Code/mat/stableProjects';
rootTlbxDir='~/Code/mat/toolboxes/';
rootHookDir='~/Code/mat/localHooks/';

rootWrkdir=strrep(rootWrkdir,'/',filesep);
rootSWrkdir=strrep(rootStbDir,'/',filesep);
rootPrjDir =strrep(rootPrjDir,'/',filesep);
rootStbDir=strrep(rootStbDir,'/',filesep);
rootTlbxDir=strrep(rootTlbxDir,'/',filesep);
rootHookDir=strrep(rootHookDir,'/',filesep);
if ispc
    % XXX should have some env variable for 'home', set it up if doesn't exist
    rootWrkdir=strrep(rootWrkdir,'~\Code\mat','E:\matenv');
    rootSWrkdir=strrep(rootStbDir,'~\Code\mat','E:\matenv');
    rootPrjDir =strrep(rootPrjDir,'~\Code','Y:');
    rootStbDir=strrep(rootStbDir,'~\Code','Y:');
    rootTlbxDir=strrep(rootTlbxDir,'~\Code','Y:');
    rootHookDir=strrep(rootHookDir,'~\Code','Y:');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rootPrjDir=filesepc(rootPrjDir);
rootTlbxDir=filesepc(rootTlbxDir);
rootStbDir=filesepc(rootStbDir);
rootHookDir=filesepc(rootHookDir);

if nargout > 0
    varargout{1} = rootPrjDir;
end
if nargout > 1
    varargout{2} = rootStbDir;
end
if nargout > 2
    varargout{3} = rootTlbxDir;
end
if nargout > 3
    varargout{4} = rootHookDir;
end

if exist('bVarsOnly') && bVarsOnly==1
    return
end

fname=mfilename;
fdir=mfilename('fullpath');
fdir=strrep(fdir,fname,'');
addpath(fdir);

if ~exist('bStable','var') || isempty(bStable)
    bStable=0;
end

stableflag=0;
if ~exist('prj','var') || isempty(prj)
    %GET ALL PROJECTS IN PROJECT DIRECTORY
    ignore={'_AR','AR'};
    if bStable
        prjs=pxGetProjects(rootStbDir);
    else
        prjs=pxGetProjects(rootPrjDir);
    end
    prjs(ismember(prjs,ignore))=[];
    sprjs=pxGetProjects(rootStbDir);
    sprjs(ismember(sprjs,ignore))=[];

    %DISPLAY PROJECTS
    disp([newline '  r last open project']);
    fprintf(['%3.0f Toolboxes Only' newline newline],0);
    fprintf(['%-31s %-25s' newline],'DEVELOPMENT','STABLE');
    for i = 1:length(prjs)
        if i > length(sprjs)
            fprintf(['%3.0f %-25s' newline],i,prjs{i});
        elseif i > length(prjs)
            fprintf(['    %-25s   %3.0f %-25s' newline],repmat(' ',1,25),i+length(prjs),sprjs{i});
        else
            fprintf(['%3.0f %-25s   %3.0f %-25s' newline],i,prjs{i},i+length(prjs),sprjs{i});
        end
    end

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
        elseif resp > length(prjs) && resp <= (length(prjs) + length(sprjs))
            stableflag=1;
            break
        elseif resp > length(prjs)
            disp('Invalid response')
            continue
        elseif resp < 1
            disp('Invalid response')
            continue
        end
        break
    end
    if resp==0
        prj='_0_';
    elseif stableflag==1
        prj=sprjs{resp-length(prjs)};
    else
        prj=prjs{resp};
    end
    if stableflag==1
        cmd=['echo s:' prj ' > ' fdir '.current_project'];
    else
        cmd=['echo ' prj ' > ' fdir '.current_project'];
    end
    system(cmd);
end

if startsWith(prj,'s:') || bStable
    stableflag=1;
    prj=strrep(prj,'s:','');
end

%RESET
restoredefaultpath

%ADD THIS PATH
addpath(fdir);

%Read config and link dependencies
pxs(prj,stableflag,rootPrjDir,rootStbDir,rootTlbxDir,rootWrkdir,rootSWrkdir);

%ADD PRJ
if stableflag==1 && ~strcmp(prj,'_0_')
    pxAddToPath([rootSWrkdir prj]);
elseif ~strcmp(prj,'_0_')
    pxAddToPath([rootWrkdir prj]);
end

%GETTOOLBOXES
tlbxs=pxGetProjects(rootTlbxDir,1);

%ADD DEPENDENCIES/REMOVE EXLUDED TOOLBOXES
% XXX
%tlbxs = parseSettings(prj,rootPrjDir,rootStbDir,tlbxs)

%ADD TOOLBOXES IF NOT ADDED ALREADY, UNLESS EXCLUDED
for i = 1:length(tlbxs)
    if ~strcmp(prj,tlbxs{i})
        pxAddToPath([rootTlbxDir tlbxs{i}]);
    end
end

%CHANGE DIRECTORY TO PROJECT DIRECTORY
if stableflag==1 && ~strcmp(prj,'_0_')
    cd([rootStbDir prj]);
elseif ~strcmp(prj,'_0_')
    cd([rootPrjDir prj]);
end

%RUN HOOKS IF ANY
if exist([rootHookDir prj '.m'])==2
    old=cd(rootHookDir);

    %CHECK WHETHER HOOK IS SCRIPT OR FUNCTION WITH OUTPUT
    fid = fopen([prj '.m'],'r');
    line=fgetl(fid);
    fclose(fid);
    try
        %check if function
        str=['^function *= *' prj '\({0,1}\){0,1}$'];
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

disp('Done.')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out=pxGetProjects(rootPrjDir,accept)
    if ~exist('accept','var') || isempty(accept)
        accept=0;
    end
% GET ALL PROJECTS IN PROJECT DIRECTORY
    folder=dir(rootPrjDir);
    ind=[folder.isdir]';
    f={folder.name}';
    folders=f(ind);
    out=cell2mat(cellfun( @(x) isempty(regexp(x,'^\.')),folders,'UniformOutput',false)');
    out=folders(out)';
    if ~accept
        ind=startsWith(out,'_');
        out(ind)=[];
    end
end

function oldPath=pxAddToPath(rootFolder)
% ADD DIRECTORIES AND SUBDIRECTORIES TO PATH CLEANLY
    allFolders = genpath(rootFolder);
    %allFolders
    try
        cleanFolders = pxCleanPath(allFolders);
        oldPath = addpath(cleanFolders, '-end');
    catch
        warning('Problem adding path. Likley a borken sym link.')
    end
end

function cleanPath = pxCleanPath(originalPath)
% CLEANUP A GENERATED PATH

    % BREAK THE PATH INTO SEPARATE ENTRIES
    scanResults = textscan(originalPath, '%s', 'delimiter', pathsep());
    pathElements = scanResults{1};

    % LOCATE SVN, GIT, MERCURIAL ENTRIES
    isCleanFun = @(s) isempty(regexp(s, '\.svn|\.git|\.hg', 'once'));
    isClean = cellfun(isCleanFun, pathElements);

    % PRINT A NEW, CLEAN PATH
    cleanElements = pathElements(isClean);
    cleanPath = sprintf(['%s' pathsep()], cleanElements{:});
end

function tlbxs = parseSettings(prj,rootPrjDir,rootStbDir,tlbxs)
    settingsFile=[prj filesep '.px'];
    if ~exist(settingsFile,'file')
        % XXX make settings file
        return
    end
    fid=fopen(settingsFile)
    while ischar(tline)
        tline=strtrim(fgetl(fid));
        if startsWith(tline,'stb:')
            bStable=1;
            dep=strtrim(strrep(tline,'stb:',''));
        elseif startsWith(tline,'excALL:')
            tlbxs={};
        elseif startsWith(tline,'exc:') && ~isempty(tlbxs)
            tlbx=strtrim(strrep(tline,'stb:',''));
            tlbxs(contains(tlbxs,tlbx))=[];
            continue
        else
            bStable=0;
            dep=tline;
        end

        if bStable
            prjSrc=[rootPrjDir dep];
        elseif  bStable
            prjSrc=[rootStbDir dep];
        end
        prjDst=[prj fielsep lib filesep dep];

        if ~exist(prjDst,'dir')
        if ispc
            % XXX need to give user permissions
            [~,n]=fileparts(origin);
            cmd=['mklink /d ' destination n ' ' origin];
        else
            cmd=['ln -s ' prjSrc ' ' prjDst ];
            end
            system(cmd);
        end
    end
    fclose(fid);
end

function dire=filesepc(dire)
%function dire=filesepc(dire)
%adds filesep to end if it doesn't already exist
   if ~strcmp(dire(end),filesep)
       dire=[dire filesep];
   elseif strcmp(dire(end),filesep) && strcmp(dire(end-1),filesep)
       dire=dire(1:end-1);
   end
end
