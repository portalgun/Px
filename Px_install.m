classdef Px_install < handle
methods
    function out=get_install_status(obj)
        out=logical(exist([obj.selfPath '.installed']));
    end
    function obj=reinstall_px(obj,varargin)
        installLoc=varargin{1};
        if ~endsWith(installLoc,filesep)
            installLoc=[installLoc filesep];
        end
        if ~exist(installLoc,'dir')
            error(['Install path ' installLoc '  does not exist']);
        end

        if logical(exist([installLoc '.installed']));
            error(['Px not installed at ' installLoc ]);
        end
        obj.root=[installLoc '.px' filesep 'boot' filesep];

        Px_install.rm_rf([obj.root 'MatBaseTools']);
        Px_install.rm_rf(obj.root);

        %% UNLINK PRJ
        if length(varargin) > 1
            prjLoc=varargin{2};
        else
            prjLoc=[];
        end
        if ~endsWith(prjLoc,filesep)
            prjLoc=[prjLoc filesep];
        end
        %Px_install.unlink(prjLoc); XXX


        %% INSTALL
        obj.install_px(varargin{:});


    end
    function obj=install_px(obj,varargin);
        old=path;
        assignin('base','oldPath','path');
        bComplete=false;
        %cl=onCleanup(@() Px_install.restore_path(bComplete,old));

        % XXX TODO SAVE OLDPATH
        restoredefaultpath;
        if length(varargin) == 0
            error('Px Install: install destination directory required for first parameter');
        end
        installLoc=varargin{1};

        if length(varargin) > 1
            prjLoc=varargin{2};
        else
            prjLoc=[];
        end
        if ~endsWith(prjLoc,filesep)
            prjLoc=[prjLoc filesep];
        end

        if length(varargin) > 2
            opts=struct(varargin{3:end});
        else
            opts=struct();
        end

        if ~endsWith(installLoc,filesep)
            installLoc=[installLoc filesep];
        end
        rootpar=obj.parent(installLoc);
        if ~exist(rootpar,'dir')
            error(['Install location ' rootpar ' does not exist. Manually make this directory if this is intentional.']);
        end
        if ~isempty(prjLoc) && ~exist(prjLoc,'dir')
            error(['Existing project location ' prjLoc ' does not exist. Manually make this directory fi this is intentional.']);
        elseif ~isempty(prjLoc)
            obj.linkPrj=prjLoc;
        end

        obj.parse_installPx(opts);
        obj.root=[installLoc '.px' filesep];

        obj.move_self();
        out=obj.find_install_config();
        if out
            obj.copy_config();
        end
        old=cd(obj.selfPath);
        %cl=onCleanup(@() cd(old));
        %obj.setup_base_tools();

        obj.handle_startup();
        %Px('install2',obj.selfPath,obj.root,obj.rootconfig,obj.linkPrj);

        fclose(fopen([obj.selfPath '.installed'], 'w'));
        bComplete=true;

        cd(obj.root);

        clear Px Px_install Px_util;
        rehash path;
        obj.setup_base_tools();

        clear Px Px_install Px_util;
        rehash path;

        disp('New path applied. Old path assigned to your workspace as ''oldPath''');
        disp('Run ''clear Px Px_install Px_util Px_git startup; startup''')
        %cd(obj.selfPath);
        %Px.startup();
    end
    function handle_startup(obj)
        text=['cd ' obj.selfPath '; Px.startup;'];

        fname=which('startup');
        if ~isempty(fname) && Px_install.file_contains(fname,text);
            return
        elseif ~isempty(fname)
            dir=fileparts(fname);
        end
        if ~isempty(fname) &&  contains(dir,matlabroot)
            fname=[userpath filesep 'startup.m'];
            fid = fopen(fname, 'w');
        else
            fid = fopen(fname, 'a');
        end
        cl=onCleanup(@() fclose(fid));
        fprintf(fid, '%s', text);


    end
    function opts=parse_installPx(obj,opts)
        % TODO
    end
    function out=find_install_config(obj,opts)
        out=false;
        fname=[obj.selfPath 'Px.config'];
        if exist(fname,'file')
            obj.rootconfig=fname;
            out=true;
        end
    end
    function obj=copy_config(obj)
        etc=[obj.root 'etc' filesep];
        if ~exist(etc,'dir')
            mkdir(etc);
        end
        dest=[etc 'Px.config'];
        copyfile(obj.rootconfig, dest);
        obj.rootconfig=dest;
    end
    function obj=move_self(obj)
        if ~exist(obj.root,'dir')
            mkdir(obj.root);
        end
        dest=[obj.root 'boot' filesep];
        copyfile(obj.selfPath,dest);
        obj.selfPath=dest;
    end
end
methods(Static, Access=private)
    function out=file_contains(fname,text)
        lines=Px_install.cell(fname);
        if isempty(lines)
            out=false;
            return
        end
        out=ismember(text,lines);
    end
    function lines=cell(fname)
        fid = fopen(fname);
        if fid==-1
            lines=[];
            return
        end
        cl=onCleanup(@() fclose(fid));
        tline = fgetl(fid);
        lines={};
        while ischar(tline)
            lines{end+1}=tline;
            tline = fgetl(fid);
        end
    end
    function restore_path(bComplete,oldPath)
        if ~bComplete
            path(oldPath);
        end
    end
