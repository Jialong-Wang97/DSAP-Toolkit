function output=dsap_orientation_fixture(action,varargin)
% capture(entry,provenance,new_folder): preserve original data; no ExpectedMask.
% review(fixture_file,independent_expected_mat,attestation,new_output_mat).
% validate(reviewed_fixture_file): source/integrity checks + eight candidates.
    switch action
        case 'capture',output=capture(varargin{:});
        case 'review',output=review(varargin{:});
        case 'validate',output=validate(varargin{:});
        case 'inspect',output=inspect(varargin{:});
        case 'human_review',output=human_review(varargin{:});
        otherwise,error('DSAP:OrientationAction','Unknown fixture action.');
    end
end

function Fixture=inspect(file)
    Fixture=load_fixture(file);check_capture(Fixture);
end

function file=human_review(fixture_file,mapping,decision,folder)
% New user-approved evidence definition: human selects a discrete pixel mapping.
% Do not describe the generated raster as an independently authored pixel mask.
    assert(~isfolder(folder),'DSAP:FixtureExists','Use a new review folder.');
    Fixture=inspect(fixture_file);c=Fixture.Capture;
    required={'Reviewer','ExplicitUnambiguousConfirmation','DistinctPositionConfirmed','AsymmetryConfirmed','Simulation'};
    assert(all(isfield(decision,required))&&~isempty(decision.Reviewer)&& ...
        isequal(decision.ExplicitUnambiguousConfirmation,true)&& ...
        islogical(decision.DistinctPositionConfirmed)&&isscalar(decision.DistinctPositionConfirmed)&& ...
        islogical(decision.AsymmetryConfirmed)&&isscalar(decision.AsymmetryConfirmed), ...
        'DSAP:HumanReviewRequired','An explicit unambiguous anatomical/historical-position selection is required.');
    ExpectedMask=dsap_orientation_transform(squeeze(c.OriginalMask)~=0,mapping);
    assert(isequal(size(ExpectedMask),[c.DICOMIdentity.Rows c.DICOMIdentity.Columns]), ...
        'DSAP:OrientationExpected','Mapping does not fit the DICOM pixel domain.');
    ExpectedPixelIndices=find(ExpectedMask);
    comparison=dsap_orientation_compare(squeeze(c.OriginalMask)~=0,ExpectedMask,mapping);
    assert(comparison.Passed,'DSAP:OrientationParity','Ambiguous or near-symmetric mapping evidence.');
    writer=c.WriterVersion;
    if isempty(writer)&&isfield(c.Provenance,'WriterVersion'),writer=c.Provenance.WriterVersion;end
    attestation=struct('ExpectedMethod', ...
        'Exact original NIfTI permutation selected by human anatomical and historical-position review on native DICOM; raster is generated, not independently authored.', ...
        'Reviewer',decision.Reviewer,'ReviewerIdentityMethod','Local interactive account with explicit review-button confirmation', ...
        'ConfirmationTimestampUTC',utcnow(),'ApprovedMapping',char(mapping),'WriterVersion',writer, ...
        'SchemaVersion',c.SchemaVersion,'ImportVersion',c.ImportVersion, ...
        'IndependentDICOMPixelGroundTruth',false,'HumanAnatomicalReview',~decision.Simulation, ...
        'ExplicitUnambiguousConfirmation',true,'DistinctPositionConfirmed',decision.DistinctPositionConfirmed, ...
        'AsymmetryConfirmed',decision.AsymmetryConfirmed, ...
        'DistinctPositionBasis','Normalized centroid separation >=0.10 from retained evidence; human confirms current anatomical position', ...
        'AsymmetryBasis','Explicit confirmation plus exact candidate uniqueness and near-symmetry checks', ...
        'Simulation',logical(decision.Simulation));
    if isfield(decision,'ViewedFrame'),attestation.ViewedFrame=decision.ViewedFrame;end
    if isfield(decision,'SessionId'),attestation.SessionId=decision.SessionId;end
    mkdir(folder);expected_file=fullfile(folder,'expected_mask.mat');
    save(expected_file,'ExpectedMask','ExpectedPixelIndices','attestation','-v7');
    Fixture.Review=struct('ExpectedMask',ExpectedMask,'ExpectedPixelIndices',ExpectedPixelIndices, ...
        'ExpectedFile',dsap_source_identity(expected_file),'Attestation',attestation, ...
        'Comparison',comparison,'RecordedAtUTC',utcnow());
    Fixture.ReviewSignature=dsap_analysis_signature(Fixture.Review);
    Fixture.Status='HumanAnatomicallyReviewed';
    if decision.Simulation,Fixture.Status='SimulationNotHumanEvidence';end
    file=fullfile(folder,'reviewed_fixture.mat');save(file,'Fixture','-v7');
    writetable(comparison.Candidates,fullfile(folder,'candidates.csv'));
    record=struct('FixtureFile',fixture_file,'ReviewedFile',file,'SourceDICOM',c.SourceDICOM, ...
        'NIfTI',c.NIfTI,'StackId',c.TIMESlice.stackId,'ROIId',c.TIMESlice.roiId,'StepId',c.TIMESlice.stepId, ...
        'ApprovedMapping',char(mapping),'Attestation',attestation,'Status',Fixture.Status);
    write_json(fullfile(folder,'human_review.json'),record);
