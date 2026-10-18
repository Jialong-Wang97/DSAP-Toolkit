function report=dsap_orientation_compare(original,expected,approved_mapping)
% Diagnostic evidence only. Calling this does not approve a contract.
    assert(islogical(original)&&ismatrix(original)&&islogical(expected)&&ismatrix(expected), ...
        'DSAP:OrientationMask','Both masks must be logical 2-D matrices.');
    assert(any(expected,'all'),'DSAP:OrientationExpected','ExpectedMask cannot be empty.');
    mapping={'identity';'transpose';'flipud';'fliplr';'flipud+fliplr'; ...
        'transpose+flipud';'transpose+fliplr';'transpose+flipud+fliplr'};
    same_size=false(8,1);mask_equal=same_size;indices_equal=same_size;jaccard=nan(8,1);
    indices=find(expected);
    for k=1:8
        candidate=dsap_orientation_transform(original,mapping{k});
        same_size(k)=isequal(size(candidate),size(expected));
        mask_equal(k)=isequaln(candidate,expected);
        indices_equal(k)=isequaln(find(candidate),indices);
        if same_size(k),jaccard(k)=nnz(candidate&expected)/nnz(candidate|expected);end
    end
    matches=mask_equal&indices_equal&same_size;approved=strcmp(mapping,approved_mapping);
    % QC criterion, not an equality tolerance: near-symmetric evidence is rejected.
    report=struct('Candidates',table(mapping,same_size,mask_equal,indices_equal,jaccard, ...
        'VariableNames',{'Mapping','SameSize','MaskEqual','IndicesEqual','Jaccard'}), ...
        'ApprovedMapping',char(approved_mapping),'UniqueExactMatch',nnz(matches)==1, ...
        'ApprovedMappingMatches',nnz(approved)==1&&any(matches&approved), ...
        'NearSymmetryThreshold',.95,'NearSymmetric',any(jaccard(~approved)>=.95), ...
        'Passed',false);
    report.Passed=report.UniqueExactMatch&&report.ApprovedMappingMatches&&~report.NearSymmetric;
end