%% DIRS
    function out=dir_isempty(dire)
        %if ~endsWith(dire,filesep)
        %    dire=[dire fiesep];
        %end
        dirs=dir(dire);
        out=numel(dirs) == 2;
    end
    function out=rm_rf(dire)
        if ~exist(dire,'dir')
            return
        end
        if ~endsWith(dire,filesep)
            dire=[dire filesep];
        end
        if exist(dire,'file') && exist(dire,'file')~=7
            delete(dire);
            return
        elseif Px_install.isLinkCmd(dire)
            Px_install.unlink(dire);
            return
        elseif ~exist(dire,'dir')
            error(['File/directory ' dire ' does not exist.']);
        end

        dirs=Px_install.find(dire,'.*',[],'d');
        %text=[ 'Remove the following directories and their contents from directory ' dire '?' newline strjoin(dirs,newline) newline];
        %r=Px_install.yn(text);
        %if ~r
        %    return
        %end
        files=Px_install.find(dire,'.*',[],'f');
        for i = 1:length(files)
            delete([dire files{i}]);
        end
        dirs=strcat(dire,dirs);
        while true
            ind=cellfun(@Px_install.dir_isempty,dirs);
            if sum(ind) == 0
                break
            end
            dirse=dirs(ind);
            for i =1:length(dirse)
                rmdir(dirse{i});
            end
        end
    end
%% NON-COMPILED SYS CODE
%% LN
    %%
    function out = yn(question)
        while true
            resp=input([question ' (y/n): '],'s');
            switch Px_install.valYN(resp)
                case 1
                    out=1;
                    break
                case 0
                    out=0;
                    break
                otherwise
                    disp('Invalid response.')
            end
        end
    end
    function unlink(thing)
        if ~Px_install.isLinkCmd(thing)
            error(['File/directory ' thing ' is not a link.']);
        else
            % XXX need to test
            delete(thing);
        end
    end
    function bSuccess=ln(origin,destination)
        if isunix
            bSuccess=FilDir.lnUnix_(origin,desitination);
        else
            error('unhandled OS');
        end
    end

    function bSuccess=relink(origin,destination);
        Px_install.unlink(destination);
        Px_install.ln(destination);
    end
    function lnUnix_(origin,destination)
        %ln(origin,destination)
        %create symbolic links
        cmd=['ln -s ' origin ' ' destination];
        [~,bSuccess]=Sys.run(cmd);
    end
    function out= isLinkCmd(dire)
        if ispc
            cmd=['powershell -Command "((get-item ' dire ' -Force -ea SilentlyContinue).Attributes.ToString())"'];
            [~,out]=system(cmd);
            out=strrep(out,newline,'');
            out=contains(out,'ReparsePoint');
        %elseif Sys.islinux
        %    out=issymlink(dire);
        else
            out=~unix(['test -L ' dire]);
        end
    end
%% FIND
    function Out = valYN(response)
        %simple function to handle input yes no responses
        if strcmp(response,'y') || strcmp(response,'Y') || strcmp(response,'Yes') || strcmp(response,'yes')  || strcmp(response,'YES') || strcmp(response,'1')
            Out=1;
        elseif strcmp(response,'n') || strcmp(response,'N') || strcmp(response,'No') || strcmp(response,'no') || strcmp(response,'NO') || strcmp(response,'0')
            Out=0;
        elseif strcmp(response,'')
            Out=2;
        else
            Out=-1;
        end
    end
    function out = find(dire,re,depth,ftype)
        if ~exist('depth','var')
            depth=[];
        end
        if ~exist('ftype','var')
            ftype=[];
        end
        if isunix()
            out=Px_install.findUnix_(dire,re,depth,ftype);
        else
            error('unhandled os');
        end
    end
    function out=findUnix_(dire,re,depth,ftype);
        if ~exist('dire','var') || isempty(dire)
            dire=pwd;
        end
        bFd=false;
        if exist('depth','var') && ~isempty(depth) && bFd
            depthStr=['--maxdepth ' num2str(depth) ' '];
        elseif exist('depth','var') && ~isempty(depth)
            depthStr=['-maxdepth ' num2str(depth) ' '];
        else
            depthStr='';
        end
        if ~exist('ftype','var') || isempty(ftype)
            typeStr='';
        elseif ismember(ftype,{'f','d'}) && bFd
            typeStr=['--type ' ftype ' '];
        elseif ismember(ftype,{'f','d'})
            typeStr=['-type ' ftype ' '];
        elseif ~ismember(ftype,{'f','d'})
            error('Invalid type. Must be "f" or "d"');
        end
        if dire(end) ~= filesep
            dire=[dire filesep];
        end
        if bFd
            cmd=['fd --color never ' depthStr typeStr  '--regex "' re  '" --base-directory ' dire];
        else
            %cmd=['find ' dire '  -regextype egrep ' depthStr typeStr '-regex ".*' filesep re '" -printf "%P\n" | cut -f 1 -d "."' ];
            cmd2=['find ' dire '  -regextype egrep ' depthStr typeStr '-regex ".*' filesep re '"' ];
        end
        %[~,out]=unix(cmd);
        [~,out2]=unix(cmd2);
        out=strrep(out2,dire,'');
        if ~isempty(out);
            out(end)=[];
            out=strsplit(out,newline);
        end
        out=transpose(out);
    end

end
end