end

function file=capture(entry,provenance,folder)
    assert(~isfolder(folder),'DSAP:FixtureExists','Use a new fixture folder; existing evidence is never overwritten.');
    source=dsap_source_identity(entry.dicomFile);mask_id=dsap_source_identity(entry.maskFile);
    info=dicominfo(entry.dicomFile);original=niftiread(entry.maskFile);nifti_info=niftiinfo(entry.maskFile);
    assert(ismatrix(squeeze(original))&&all(isfinite(original),'all'),'DSAP:OrientationMask','Invalid original NIfTI mask.');
    metadata=struct('StudyInstanceUID',char(info.StudyInstanceUID),'SeriesInstanceUID',char(info.SeriesInstanceUID), ...
        'SOPInstanceUID',char(info.SOPInstanceUID),'Rows',double(info.Rows),'Columns',double(info.Columns));
    source_check=struct('Passed',false,'Identifier','','Message','');
    try
        dsap_timeslice_validate_source(entry,entry.dicomFile,info,provenance);source_check.Passed=true;
    catch exception
        if ~startsWith(exception.identifier,'DSAP:Legacy'),rethrow(exception);end
        source_check.Identifier=exception.identifier;source_check.Message=exception.message;
    end
    assert_same(source,dsap_source_identity(entry.dicomFile));assert_same(mask_id,dsap_source_identity(entry.maskFile));
    assert(isfield(provenance,'SchemaVersion')&&~isempty(provenance.SchemaVersion), ...
        'DSAP:OrientationSchema','Fresh Realm schema identity is required.');
    data=struct('Origin','RealTIMESliceExport','SourceDICOM',source,'DICOMIdentity',metadata, ...
        'TIMESlice',entry,'NIfTI',mask_id,'OriginalMask',original,'NIfTIHeader',nifti_info, ...
        'SourceValidation',source_check,'Provenance',provenance, ...
        'WriterVersion','','SchemaVersion',provenance.SchemaVersion, ...
        'ImportVersion','DSAP-orientation-v2','CapturedAtUTC',utcnow());
    Fixture=struct('SchemaVersion',2,'Capture',data,'CaptureSignature',dsap_analysis_signature(data), ...
        'Review',struct([]),'Status','AwaitingIndependentExpectedMask');
    mkdir(folder);file=fullfile(folder,'fixture.mat');save(file,'Fixture','-v7');
    % No zero/empty logical ExpectedMask is generated: absence remains explicit.
    todo=struct('Status',Fixture.Status,'ExpectedFile','','ExpectedMethod','','Reviewer','', ...
        'ConfirmationTimestampUTC','','ApprovedMapping','','WriterVersion','', ...
        'SchemaVersion',data.SchemaVersion,'ImportVersion',data.ImportVersion, ...
        'IndependentDICOMPixelGroundTruth',false,'DistinctPositionConfirmed',false, ...
        'AsymmetryConfirmed',false,'SourceValidation',source_check);
    write_json(fullfile(folder,'review_required.json'),todo);
