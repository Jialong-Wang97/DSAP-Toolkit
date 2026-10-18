function dsap_export_parameter_tables(folder,r)
% Identical parameter output for Native, TIMESlice, and saved-result re-export.
if ~isfield(r,'roi_artery'),r=dsap_roi_artery_analysis(r);end
writetable(dsap_result_parameter_table(r),fullfile(folder,'ROI_perfusion_parameters.csv'));
if isfield(r,'roi_artery')
 writetable(r.roi_artery.Summary,fullfile(folder,'ROI_artery_parameters.csv'));
 roi_artery=r.roi_artery;
 save(fullfile(folder,'ROI_artery_results.mat'),'roi_artery');
end
if isfield(r,'vessel_inclusive')
 writetable(r.vessel_inclusive.Summary,fullfile(folder,'ROI_perfusion_with_vessels.csv'));
 writetable(r.vessel_inclusive.Comparison,fullfile(folder,'ROI_perfusion_vessel_comparison.csv'));
end
end
