function provenance=dsap_roi_automation_provenance(state,frame)
% Compact result metadata only. No masks, volumes, Snapshot fields or signatures.
keys={'ReferenceFrame','AIF','CranialLimits'};provenance=struct('Enabled',state.Enabled, ...
 'Version','rule-based-ROI-suggestions-v1','ReferenceFrameSource',state.ReferenceFrameSource, ...
 'ActualReferenceFrame',frame,'Timing',state.Timing);
for k=1:numel(keys)
 s=state.(keys{k});record=struct('Method',s.Method,'Quality',s.Quality,'SuggestedValue',[], ...
  'Accepted',s.Accepted,'ManualOverride',s.ManuallyModified,'Rejected',s.Rejected,'CreatedAt',s.CreatedAt,'Reason',s.Reason);
 if k~=2,record.SuggestedValue=s.Value;else,record.SuggestedArea=nnz(s.Value);end
 if isfield(state.Used,keys{k}),record.AcceptedSuggestion=state.Used.(keys{k});end
 provenance.(keys{k})=record;
end
end
