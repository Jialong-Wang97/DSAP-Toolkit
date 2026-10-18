function [view,timing]=dsap_show_results(r,output_dir,view,visibility,owner)
% Present computed results before saving. No export or scientific calculation.
% Pass the returned view to update this result; unrelated patient windows stay.
    if nargin<3||isempty(view),view=struct();end
    if nargin<4,visibility=get(groot,'DefaultFigureVisible');end
    started=tic;
    [view,prepare_seconds]=dsap_prepare_critical_view(size(r.CBF),view);
    if nargin>=5,dsap_result_owner('attach',owner,view);end
    timing.UIPrepareSeconds=prepare_seconds;
    dsap_update_critical_view(view,r,output_dir,visibility);
    timing.CriticalVisibleSeconds=toc(started);
    timing.MapsPreparedSeconds=timing.CriticalVisibleSeconds;
    [view,timing.Auxiliary]=dsap_show_auxiliary_results(r,view,visibility);
    dsap_result_save_status(view,'pending');
    drawnow;
    timing.AllResultsPreparedSeconds=toc(started);timing.Visibility=visibility;
    timing.AllResultsVisibleSeconds=NaN;
    if strcmp(visibility,'on'),timing.AllResultsVisibleSeconds=timing.AllResultsPreparedSeconds;end
end

function value=member(s,name)
    value=[];if isfield(s,name),value=s.(name);end
end
