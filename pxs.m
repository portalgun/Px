function []=pxs(prj,stableflag,rootPrjDir,rootStbDir,rootTlbxDir,rootWrkdir,rootSWrkdir)
%function []=pxs(rootPrjDir,rootStbDir,rootTlbxDir)
%px symbolic links - handle dependencies
% TODO
% check for recursion

%get config file
fname=mfilename('fullpath');
configdir=fileparts(fname);
configdir=filesepc(configdir);
file=[configdir '_config_'];

if ~exist(file,'file')
    disp('No config file. Skipping.')
    return
end

fid=fopen(file);
%Section into seperate configs & create full paths
Options=cell(0);
bStart=0;
while true
    tline=fgetl(fid);
    if ~ischar(tline)
        break
    end
    bNew=~regExp(tline,'^\s');
    if ~bNew && ~bStart
        continue
    elseif isempty(tline)
        continue
    elseif bNew %header
        bStart=1;
        [a,b]=strip_fun(tline); % a = s,d,e
        dest=sort_fun(a,b,rootPrjDir,rootStbDir);
        if isempty(dest)
            continue
        end
        if isempty(prj) || (strcmp(prj,b(1:end-1)) && ((stableflag==1 && a=='s') || ((stableflag==0 && a=='d'))))
            Options{end+1}{1}=dest;
        else
            bStart=0;
        end
    elseif ~bNew && bStart %body
        [a,b]=strip_fun(tline);
        dest=sort_fun(a,b,rootPrjDir,rootStbDir);
        if isempty(dest)
            continue
        end
        Options{end}{end+1}=dest;
    end
end
fclose(fid);

if stableflag==1
    d=[rootSWrkdir prj filesep];
else
    d=[rootWrkdir prj filesep];
end
if ~exist(d,'dir')
    mkdir(d);
end

%Make sure that projects in each exist, then symlink
for i=1:length(Options)
    O=Options{i};
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
% ---------------------------------
% FUNCTIONS


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

function dire=filesepc(dire)
 %function dire=filesepc(dire)
 %adds filesep to end if it doesn't already exist
    if ~strcmp(dire(end),filesep)
        dire=[dire filesep];
    elseif strcmp(dire(end),filesep) && strcmp(dire(end-1),filesep)
        dire=dire(1:end-1);
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
        disp(dire)
        disp(src)
        disp(gdSrc)
    end
end

%function
%    unix(['[[ -z $(find -L ' dire ' | grep 'loop detected) ]]'])
%end

function out= issymboliclink(dire)
    out=~unix(['test -L ' dire]);
end
function out = islinkbroken(dire)
    out=~unix(['[[ ! -e ' dire ' ]] && echo 1']);
end

function out =linksource(dire)
    if ismac
        str=['readlink ' dire];
    elseif islinux
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
        destination
        cmd
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
