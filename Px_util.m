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
        obj=Px('get_current');

    end
    function reset(bEcho)
        Px('reset');
    end
    function installPx(varargin)
        Px('installPx',varargin{:});
    end
    function prj=get_config_dir()
        % XXX TODO
    end
    function prj=get_log_dir()
    end
    function prj=get_tmp_dir()
    end
    function prj=get_media_dir()
    end
    function refresh()
        % XXX TODO
        % rehash
        % get files changed?
    end
    function prj=recompile()
        % XXX TODO
        %
    end
    function startup()
        Px('startup');
    end
end
methods(Static, Hidden)
    function test_install()
        prj='~/Cloud/Code/mat/prj/';
        %prj=[userpath filesep 'myProjects'];;
        Px.installPx([userpath filesep],prj);
    end
end
methods(Static, Access={?Px,?Px_hist})
    function LN_fun(src,dest,bTest,home)
        if ~exist('bTest','var') || isempty(bTest)
            bTest=0;
        end

        if ~exist('home','var') || isempty(home)
            home=Dir.home();
        end
        if endsWith(home,'/')
            home=home(1:end-1);
        end
        src=strrep(src,'~',home);

        % get source of source
        if ~ispc
            src=FilDir.readLink(src);
        end

        % LINK IF DOESNT EXIST
        bExist=exist(dest,'dir') || exist(dest,'file');
        if ~bExist
            FilDir.ln(src,dest);
            return
        end

        % ERROR IF DEST NOT SYMBOLIC
        bLink=FilDir.isLink(dest);
        if ~bLink
            error([ 'Unexpected non-symbolic link at ' dest ]);
            return
        end

        % CHECK FIX IF EXISTING IS POINTING TO INCORRECT LOCATION
        trueSrc=FilDir.readLink(dest);
        if isnan(src)
            error('Something went wrong');
        end
        if ~bTest && ~strcmp(src,trueSrc)
            warning(['Fixing bad symlink ' trueSrc ' to ' src]);
            delete(dest);
            FilDir.ln(src,dest);
        elseif bTest
            disp(dire);
            disp(src);
            disp(src);
        end
    end
end
end
