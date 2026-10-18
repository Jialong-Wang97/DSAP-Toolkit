function [folder,timing]=dsap_update_tissue_roi(request)
% Strict R1. There is deliberately no R2/full-workflow fallback here.
    started=tic;state=dsap_analysis_session('get');
    assert(~dsap_task_control('active'),'DSAP:AlreadyRunning','请等待当前分析完成。');
    dsap_analysis_session('lock');unlock=onCleanup(@() dsap_analysis_session('unlock')); %#ok<NASGU>
    assert(strcmp(state.CodeSignature,dsap_analysis_code_signature),'DSAP:CodeChanged','算法代码已改变，请重新完整分析。');
    [geometry,stats]=dsap_analysis_plan(state,request);nodes={'G','R'};r=state.Result;
    if isfield(geometry,'partition'),r.partition=geometry.partition;else,r.timeslice_import=geometry.timeslice_import;end
    if isfield(r,'roi_snapshot')
        if isfield(geometry,'partition'),definition=r.partition;else,definition=r.timeslice_import;end
        r.roi_snapshot=dsap_build_roi_snapshot(state.Source,r.aif_mask,r.cranial_limits, ...
            definition,r.roi_snapshot.Settings,r.roi_snapshot.Source);
    end
    r.partition_stats=stats;count=numel(stats.TICMasks);names=stats.Names;
    native=cell(count,1);enhanced=native;filtered=native;irfs=native;
    for k=1:count
        native{k}=mean(dsap_session_cache('samples',state.Cache,'native',stats.TICMasks{k}),2);
        enhanced{k}=mean(dsap_session_cache('samples',state.Cache,'enhanced',stats.TICMasks{k}),2);
        filtered{k}=mean(dsap_session_cache('samples',state.Cache,'filtered',stats.TICMasks{k}),2);
        irfs{k}=mean(dsap_session_cache('samples',state.Cache,'irf',stats.ParameterMasks{k}),2);
    end
    nodes{end+1}='C';
    if isfield(r,'partition')
        types={'ManualPartitionCortex';'ManualPartitionSubcortex';'Merged'};merged={'';'';'皮层 + 皮层下'};
    else
        types=repmat({'TIMESliceCurrentROI'},count,1);merged=repmat({''},count,1);
        if numel(r.timeslice_import.Masks)>1,types{end}='Merged';merged{end}=strjoin(r.timeslice_import.Names,' + ');end
    end
    summary=dsap_build_summary_table(names,stats.TICMasks,nan(count,1),types,merged, ...
        r.CBF,r.CBV,r.Tmax,r.MTT,r.volume_map,r.peak_map,r.ttp_map,r.intensity_map,irfs,r.time_seconds);
    vessels=r.vessel_roi_results;
    r.summary_table=[[summary stats.Coverage(:,2:end)];[vessels.Summary vessels.Coverage(:,2:end)]];
    r.roi_names=[names(:);vessels.Names];r.roi_types=[types;vessels.Types];r.roi_merge_sources=[merged;{'';''}];
    r.roi_frames=[nan(count,1);NaN;NaN];r.roi_masks=[stats.TICMasks;vessels.Masks];
    r.native_original_roi_tics=[native;vessels.NativeTIC];r.original_roi_tics=[enhanced;vessels.OriginalTIC];
    r.roi_tics=[filtered;vessels.TIC];r.roi_irfs=[irfs;vessels.IRF];r.settings.TissueROICount=count;
    if isfield(r,'vessel_inclusive'),r=dsap_vessel_inclusive_analysis(r);end
    r=dsap_attach_roi_distribution(r); % Finalized ROI revision invalidates derived distribution cache.
    r=dsap_roi_artery_analysis(r);
    nodes{end+1}='ST';
    revision=state.Revision+1;folder=fullfile(state.BaseFolder,sprintf('revision_%04d',revision));
    r.analysis_revision=struct('SessionId',state.Id,'Revision',revision,'SourceSHA256',state.Source.SHA256);
    candidate=state;candidate.Result=r;candidate.Revision=revision;candidate.OutputDirectory=folder;
    candidate.Status='unsaved';
    for name={'ROIMasks','Curves','Statistics','Presentation'}
        candidate.Nodes.(name{1}).Revision=revision;
        candidate.Nodes.(name{1}).Signature=dsap_analysis_signature({candidate.UpstreamSignature,name{1},revision});
    end
    % Publish before drawnow so reentrant/old callbacks can never use old data.
    dsap_analysis_session('publish',candidate,state.Id,state.Revision);
    dsap_bind_analysis_controls(candidate);
    dsap_workspace_distribution('close',state.View.Table);
    dsap_workspace_inclusive('close',state.View.Table);
    candidate.View=dsap_update_roi_views(r,state.View,folder);nodes{end+1}='UI';
    timing.EditToVisibleSeconds=toc(started);
    if ~strcmp(candidate.View.Table.Visible,'on'),timing.EditToVisibleSeconds=NaN;end
    timing.EditToPreparedSeconds=toc(started);save_started=tic;
    try
        dsap_save_core(folder,r);timing.CoreSaveSeconds=toc(save_started);nodes{end+1}='Core Save';
        candidate.SavedRevision=revision;candidate.Status='valid';
        dsap_analysis_session('publish',candidate,state.Id,revision);
        dsap_bind_analysis_controls(candidate);dsap_result_save_status(candidate.View,'saved');drawnow;
    catch exception
        dsap_result_save_status(candidate.View,'failed',exception.message);drawnow;rethrow(exception);
    end
    timing.TotalSeconds=toc(started);timing.ExecutedNodes=nodes;timing.CacheMode=state.Cache.Mode;
end
