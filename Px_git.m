classdef Px_git < handle
methods(Static)
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
            cmd=['git clone -q ' site ' ' direName ];
            [status,msg]=unix(cmd);
        elseif out==0
            cmd=['git clone ' site ' ' direName ];
            [status,msg]=system(cmd);
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
    function branch=git_get_branch(dire)
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