end

function file=review(fixture_file,expected_file,attestation,file)
    assert(~isfile(file),'DSAP:FixtureExists','Reviewed evidence cannot be overwritten.');
    Fixture=load_fixture(fixture_file);check_capture(Fixture);
    assert(Fixture.Capture.SourceValidation.Passed,'DSAP:OrientationSource','Source-conflict fixtures cannot approve a contract.');
    required={'ExpectedMethod','Reviewer','ConfirmationTimestampUTC','ApprovedMapping','WriterVersion', ...
        'SchemaVersion','ImportVersion','IndependentDICOMPixelGroundTruth','DistinctPositionConfirmed','AsymmetryConfirmed'};
    assert(all(isfield(attestation,required)),'DSAP:OrientationAttestation','Review metadata are incomplete.');
    for key=required(1:7)
        value=attestation.(key{1});assert((ischar(value)||isstring(value))&&strlength(string(value))>0, ...
            'DSAP:OrientationAttestation','Missing review field: %s',key{1});
    end
    assert(~any(strcmpi(strtrim(string(attestation.WriterVersion)),["unknown","pending","unverified"])), ...
        'DSAP:OrientationWriter','Unknown writer versions cannot approve a contract.');
    assert(strcmp(attestation.SchemaVersion,Fixture.Capture.SchemaVersion)&& ...
        strcmp(attestation.ImportVersion,Fixture.Capture.ImportVersion), ...
        'DSAP:OrientationVersion','Reviewed schema/import versions differ from capture.');
    assert(isequal(attestation.IndependentDICOMPixelGroundTruth,true)&& ...
        isequal(attestation.DistinctPositionConfirmed,true)&&isequal(attestation.AsymmetryConfirmed,true), ...
        'DSAP:OrientationAttestation','Independent ground truth, position and asymmetry require explicit confirmation.');
    timestamp=char(attestation.ConfirmationTimestampUTC);
    assert(~isempty(regexp(timestamp,'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$','once')), ...
        'DSAP:OrientationAttestation','Use a reviewer-supplied UTC timestamp: yyyy-MM-ddTHH:mm:ssZ.');
    datetime(timestamp,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');
    expected_id=dsap_source_identity(expected_file);data=load(expected_file,'ExpectedMask','ExpectedPixelIndices');
    assert_same(expected_id,dsap_source_identity(expected_file));
    assert(isfield(data,'ExpectedMask')&&islogical(data.ExpectedMask)&& ...
        isequal(size(data.ExpectedMask),[Fixture.Capture.DICOMIdentity.Rows Fixture.Capture.DICOMIdentity.Columns]), ...
        'DSAP:OrientationExpected','ExpectedMask must be independently supplied, logical and DICOM-sized.');
    indices=find(data.ExpectedMask);
    if isfield(data,'ExpectedPixelIndices')
        assert(isequaln(indices,data.ExpectedPixelIndices),'DSAP:OrientationExpected','Supplied expected indices differ from ExpectedMask.');
    end
    comparison=dsap_orientation_compare(squeeze(Fixture.Capture.OriginalMask)~=0,data.ExpectedMask,attestation.ApprovedMapping);
    Fixture.Review=struct('ExpectedMask',data.ExpectedMask,'ExpectedPixelIndices',indices, ...
        'ExpectedFile',expected_id,'Attestation',attestation,'Comparison',comparison,'RecordedAtUTC',utcnow());
    Fixture.ReviewSignature=dsap_analysis_signature(Fixture.Review);
    Fixture.Status='ReviewedRejected';if comparison.Passed,Fixture.Status='ReviewedCandidatePass';end
    save(file,'Fixture','-v7');writetable(comparison.Candidates,[file '.candidates.csv']);
    % A failing review is retained as evidence; it cannot mint a contract.
end

function output=validate(file)
    Fixture=load_fixture(file);check_capture(Fixture);
    assert(Fixture.Capture.SourceValidation.Passed,'DSAP:OrientationSource','Source conflict remains an exception.');
    assert(~isempty(Fixture.Review)&&isfield(Fixture,'ReviewSignature'), ...
        'DSAP:OrientationEvidenceMissing','Awaiting independent ExpectedMask and reviewer attestation.');
    assert(strcmp(Fixture.ReviewSignature,dsap_analysis_signature(Fixture.Review)), ...
        'DSAP:OrientationEvidenceChanged','Reviewed evidence changed.');
    review=Fixture.Review;assert_same(review.ExpectedFile,dsap_source_identity(review.ExpectedFile.Path));
    a=review.Attestation;
    human=isfield(a,'HumanAnatomicalReview')&&isequal(a.HumanAnatomicalReview,true);
    independent=isfield(a,'IndependentDICOMPixelGroundTruth')&&isequal(a.IndependentDICOMPixelGroundTruth,true);
    simulated=isfield(a,'Simulation')&&isequal(a.Simulation,true);
    assert(~simulated&&(human||independent)&&isequal(a.DistinctPositionConfirmed,true)&& ...
        isequal(a.AsymmetryConfirmed,true),'DSAP:HumanReviewRequired','No real, unambiguous human review is recorded.');
    if human
        assert(isfield(a,'ExplicitUnambiguousConfirmation')&&isequal(a.ExplicitUnambiguousConfirmation,true), ...
            'DSAP:HumanReviewRequired','Explicit anatomical confirmation is required.');
    end
    assert(isequaln(find(review.ExpectedMask),review.ExpectedPixelIndices), ...
        'DSAP:OrientationExpected','Expected indices changed.');
    comparison=dsap_orientation_compare(squeeze(Fixture.Capture.OriginalMask)~=0,review.ExpectedMask,review.Attestation.ApprovedMapping);
    assert(comparison.Passed,'DSAP:OrientationParity','Only the approved mapping may match; near-symmetric fixtures are rejected.');
    [row,col]=find(review.ExpectedMask);sz=size(review.ExpectedMask);
    output=struct('FixtureFile',dsap_source_identity(file),'Capture',Fixture.Capture, ...
        'CaptureSignature',Fixture.CaptureSignature,'ReviewSignature',Fixture.ReviewSignature, ...
        'Attestation',review.Attestation,'ExpectedFile',review.ExpectedFile, ...
        'ExpectedPixelIndices',review.ExpectedPixelIndices,'Comparison',comparison, ...
        'CentroidNormalized',[mean(row)/sz(1) mean(col)/sz(2)],'ImageSize',sz);
end

function Fixture=load_fixture(file)
    data=load(file,'Fixture');assert(isfield(data,'Fixture')&&data.Fixture.SchemaVersion==2, ...
        'DSAP:OrientationFixture','A v2 real fixture bundle is required.');Fixture=data.Fixture;
end
function check_capture(Fixture)
    assert(strcmp(Fixture.CaptureSignature,dsap_analysis_signature(Fixture.Capture)), ...
        'DSAP:OrientationEvidenceChanged','Captured source evidence changed.');
    c=Fixture.Capture;
    assert_same(c.SourceDICOM,dsap_source_identity(c.SourceDICOM.Path));
    assert_same(c.NIfTI,dsap_source_identity(c.NIfTI.Path));
    assert(isequaln(niftiread(c.NIfTI.Path),c.OriginalMask),'DSAP:OrientationEvidenceChanged','Original mask differs from captured NIfTI.');
    info=dicominfo(c.SourceDICOM.Path);
    dsap_timeslice_validate_source(c.TIMESlice,c.SourceDICOM.Path,info,c.Provenance);
end
function assert_same(before,after)
    assert(strcmp(before.SHA256,after.SHA256)&&before.Bytes==after.Bytes, ...
        'DSAP:OrientationEvidenceChanged','Evidence file changed: %s',before.Path);
end
function value=utcnow
    value=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
end
function write_json(file,value)
    fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
