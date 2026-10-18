function r=dsap_vessel_inclusive_analysis(r,maps,valid)
% Paired ROI statistics from the SAME deconvolution, before vessel exclusion.
% No new AIF, fit, smoothing, floor or signal classification is performed.
if nargin<2
 assert(isfield(r,'vessel_inclusive'),'DSAP:InclusiveUnavailable','此历史结果未保存去血管前参数图；请在新版本中重新分析该病例。');
 old=r.vessel_inclusive;maps={old.CBF,old.CBV,old.Tmax,old.MTT};valid=old.DomainMask;
end
dsap_validate_roi_snapshot(r.roi_snapshot);
domain=r.brain_mask & r.cranial_limit_mask & ~r.aif_mask & valid & ~r.signal_quality_features.NonfiniteInputMask;
if isfield(r.signal_quality_features,'ProjectionForegroundMask'),domain=domain&r.signal_quality_features.ProjectionForegroundMask;end
for k=1:4,domain=domain&isfinite(maps{k});end
ids={r.roi_snapshot.ROIs.ID};[found,ix]=ismember(r.roi_snapshot.StatisticsPlan.ROIIds,ids);
assert(all(found),'DSAP:InclusiveROI','Snapshot ROI identities are missing.');
rois=r.roi_snapshot.ROIs(ix);n=numel(rois);masks=cell(n,1);names=reshape({rois.Name},[],1);
included=zeros(n,1);excluded=included;vesselPixels=included;with=nan(n,4);without=with;
for k=1:n
 masks{k}=rois(k).Mask & domain; tissue=masks{k}&~r.large_vessel_mask;
 included(k)=nnz(masks{k});excluded(k)=nnz(tissue);vesselPixels(k)=nnz(masks{k}&r.large_vessel_mask);
 for j=1:4
  with(k,j)=mean(maps{j}(masks{k}),'omitnan');without(k,j)=mean(maps{j}(tissue),'omitnan');
 end
end
summary=table(names,included,vesselPixels,with(:,1),with(:,2),with(:,3),with(:,4), ...
 'VariableNames',{'ROI','ValidPixels','RetainedVesselPixels','CBF','CBV','Tmax_s','MTT_s'});
comparison=table(names,excluded,included,vesselPixels,'VariableNames',{'ROI','TissuePixels','InclusivePixels','RetainedVesselPixels'});
metrics={'CBF','CBV','Tmax_s','MTT_s'};
for j=1:4
 comparison.([metrics{j} '_Tissue'])=without(:,j);
 comparison.([metrics{j} '_WithVessels'])=with(:,j);
 comparison.([metrics{j} '_Difference'])=with(:,j)-without(:,j);
 maps{j}(~domain)=NaN;
end
r.vessel_inclusive=struct('Version',1,'CBF',maps{1},'CBV',maps{2},'Tmax',maps{3},'MTT',maps{4}, ...
 'DomainMask',domain,'ROIMasks',{masks},'Names',{names},'Summary',summary,'Comparison',comparison, ...
 'SnapshotSignature',r.roi_snapshot.FullSignature, ...
 'Definition','Same pre-exclusion deconvolution and postprocessing; same source, AIF, time axis, signal/numerical validity and ROI; artery/vein exclusion disabled. AIF pixels remain excluded.', ...
 'Interpretation','Relative parameters of tissue plus vascular projections; not pure parenchymal perfusion.');
end
