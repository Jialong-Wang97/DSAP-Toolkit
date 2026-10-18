function r=dsap_add_roi_distribution(r,options)
% Recompute only after finalized maps/ROI revisions; cached result is persisted.
if nargin<2
 options=struct();if isfield(r,'DistributionAnalysisOptions'),options=r.DistributionAnalysisOptions;end
end
o=dsap_distribution_options(options);n=numel(r.roi_masks);parameters={'CBF','CBV','MTT','Tmax'};
assert(n==numel(r.roi_names)&&height(r.summary_table)==n,'DSAP:DistributionRows','ROI row alignment mismatch.');
pairs=o.ContralateralPairs;
assert(all(pairs<=n,'all')&&all(pairs(:,1)~=pairs(:,2))&&numel(unique(pairs(:,1)))==size(pairs,1),'DSAP:DistributionPairs','Pairs must specify unique affected rows and distinct existing references.');
metadata=repmat(struct('ROIIndex',0,'ID','','Name','','Side','Unknown','HomologyID','','PairSource','None','ReferenceROIIndex',NaN),n,1);
for k=1:n
 metadata(k).ROIIndex=k;metadata(k).ID=sprintf('ROI_%d',k);metadata(k).Name=r.roi_names{k};
 if isfield(r,'roi_snapshot')&&isfield(r.roi_snapshot,'StatisticsPlan')
  snap=r.roi_snapshot;plan=snap.StatisticsPlan;
  if k<=numel(plan.ROIIds)&&strcmp(plan.Names{k},r.roi_names{k})
   j=find(strcmp({snap.ROIs.ID},plan.ROIIds{k}));
   if numel(j)==1
    metadata(k).ID=snap.ROIs(j).ID;metadata(k).Side=snap.ROIs(j).Side;
    if isfield(snap.ROIs,'HomologyID'),metadata(k).HomologyID=snap.ROIs(j).HomologyID;end
   end
  end
 end
end
% Only explicit homology IDs + side labels, never ROI-name heuristics.
for k=1:n
 ref=[];provenance='None';given=find(pairs(:,1)==k);
 if ~isempty(given)
  ref=pairs(given,2);provenance='ExplicitOptionsPair';
 elseif strcmp(metadata(k).Side,'Affected')&&~isempty(metadata(k).HomologyID)
  ref=find(strcmp({metadata.Side},'Contralateral')&strcmp({metadata.HomologyID},metadata(k).HomologyID));
  if numel(ref)~=1,ref=[];else,provenance='SnapshotSideAndHomologyID';end
 end
 if ~isempty(ref),metadata(k).ReferenceROIIndex=ref;metadata(k).PairSource=provenance;end
end
rows=repmat(struct('Metadata',struct(),'CBF',struct(),'CBV',struct(),'MTT',struct(),'Tmax',struct()),n,1);
extra=table();
for k=1:n
 rows(k).Metadata=metadata(k);
 for j=1:numel(parameters)
  parameter=parameters{j};[map,mask,source]=dsap_distribution_roi_input(r,k,parameter);
  m=computeRoiDistributionMetrics(map,mask,o);m.QCFlags.UnavailableMapSource=startsWith(source,'Unavailable');
  if strcmp(parameter,'CBF')
   m.LowPerfusionFraction70=NaN;m.ContralateralCBFMedian=NaN;m.LowPerfusionThreshold=o.LowPerfusionThreshold;
   m.QCFlags.MissingContralateralReference=true;ref=metadata(k).ReferenceROIIndex;
   if isfinite(ref)
    [other,otherMask]=dsap_distribution_roi_input(r,ref,'CBF');x=double(other(otherMask&isfinite(other)));
    if ~isempty(x),m.ContralateralCBFMedian=median(x);end
    if isfinite(m.ContralateralCBFMedian)&&m.ContralateralCBFMedian>eps
     m.QCFlags.MissingContralateralReference=false;
     x=double(map(mask&isfinite(map)));if ~isempty(x),m.LowPerfusionFraction70=mean(x/m.ContralateralCBFMedian<o.LowPerfusionThreshold);end
    end
   end
   m.MissingContralateralReference=m.QCFlags.MissingContralateralReference;
  end
  rows(k).(parameter)=struct('Distribution',m,'MapSource',source);
  fields=fieldnames(m);
  for a=1:numel(fields)
   value=m.(fields{a});name=['Dist_' parameter '_' fields{a}];
   if (isnumeric(value)||islogical(value))&&isscalar(value)
    if ~ismember(name,extra.Properties.VariableNames),extra.(name)=nan(n,1);end
    extra.(name)(k)=double(value);
   end
  end
  flags=fieldnames(m.QCFlags);
  for a=1:numel(flags)
   name=['Dist_' parameter '_QC_' flags{a}];
   if ~ismember(name,extra.Properties.VariableNames),extra.(name)=false(n,1);end
   extra.(name)(k)=m.QCFlags.(flags{a});
  end
 end
end
extra.Dist_ROIIndex=(1:n)';extra.Dist_ROIID={metadata.ID}';extra.Dist_Side={metadata.Side}';
extra.Dist_ReferenceROIIndex=[metadata.ReferenceROIIndex]';extra.Dist_PairSource={metadata.PairSource}';
r.roi_distribution=rows;r.DistributionAnalysisOptions=o;
r.DistributionAnalysisMetadata=struct('Version','DSAP-ROI-distribution-v1', ...
 'Percentiles','midpoint empirical quantiles (k-0.5)/n, clamped endpoints', ...
 'ShapeMoments','population standardized central moments; Pearson kurtosis', ...
 'GLCM','symmetric, per-direction normalized, equal-weight finite-direction means', ...
 'Homogeneity','sum(P/(1+abs(i-j)))','LocalNeighbors','valid pixels including center', ...
 'Validity','existing parameter masks intersect finite final parameter map; no new physiological threshold', ...
 'LowPerfusionFraction70','legacy-stable field name; actual ratio cutoff stored in LowPerfusionThreshold', ...
 'TrimmedMean_05_95','default-named field; actual thresholds stored in DistributionAnalysisOptions');
r.distribution_summary_table=[r.summary_table extra];r.DistributionAnalysisStatus='complete';
if isfield(r,'DistributionAnalysisError'),r=rmfield(r,'DistributionAnalysisError');end
end
