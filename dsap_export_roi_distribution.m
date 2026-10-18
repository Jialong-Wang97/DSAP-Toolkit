function dsap_export_roi_distribution(folder,r,excel)
% Sidecar for legacy/on-demand results; original Core file is never changed here.
if nargin<3,excel=false;end
assert(isfield(r,'roi_distribution'),'DSAP:DistributionMissing','Calculate distribution before export.');
if ~isfolder(folder),mkdir(folder);end
writetable(r.distribution_summary_table,fullfile(folder,'ROI_distribution_parameters.csv'));
roi_distribution=r.roi_distribution;DistributionAnalysisOptions=r.DistributionAnalysisOptions;DistributionAnalysisMetadata=r.DistributionAnalysisMetadata; %#ok<NASGU>
save(fullfile(folder,'ROI_distribution.mat'),'roi_distribution','DistributionAnalysisOptions','DistributionAnalysisMetadata');
if excel,writetable(r.distribution_summary_table,fullfile(folder,'ROI_distribution_parameters.xlsx'),'UseExcel',false);end
end
