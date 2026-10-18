function stats=dsap_imported_statistics(imported,band,vessels,aif,valid,nonfinite)
% Retain finite weak-signal pixels in TIC; valid fits only in perfusion.
    masks=imported.Masks(:);names=imported.Names(:);combined=false(size(band));
    assert(numel(masks)==numel(names)&&~isempty(masks));
    for k=1:numel(masks)
        assert(isequal(size(masks{k}),size(band)),'导入 ROI 尺寸不一致。');
        masks{k}=logical(masks{k})&band;combined=combined|masks{k};
    end
    if numel(masks)>1,masks{end+1}=combined;names{end+1}='TIMESlice_合并';end
    n=numel(masks);tic_masks=cell(n,1);parameter_masks=cell(n,1);
    counts=zeros(n,6);
    for k=1:n
        raw=masks{k};clean=raw&~vessels&~aif;
        tic_masks{k}=clean&~nonfinite;parameter_masks{k}=tic_masks{k}&valid;
        counts(k,:)=[nnz(raw),nnz(raw&vessels&~aif),nnz(raw&aif),nnz(clean&nonfinite), ...
            nnz(tic_masks{k}),nnz(parameter_masks{k})];
        assert(counts(k,5)>=3,'ROI %s 在上下限和血管/AIF 排除后不足 3 像素。',names{k});
    end
    coverage=table(names,counts(:,1),counts(:,2),counts(:,3),counts(:,4),counts(:,5),counts(:,6), ...
        counts(:,5)-counts(:,6),100*counts(:,6)./counts(:,5), ...
        'VariableNames',{'ROI','GeometryPixels','ExcludedVesselPixels','ExcludedAIFPixels', ...
        'NonfiniteInputPixels','TICPixels','PerfusionValidPixels','InvalidPerfusionPixels','PerfusionCoveragePercent'});
    stats=struct('Names',{names},'GeometryMasks',{masks},'TICMasks',{tic_masks}, ...
        'ParameterMasks',{parameter_masks},'Coverage',coverage,'OuterMask',combined);
end
