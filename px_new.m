%git rev-parse HEAD
    function tlbxs = parseSettings(prj,rootPrjDir,rootStbDir,tlbxs)
        settingsFile=[prj filesep '.px'];
        if ~exist(settingsFile,'file')
            % XXX make settings file
            return
        end
        fid=fopen(settingsFile);
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
