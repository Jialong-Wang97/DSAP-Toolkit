function [draft,identity]=dsap_timeslice_prepare_import(entries,source,info,provenance,contract)
% Inactive adapter until a real orientation contract passes. No GUI or edits.
% Caller must display read-only preview and explicitly confirm before freezing.
    identity=dsap_timeslice_validate_source(entries,source,info,provenance);
    [semantic,issues]=dsap_timeslice_semantics(entries);
    assert(isempty(issues),'DSAP:LegacySemanticException','Legacy import requires review: %s',strjoin(issues,', '));
    assert(nargin>=5&&isstruct(contract)&&isfield(contract,'Verified')&&isequal(contract.Verified,true), ...
        'DSAP:OrientationEvidenceMissing','Automatic import is disabled without a verified real-fixture contract.');
    before=cell(numel(entries),1);
    for k=1:numel(entries),before{k}=dsap_source_identity(entries(k).maskFile);end
    observed=dsap_legacy_observable_profile(entries,provenance);
    mapping=dsap_validate_orientation_contract(contract,provenance,observed,[info.Rows info.Columns]);
    masks=dsap_timeslice_load_masks(entries,[info.Rows info.Columns],mapping);
    for k=1:numel(entries)
        after=dsap_source_identity(entries(k).maskFile);
        assert(strcmp(before{k}.SHA256,after.SHA256),'DSAP:LegacyMaskChanged','ROI mask changed during import.');
        if semantic(k).Adopted
            assert(nnz(masks{k})>=3,'DSAP:LegacyMaskInvalid','Required ROI mask has fewer than 3 pixels.');
        end
    end
    after=dsap_source_identity(source);
    assert(strcmp(identity.SHA256,after.SHA256),'DSAP:LegacySourceChanged','DICOM source changed during import.');
    ai=find(strcmp({semantic.Role},'AIF'));ti=find(strcmp({semantic.Role},'PrimaryTissue'));
    names=arrayfun(@(k) sprintf('TIMESlice_%d_%s',k,entries(k).name),ti,'UniformOutput',false)';
    provenance.SemanticVersion='LegacyTIMESlice-semantic-v1';provenance.MaskIdentities=before;
    draft=struct('AIFMask',masks{ai},'Masks',{masks(ti)},'Names',{names}, ...
        'AIFEntry',entries(ai),'Entries',entries(ti),'Transposed',startsWith(mapping,'transpose'), ...
        'Provenance',provenance,'Confirmed',false,'AllEntries',entries,'AllMasks',{masks}, ...
        'Semantics',semantic,'OrientationContract',contract);
end
