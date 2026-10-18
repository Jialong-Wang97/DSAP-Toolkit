function [view,timing]=dsap_show_auxiliary_results(r,view,visibility)
% Synchronous progressive presentation, after the critical render boundary.
    started=tic;cave_started=tic;dsap_cave_result_view(r,view);drawnow;
    cave_seconds=toc(cave_started);
    if isfield(view,'Workspace')
        [view,timing]=dsap_workspace_bridge('auxiliary',r);
        for field={'CurvesVisibleSeconds','VesselQCVisibleSeconds','AuxiliaryCompleteSeconds'}
            timing.(field{1})=timing.(field{1})+cave_seconds;
        end
        timing.CAVEResultsVisibleSeconds=cave_seconds;return;
    end
    view.Curves=dsap_curve_view(r,member(view,'Curves'));view.Curves.Visible=visibility;
    flush();timing.CurvesVisibleSeconds=toc(started);
    view.Vessels=dsap_vessel_view(r,member(view,'Vessels'));view.Vessels.Visible=visibility;
    flush();timing.VesselQCVisibleSeconds=toc(started);
    if isfield(r,'partition')
        view.Partition=dsap_partition_view(r,member(view,'Partition'));view.Partition.Visible=visibility;
        flush();
    elseif isfield(view,'Partition')&&isgraphics(view.Partition)
        view.Partition.Visible='off';
    end
    timing.AuxiliaryCompleteSeconds=toc(started);
    timing.CAVEResultsVisibleSeconds=cave_seconds;
    function flush
        if strcmp(visibility,'on')&&isgraphics(view.Perfusion),figure(view.Perfusion);end
        drawnow;
    end
end
function value=member(s,name)
    value=[];if isfield(s,name),value=s.(name);end
end
