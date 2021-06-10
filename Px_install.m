classdef Px_install < handle
methods
    function out=get_install_status(obj)
        out=logical(exist([obj.selfPath '.installed']));
    end
    function obj=install_px(obj,varargin);
        old=path;
        assignin('base','oldPath','path');
        bComplete=false;
        cl=onCleanup(@() Px_install.restore_path(bComplete,old));


        % XXX TODO SAVE OLDPATH

        restoredefaultpath;
        if length(varargin) == 0
            error('Px Install: directory required for first parameter');
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
        cl=onCleanup(@() cd(old));
        obj.setup_base_tools();

        obj.handle_startup();
        %Px('install2',obj.selfPath,obj.root,obj.rootconfig,obj.linkPrj);

        fclose(fopen([obj.selfPath '.installed'], 'w'));
        bComplete=true;

        disp('New path applied. Old path assigned to your workspace as ''oldPath''');
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

end
end
