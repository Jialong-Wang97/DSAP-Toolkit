function r=dsap_attach_roi_distribution(r)
% Optional downstream failure must not lose an otherwise valid perfusion result.
try
 r=dsap_add_roi_distribution(r);
catch e
 for name={'roi_distribution','distribution_summary_table'}
  if isfield(r,name{1}),r=rmfield(r,name{1});end
 end
 r.DistributionAnalysisStatus='failed';r.DistributionAnalysisError=struct('Identifier',e.identifier,'Message',e.message);
 warning('DSAP:DistributionFailed','ROI distribution unavailable: %s',e.message);
end
end
