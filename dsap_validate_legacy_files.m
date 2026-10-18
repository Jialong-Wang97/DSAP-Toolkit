function dsap_validate_legacy_files(draft)
% Final confirmation must still refer to the exact files shown in preview.
    assert(isfield(draft.Provenance,'MaskIdentities')&&~isempty(draft.Provenance.MaskIdentities), ...
        'DSAP:LegacyMaskIdentity','Fresh import mask identities are required.');
    for k=1:numel(draft.Provenance.MaskIdentities)
        expected=draft.Provenance.MaskIdentities{k};actual=dsap_source_identity(expected.Path);
        assert(strcmp(actual.SHA256,expected.SHA256)&&actual.Bytes==expected.Bytes, ...
            'DSAP:LegacyMaskChanged','A mask changed while reviewing the import; import again.');
    end
end
