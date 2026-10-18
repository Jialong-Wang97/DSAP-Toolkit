function dsap_full_export(folder)
% Explicit synchronous export from the recoverable Core Save snapshot.
% Never recomputes perfusion or changes the core completion status.
    assert(~dsap_task_control('active'),'DSAP:AlreadyRunning','请等待当前分析完成再导出。');
    assert(~isequal(getappdata(groot,'DSAPFullExportBusy'),true),'DSAP:AlreadyExporting','已有完整导出正在运行。');
    r=dsap_load_result(folder); % Reject partial Core Save before touching outputs.
    setappdata(groot,'DSAPFullExportBusy',true);
    release=onCleanup(@() setappdata(groot,'DSAPFullExportBusy',false)); %#ok<NASGU>
    dsap_task_control('begin',get(groot,'DefaultFigureVisible'));
    task=onCleanup(@() dsap_task_control('finish')); %#ok<NASGU>
    full_export_complete=false;full_export_state='exporting';
    save(fullfile(folder,'full_export_status.mat'),'full_export_complete','full_export_state');
    try
        dsap_task_control('check');
        imwrite(r.aif_mask,fullfile(folder,'AIF_mask.png'));
        imwrite(r.cranial_limit_mask,fullfile(folder,'manual_cranial_vertical_limits_mask.png'));
        imwrite(r.signal_valid_mask,fullfile(folder,'signal_valid_mask.png'));
        imwrite(r.valid_tissue_mask,fullfile(folder,'valid_enhancing_tissue_mask.png'));
        imwrite(r.large_vessel_mask,fullfile(folder,'large_vessel_mask.png'));
        if isfield(r.vessel_features,'RemovedSpeckleMask')
            imwrite(r.vessel_features.RemovedSpeckleMask,fullfile(folder,'removed_vessel_speckles.png'));
        end
        imwrite(r.capillary_mask,fullfile(folder,'capillary_tissue_mask.png'));
        for k=1:numel(r.roi_masks)
            dsap_task_control('check');
            name=regexprep(r.roi_names{k},'[^a-zA-Z0-9_-]','_');
            if isempty(name),name=sprintf('ROI_%d',k);end
            imwrite(r.roi_masks{k},fullfile(folder,sprintf('%02d_%s_mask.png',k,name)));
        end
        if isfield(r,'partition')
            dsap_export_partition(folder,r.reference_image,r.partition,r.partition_stats, ...
                r.large_vessel_mask,r.aif_mask,r.signal_quality_features);
        end
        if isfield(r,'timeslice_import')
            dsap_export_timeslice(folder,r.reference_image,r.timeslice_import,r.partition_stats,r.large_vessel_mask,r.aif_mask);
        end
        dsap_export_signal_quality(folder,r.reference_image,r.aif_mask,r.cranial_limit_mask,r.cranial_limits, ...
            r.signal_quality_features,r.large_vessel_mask,r.valid_tissue_mask,r.signal_quality_model);
        dsap_export_cave(folder,r.reference_image,r.vessel_model,r.vessel_features,r.large_vessel_mask);
        dsap_export_vessel_rois(folder,r.reference_image,r.vessel_roi_results,r.original_time_seconds,r.time_seconds);
        if ~isfield(r,'roi_distribution'),r=dsap_add_roi_distribution(r);end
        if ~isfield(r,'roi_artery'),r=dsap_roi_artery_analysis(r);end
        dsap_export_parameter_tables(folder,r);
        dsap_export_roi_distribution(folder,r,true);
        export_views(folder,r);
        dsap_task_control('check');
        full_export_complete=true;full_export_state='complete';
        save(fullfile(folder,'full_export_status.mat'),'full_export_complete','full_export_state');
    catch exception
        full_export_complete=false;full_export_state='failed';
        if strcmp(exception.identifier,'DSAP:Cancelled'),full_export_state='cancelled';end
        full_export_error=exception.message;
        save(fullfile(folder,'full_export_status.mat'),'full_export_complete','full_export_state','full_export_error');
        rethrow(exception);
    end
end

function export_views(folder,r)
    dsap_task_control('check');
    fig=dsap_vessel_view(r);cleanup=onCleanup(@() dsap_safe_delete(fig));
    exportgraphics(fig,fullfile(folder,'signal_and_vessel_removal_results.png'),'Resolution',200);
    clear cleanup;
    image=r.reference_image;image(~r.large_vessel_mask)=0;
    imwrite(mat2gray(image),fullfile(folder,'removed_large_vessels.png'));
    image=r.reference_image;image(~r.valid_tissue_mask)=0;
    imwrite(mat2gray(image),fullfile(folder,'valid_enhancing_tissue_dsa.png'));
    dsap_export_perfusion_maps(folder,r.reference_image,r.aif_mask,r.cranial_limits, ...
        r.valid_tissue_mask,r.large_vessel_mask,r.CBF,r.CBV,r.Tmax,r.MTT);
    dsap_task_control('check');
    fig=dsap_curve_view(r);cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    exportgraphics(fig,fullfile(folder,'ROI_curves.png'),'Resolution',200);
end
