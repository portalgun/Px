function [] = pxr(bEcho)

if ~exist('bEcho','var')        || isempty(bEcho)
    bEcho = 0;
end
%^Reloads current or last open project
prj=pxCur();
px(prj);
if bEcho
    disp(['Loaded project ' prj]);
end
