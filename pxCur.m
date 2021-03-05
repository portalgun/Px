function prj=pxCur()
    fname=mfilename;
    fdir=mfilename('fullpath');
    fdir=strrep(fdir,fname,'');

    fid=fopen([fdir '.current_project']);
    tline=fgets(fid);
    fclose(fid);

    prj=strtrim(strrep(tline,char(10),''));
end
