function snapshot=dsap_build_roi_snapshot(source_identity,aif,limits,definition,settings,source)
% Frozen input description. This helper does not rasterize or alter any mask.
% Historical imports preserve their recorded choices, not new color semantics.
    assert(islogical(aif)&&ismatrix(aif),'DSAP:SnapshotMask','AIF must be a logical 2-D mask.');
    image_size=size(aif);band=false(image_size);
    assert(limits.UpperRow>=1&&limits.LowerRow<=image_size(1)&& ...
        limits.UpperRow<=limits.LowerRow,'DSAP:SnapshotLimits','Invalid cranial limits.');
    band(limits.UpperRow:limits.LowerRow,:)=true;
    geometry=struct('ImageSize',image_size,'Coordinates','x=column,y=row', ...
        'LinearOrder','MATLAB column-major','MaskClass','logical');
    geometry.ID=dsap_analysis_signature(geometry);
    empty=struct('ID','','Role','','Side','Unknown','Source',source,'Name','', ...
        'Mask',false(0),'GeometryID',geometry.ID,'SourceIdentityID',source_identity.SHA256, ...
        'Adopted',true,'Origin',struct());
    rois=empty;rois.ID='AIF';rois.Role='AIF';rois.Name='AIF';rois.Mask=aif;
    orientation=struct('Mapping','identity','ContractVersion','NativeDSAP-v1', ...
        'Status','NativePixelCoordinates','Evidence',struct());
    if strcmp(source,'NativeDSAP')
        assert(isfield(definition,'Confirmed')&&isequal(definition.Confirmed,true), ...
            'DSAP:SnapshotUnconfirmed','Partition has not been confirmed.');
        if isfield(definition,'Mode')&&strcmp(definition.Mode,'Freehand')
            masks=definition.Masks(:);names=definition.Names(:);
            assert(~isempty(masks)&&numel(masks)==numel(names)&& ...
                numel(masks)==numel(definition.SelectedFrames)&& ...
                numel(masks)==numel(definition.Types)&&numel(masks)==numel(definition.MergeSources), ...
                'DSAP:SnapshotFreehand','Freehand ROI metadata must be complete.');
            ids=arrayfun(@(k) sprintf('Tissue%d',k),(1:numel(masks))','UniformOutput',false);
            roles=repmat({'PrimaryTissue'},numel(masks),1);
            for k=1:numel(masks)
                assert(islogical(masks{k})&&isequal(size(masks{k}),image_size)&&nnz(masks{k})>=3, ...
                    'DSAP:SnapshotFreehand','Each freehand ROI must be a logical DSA-domain mask with at least 3 pixels.');
                if strcmp(definition.Types{k},'Merged'),roles{k}='MergedTissue';end
            end
            policy='native-freehand-v1';scope=false(image_size);
            for k=1:numel(masks),scope=scope|masks{k};end
            origins=cell(numel(masks),1);
            for k=1:numel(masks)
                origins{k}=struct('DrawingMethod','drawfreehand/createMask(roi)', ...
                    'SelectedFrame',definition.SelectedFrames(k),'ROIType',definition.Types{k}, ...
                    'MergeSources',definition.MergeSources{k});
            end
            provenance=struct('Adapter','native-legacy-freehand-v1', ...
                'Rasterization','drawfreehand/createMask(roi)', ...
                'Statistics','raw mask intersected with valid capillary tissue after CAVE');
            minimum=3;denominator='TICPixels';aggregate=false;outer_field=false;
        else
            masks={definition.CortexMask;definition.SubcortexMask;definition.OuterMask};
            names={'皮层';'皮层下';'颅内合并'};ids={'Cortex';'Subcortex';'Outer'};
            roles={'Partition';'Partition';'PrimaryTissue'};
            assert(~any(masks{1}&masks{2},'all')&&isequal(masks{1}|masks{2},masks{3}), ...
                'DSAP:SnapshotPartition','Partition union is inconsistent.');
            policy='partition-v1';scope=definition.OuterMask;
            origins=repmat({struct()},3,1);origins{3}=definition;
            provenance=struct('Adapter','native-existing-partition-v1');
            minimum=0;denominator='max(TICPixels,1)';aggregate=false;outer_field=false;
        end
    elseif strcmp(source,'LegacyTIMESlice')
        assert(isfield(definition,'Confirmed')&&isequal(definition.Confirmed,true), ...
            'DSAP:SnapshotUnconfirmed','Historical import has not been confirmed.');
        assert(isequaln(aif,definition.AIFMask),'DSAP:SnapshotAIF','AIF differs from recorded import.');
        masks=definition.Masks(:);names=definition.Names(:);
        ids=arrayfun(@(k) sprintf('Tissue%d',k),(1:numel(masks))','UniformOutput',false);
        roles=repmat({'PrimaryTissue'},numel(masks),1);
        origins=arrayfun(@(x) x,definition.Entries(:),'UniformOutput',false);
        rois.Origin=definition.AIFEntry;
        orientation.Mapping='identity';
        if definition.Transposed,orientation.Mapping='transpose';end
        orientation.ContractVersion='historical-manual-review';
        orientation.Status='RecordedChoiceOnly';
        orientation.Evidence=struct('AutomaticImportAuthorized',false);
        provenance=definition.Provenance;
        provenance.Adapter='historical-confirmed-import-v1';
        if isfield(definition,'OrientationContract')
            approved=definition.OrientationContract;
            orientation.Mapping=approved.Orientation.Mapping;
            orientation.ContractVersion=approved.Orientation.Version;
            orientation.Status='VerifiedObservableLegacyProfile';
            orientation.Evidence=approved;
            provenance.Adapter='observable-legacy-profile-v1';
        end
        policy='imported-v1';scope=false(image_size);
        for k=1:numel(masks),scope=scope|(logical(masks{k})&band);end
        minimum=3;denominator='TICPixels';aggregate=numel(masks)>1;outer_field=true;
    else
        error('DSAP:SnapshotSource','Unknown ROI source.');
    end
    assert(numel(masks)==numel(names)&&numel(masks)==numel(origins), ...
        'DSAP:SnapshotRows','ROI metadata and masks have different lengths.');
    for k=1:numel(masks)
        item=empty;item.ID=ids{k};item.Role=roles{k};item.Name=names{k};
        item.Mask=masks{k};item.Origin=origins{k};rois(end+1)=item; %#ok<AGROW>
    end
    if strcmp(source,'LegacyTIMESlice')&&isfield(definition,'Semantics')
        semantics=definition.Semantics;
        for k=1:numel(rois)
            index=find(strcmp({definition.AllEntries.roiId},rois(k).Origin.roiId),1);
            rois(k).Side=semantics(index).Side;
        end
        for index=find(strcmp({semantics.Role},'OtherTissue'))
            item=empty;item.ID=['LegacyOther_' definition.AllEntries(index).roiId];
            item.Role='OtherTissue';item.Side=semantics(index).Side;item.Adopted=false;
            item.Name=definition.AllEntries(index).name;item.Mask=definition.AllMasks{index};
            item.Origin=definition.AllEntries(index);rois(end+1)=item; %#ok<AGROW>
        end
    end
    plan=struct('Version',policy,'ROIIds',{ids},'Names',{names}, ...
        'ClipToCranialBand',strcmp(policy,'imported-v1'),'AppendUnion',aggregate, ...
        'UnionName','TIMESlice_合并','MinimumTICPixels',minimum, ...
        'CoverageDenominator',denominator,'IncludeOuterMaskField',outer_field);
    snapshot=struct('SchemaVersion',1,'ID',char(java.util.UUID.randomUUID()), ...
        'Source',source,'SourceIdentity',source_identity,'Geometry',geometry, ...
        'Orientation',orientation,'ROIs',rois,'AnalysisScope', ...
        struct('CranialLimits',limits,'BandMask',band,'Mask',scope), ...
        'StatisticsPlan',plan,'Settings',settings,'Provenance',provenance, ...
        'ProducerVersions',struct('SnapshotSchema',1,'MATLAB',version, ...
        'AnalysisCodeSignature',dsap_analysis_code_signature), ...
        'Confirmed',true,'ConfirmedAtUTC',char(datetime('now','TimeZone','UTC', ...
        'Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")),'FullSignature','');
    snapshot.FullSignature=dsap_analysis_signature(rmfield(snapshot,'FullSignature'));
    dsap_validate_roi_snapshot(snapshot);
end
