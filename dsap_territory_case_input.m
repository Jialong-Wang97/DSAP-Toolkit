function [sequence,metadata,reference]=dsap_territory_case_input(source)
% Read-only native DICOM adapter; pixel order is the DSAP [T,H,W] contract.
if isfolder(source)
 core=load(fullfile(source,'interactive_perfusion_results.mat'),'source_file');source=core.source_file;
end
identity=dsap_source_identity(source);info=dicominfo(source);raw=squeeze(dicomread(info));
assert(size(raw,1)==info.Rows&&size(raw,2)==info.Columns&&ndims(raw)<=3,'DSAP:TerritoryDICOM','Unsupported RGB or non-native DICOM frame geometry.');
if ismatrix(raw),sequence=reshape(raw,[1 size(raw)]);else,sequence=permute(raw,[3 1 2]);end
reference=squeeze(min(single(sequence),[],1));spacing=[];if isfield(info,'PixelSpacing'),spacing=double(info.PixelSpacing(:)');end
orientation=struct();for key={'ImageOrientationPatient','ImagePositionPatient','PatientOrientation','PositionerPrimaryAngle','PositionerSecondaryAngle','PhotometricInterpretation'}
 if isfield(info,key{1}),orientation.(key{1})=info.(key{1});end
end
metadata=struct('source_id',identity.SHA256,'source_file',identity.Path,'view','AP','view_selection_required',true, ...
 'input_kind','dark_dsa','pixel_spacing',spacing,'dicom_orientation',orientation,'axis_order','time,row,column');
end
