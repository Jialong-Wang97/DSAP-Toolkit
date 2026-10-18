function identity=dsap_timeslice_validate_source(entries,source,info,provenance)
% Conservative selected-stack chain and DICOM metadata validation. No inference.
    required={'roiId','stepId','stackId','studyId','serialId','dicomFile','maskFile','serialTags'};
    assert(~isempty(entries)&&all(isfield(entries,required)), ...
        'DSAP:LegacySourceMetadata','Fresh linked stack metadata are required.');
    for name={'stackId','studyId','serialId'}
        assert(numel(unique({entries.(name{1})}))==1,'DSAP:LegacySourceConflict','Mixed %s.',name{1});
    end
    assert(isfield(provenance,'ReaderVersion')&&ismember(provenance.ReaderVersion,{'current-roi-v2','current-roi-v3'}), ...
        'DSAP:LegacySourceMetadata','A supported fresh reader snapshot is required.');
    has_stack_identity=strcmp(provenance.ReaderVersion,'current-roi-v3');
    if isfield(provenance,'SelectedStackSkipped')
        assert(isempty(provenance.SelectedStackSkipped),'DSAP:LegacyIncompleteStack','Selected stack has missing/ambiguous records.');
    else
        error('DSAP:LegacySourceMetadata','Skipped records for the selected stack must be retained.');
    end
    identity=dsap_source_identity(source);
    canonical=@(p) char(java.io.File(p).getCanonicalPath());
    root=canonical(provenance.dbRoot);
    stack_dir=fullfile(root,entries(1).studyId,entries(1).stackId);
    assert(startsWith([canonical(stack_dir) filesep],[root filesep],'IgnoreCase',true), ...
        'DSAP:LegacySourceConflict','Stack path leaves the configured database.');
    scan_dir=canonical(fullfile(stack_dir,'scan'));
    assert(strcmpi(fileparts(identity.Path),scan_dir),'DSAP:LegacySourceConflict','Source is outside selected stack scan directory.');
    for k=1:numel(entries)
        e=entries(k);
        assert(strcmpi(canonical(e.dicomFile),identity.Path)&& ...
            strcmpi(canonical(e.maskFile),canonical(fullfile(stack_dir,'rois',[e.stepId '.nii.gz']))), ...
            'DSAP:LegacySourceConflict','ROI/step/source path chain differs.');
        assert(isequaln(e.serialTags,entries(1).serialTags), ...
            'DSAP:LegacySourceConflict','Serial metadata changed within the snapshot.');
    end
    assert(isfield(info,'StudyInstanceUID')&&strcmp(char(info.StudyInstanceUID),entries(1).studyId)&& ...
        isfield(info,'SeriesInstanceUID')&&strcmp(char(info.SeriesInstanceUID),entries(1).serialId), ...
        'DSAP:LegacySourceConflict','Study/Series UID differs from the selected stack chain.');
    if has_stack_identity
        assert(isfield(provenance,'SourceLinkConvention')&&strcmp(provenance.SourceLinkConvention,'TIMESlice-Stack-Slice-SOP-v1')&& ...
            isfield(entries,'sourceSlices'),'DSAP:LegacySourceMetadata','Selected Stack/Slice source identity is missing.');
        slices=entries(1).sourceSlices;
        assert(isstruct(slices)&&isscalar(slices)&&all(isfield(slices,{'sliceId','stackId'}))&& ...
            strcmp(slices.stackId,entries(1).stackId), ...
            'DSAP:LegacySourceConflict','所选 Stack 没有唯一且正确关联的 Slice，不能自动导入 ROI。');
        assert(isfield(info,'SOPInstanceUID')&&strcmp(slices.sliceId,char(info.SOPInstanceUID)), ...
            'DSAP:LegacySourceConflict','所选 Stack 的 Slice SOP 与 DICOM SOP 不一致，不能自动导入 ROI。');
        if isfield(info,'MediaStorageSOPInstanceUID')
            assert(strcmp(char(info.MediaStorageSOPInstanceUID),char(info.SOPInstanceUID)), ...
                'DSAP:LegacySourceConflict','DICOM 文件头 SOP 与数据集 SOP 不一致。');
        end
        for k=1:numel(entries)
            assert(isequaln(entries(k).sourceSlices,slices),'DSAP:LegacySourceConflict','Slice source links changed within the snapshot.');
        end
        identity.LegacySourceLink=struct('Version',provenance.SourceLinkConvention,'Type','DirectSOP', ...
            'StackId',entries(1).stackId,'SliceSOP',slices.sliceId,'SelectedSOP',char(info.SOPInstanceUID), ...
            'SerialSOP','','ReferenceSequence','');
    end
    tags=entries(1).serialTags;
    required_tags={'StudyInstanceUID','SeriesInstanceUID','Rows','Columns','NumberOfFrames'};
    if has_stack_identity,required_tags{end+1}='SOPInstanceUID';end
    assert(~isempty(tags)&&all(ismember(required_tags,{tags.key})), ...
        'DSAP:LegacySourceMetadata','Required source identity/dimension tags are missing.');
    tag_info=info;
    if has_stack_identity
        assert(nnz(strcmp({tags.key},'SOPInstanceUID'))==1,'DSAP:LegacySourceConflict','Ambiguous serial SOP tag.');
        serial_sop=char(string(tags(strcmp({tags.key},'SOPInstanceUID')).value));
        identity.LegacySourceLink.SerialSOP=serial_sop;
        if ~strcmp(serial_sop,char(info.SOPInstanceUID))
            sequence=unique_parent_reference(info,serial_sop);
            assert(~isempty(sequence),'DSAP:LegacySourceConflict', ...
                'Serial SOP 与当前 Slice SOP 不一致，且 DICOM 没有唯一、精确的原图引用。');
            [tag_info,parent_identity]=validate_serial_tag_source(entries,info,serial_sop,root);
            identity.LegacySourceLink.Type='StackSliceWithDerivedReference';
            identity.LegacySourceLink.ReferenceSequence=sequence;
            identity.LegacySourceLink.ParentSourceIdentity=parent_identity;
        end
    end
    for k=1:numel(tags)
        key=tags(k).key;
        assert(nnz(strcmp({tags.key},key))==1,'DSAP:LegacySourceConflict','Ambiguous serial tag: %s.',key);
        assert(isfield(tag_info,key),'DSAP:LegacySourceConflict','DICOM is missing recorded tag: %s.',key);
        expected=char(string(tags(k).value));value=tag_info.(key);
        if isnumeric(value)
            numbers=sscanf(strrep(expected,'\',' '),'%f');match=isequaln(double(value(:)),numbers(:));
        else,match=strcmp(strtrim(char(value)),strtrim(expected));end
        assert(match,'DSAP:LegacySourceConflict','Recorded %s conflicts with selected DICOM; do not auto-import.',key);
    end
end

function [parent_info,identity]=validate_serial_tag_source(entries,info,sop,root)
assert(isfield(entries,'serialTagSources'),'DSAP:LegacySourceMetadata','Serial 标签缺少独立来源信息。');
parent=entries(1).serialTagSources;
assert(isstruct(parent)&&isscalar(parent)&&all(isfield(parent,{'stackId','studyId','serialId','sourceSlices','dicomFile'})), ...
    'DSAP:LegacySourceConflict','Serial 标签没有唯一、可核验的原图 Stack。');
assert(strcmp(parent.studyId,entries(1).studyId)&&strcmp(parent.serialId,entries(1).serialId)&& ...
    isstruct(parent.sourceSlices)&&isscalar(parent.sourceSlices)&&all(isfield(parent.sourceSlices,{'stackId','sliceId'}))&& ...
    strcmp(parent.sourceSlices.stackId,parent.stackId)&&strcmp(parent.sourceSlices.sliceId,sop), ...
    'DSAP:LegacySourceConflict','Serial 原图的 Study/Series/Stack/Slice 链不一致。');
canonical=@(p) char(java.io.File(p).getCanonicalPath());
scan=canonical(fullfile(root,parent.studyId,parent.stackId,'scan'));
assert(startsWith([scan filesep],[root filesep],'IgnoreCase',true)&&strcmpi(fileparts(canonical(parent.dicomFile)),scan), ...
    'DSAP:LegacySourceConflict','Serial 原图路径不属于已记录的 Stack。');
for k=1:numel(entries)
    assert(isequaln(entries(k).serialTagSources,parent),'DSAP:LegacySourceConflict','Serial source links changed within the snapshot.');
end
identity=dsap_source_identity(parent.dicomFile);parent_info=dicominfo(parent.dicomFile);
after=dsap_source_identity(parent.dicomFile);
assert(strcmp(identity.SHA256,after.SHA256),'DSAP:LegacySourceConflict','Serial 原图在来源校验期间发生变化。');
assert(strcmp(parent_info.SOPInstanceUID,sop)&&strcmp(parent_info.StudyInstanceUID,entries(1).studyId)&& ...
    strcmp(parent_info.SeriesInstanceUID,entries(1).serialId), ...
    'DSAP:LegacySourceConflict','Serial 原图的实际 DICOM 身份与 Realm 记录不一致。');
if isfield(parent_info,'MediaStorageSOPInstanceUID')
    assert(strcmp(parent_info.MediaStorageSOPInstanceUID,sop),'DSAP:LegacySourceConflict','Serial 原图文件头 SOP 不一致。');
end
% Preserve exact pixel dimensions/frame count; no tolerance, resizing or
% comparison of a derived instance's decimal serialization to parent tags.
for field={'Rows','Columns','NumberOfFrames'}
    assert(isfield(parent_info,field{1})&&isfield(info,field{1})&&isequaln(info.(field{1}),parent_info.(field{1})), ...
        'DSAP:LegacySourceConflict','当前图像与 Serial 原图的 %s 不一致。',field{1});
end
end

function sequence=unique_parent_reference(info,expected)
sequence='';
if isempty(strtrim(expected))||~isfield(info,'ImageType')||~isfield(info,'SOPClassUID'),return;end
parts=strsplit(char(info.ImageType),'\');if isempty(parts)||~strcmp(parts{1},'DERIVED'),return;end
if ~isfield(info,'ReferencedImageSequence')||~isstruct(info.ReferencedImageSequence),return;end
references=info.ReferencedImageSequence;items=fieldnames(references);matches=0;
for k=1:numel(items)
    item=references.(items{k});
    if isstruct(item)&&isscalar(item)&&isfield(item,'ReferencedSOPInstanceUID')&& ...
            strcmp(char(item.ReferencedSOPInstanceUID),expected)
        if ~isfield(item,'ReferencedSOPClassUID')||~strcmp(char(item.ReferencedSOPClassUID),char(info.SOPClassUID)),return;end
        matches=matches+1;sequence=['ReferencedImageSequence.' items{k}];
    end
end
if matches~=1,sequence='';end
end
