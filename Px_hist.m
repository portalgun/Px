classdef Px_hist < handle
methods
    function obj=make_history(obj)
        obj.save_history();
        %/home/dambam/.matlab/java/jar/mlservices.jar
        %% MAKE history files
        prjdir=obj.prjDir;
        mdir=Dir.parse(prefdir);

        names={'history.m','History.xml','History.bak'};
        % History.xml = desktop command history

        for i = 1:length(names)
            history_fun(names{i},prjdir,mdir,obj.home);
        end

        obj.reload_history();

        function history_fun(name,prjdir,mdir,home)
            pHist=[prjdir '.' name];
            mHist=[mdir name];
            prjdir
            if ~exist(mHist,'file') && ~exist(pHist,'file') % XXX SLOW 1
                error(['History file ' name ' does not exist']);
            end
            if ~exist(pHist,'file') % XXX SLOW 5
                Fil.touch(pHist);
            end
            if exist(mHist,'file')
                bSym=FilDir.isLink(mHist); % XXX SLOW 3
                if bSym && strcmp(FilDir.readLink(mHist),pHist); % XXX SLOW 2
                    return
                elseif bSym
                    delete(mHist);
                else
                    movefile(mHist,[mHist '_bak']);
                end
            end

            Px.LN_fun(pHist,mHist,0,home); % XXX SLOW 4

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
        mdir=Dir.parse(prefdir);
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
end
end
