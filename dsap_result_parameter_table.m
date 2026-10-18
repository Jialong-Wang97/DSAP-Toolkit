function result=dsap_result_parameter_table(r)
% Shared presentation/export schema; never changes the scientific base table.
base=r.summary_table;result=base;n=height(base);
distributionStatus='not_calculated';
if isfield(r,'DistributionAnalysisStatus'),distributionStatus=r.DistributionAnalysisStatus;end
if isfield(r,'distribution_summary_table')
 extended=r.distribution_summary_table;names=base.Properties.VariableNames;
 assert(istable(extended)&&all(ismember(names,extended.Properties.VariableNames))&& ...
  isequaln(extended(:,names),base),'DSAP:ResultTableAlignment','Distribution table does not match the current ROI results.');
 result=extended;distributionStatus='complete';
end
result.DistributionStatus=repmat({distributionStatus},n,1);
result.WithVesselsStatus=repmat({'unavailable_reanalysis_required'},n,1);
fields={'ValidPixels','RetainedVesselPixels','CBF','CBV','Tmax_s','MTT_s'};
for k=1:numel(fields),result.(['WithVessels_' fields{k}])=nan(n,1);end
metrics={'CBF','CBV','Tmax_s','MTT_s'};
for k=1:4,result.([metrics{k} '_VesselDifference'])=nan(n,1);end
result.ROIArtery_Status=repmat({'unavailable_reanalysis_required'},n,1);
if isfield(r,'roi_artery')
 a=r.roi_artery;t=a.Summary;count=height(t);
 assert(count<=n&&isequal(string(t.ROI),string(base.ROI(1:count)))&& ...
  isfield(r,'roi_snapshot')&&strcmp(a.SnapshotSignature,r.roi_snapshot.FullSignature), ...
  'DSAP:ResultTableAlignment','ROI artery statistics belong to another ROI revision.');
 result.ROIArtery_Status(:)={'not_applicable_vessel_roi'};
 result.ROIArtery_Status(1:count)=t.Status;
 fieldsA=setdiff(t.Properties.VariableNames,{'ROI','Status'},'stable');
 for k=1:numel(fieldsA)
  field=['ROIArtery_' fieldsA{k}];result.(field)=nan(n,1);
  result.(field)(1:count)=double(t.(fieldsA{k}));
 end
end
if ~isfield(r,'vessel_inclusive'),return;end
v=r.vessel_inclusive;count=height(v.Summary);
assert(count<=n&&isequal(string(v.Summary.ROI),string(base.ROI(1:count)))&& ...
 isequal(string(v.Comparison.ROI),string(v.Summary.ROI)), ...
 'DSAP:ResultTableAlignment','Vessel-inclusive rows do not match tissue ROI order.');
if isfield(r,'roi_snapshot')&&isfield(v,'SnapshotSignature')
 assert(strcmp(v.SnapshotSignature,r.roi_snapshot.FullSignature), ...
  'DSAP:ResultTableAlignment','Vessel-inclusive statistics belong to another ROI revision.');
end
result.WithVesselsStatus(:)={'not_applicable_vessel_roi'};
result.WithVesselsStatus(1:count)={'available'};
for k=1:numel(fields),result.(['WithVessels_' fields{k}])(1:count)=v.Summary.(fields{k});end
for k=1:4,result.([metrics{k} '_VesselDifference'])(1:count)=v.Comparison.([metrics{k} '_Difference']);end
end
