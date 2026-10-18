function dsap_save_core(folder,result)
% Minimal recoverable result set. No graphics or image files are produced.
    if ~isfolder(folder),mkdir(folder);end
    analysis_complete=false;core_save_state='saving';
    save(fullfile(folder,'analysis_status.mat'),'analysis_complete','core_save_state');
    pending=[tempname(folder) '.mat'];
    cleanup=onCleanup(@() delete_pending(pending)); %#ok<NASGU>
    try
        save(pending,'-struct','result','-v7');
        [ok,message]=movefile(pending,fullfile(folder,'interactive_perfusion_results.mat'),'f');
        assert(ok,'DSAP:CoreSaveFailed','%s',message);
        dsap_export_parameter_tables(folder,result);
        writetable(struct2table(result.cranial_limits),fullfile(folder,'manual_cranial_limits.csv'));
        dsap_write_curve_tables(folder,result.roi_names,result.original_time_seconds,result.time_seconds, ...
            result.native_original_aif_curve,result.original_aif_curve,result.aif_curve, ...
            result.native_original_roi_tics,result.original_roi_tics,result.roi_tics,result.roi_irfs);
        analysis_complete=true;core_save_state='complete';
        save(fullfile(folder,'analysis_status.mat'),'analysis_complete','core_save_state');
    catch exception
        analysis_complete=false;core_save_state='failed';core_save_error=exception.message;
        save(fullfile(folder,'analysis_status.mat'),'analysis_complete','core_save_state','core_save_error');
        rethrow(exception);
    end
end
function delete_pending(path)
    if isfile(path),delete(path);end
end
