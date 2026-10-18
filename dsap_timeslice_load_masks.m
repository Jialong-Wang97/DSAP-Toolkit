function masks=dsap_timeslice_load_masks(entries,image_size,transpose_masks)
% One current ROI object = one mask; no color/time based merging.
    assert(numel(unique({entries.roiId}))==numel(entries),'重复 ROI ID，拒绝导入。');
    masks=cell(numel(entries),1);
    for k=1:numel(entries)
        assert(isfile(entries(k).maskFile),'当前 ROI 掩膜缺失：%s',entries(k).maskFile);
        raw=squeeze(niftiread(entries(k).maskFile));
        assert(ismatrix(raw)&&all(isfinite(raw),'all'),'ROI 必须是有限的二维掩膜。');
        mask=raw~=0;
        if ischar(transpose_masks)||isstring(transpose_masks)
            mask=dsap_orientation_transform(mask,transpose_masks);
        elseif transpose_masks,mask=mask.';end
        assert(isequal(size(mask),image_size),'ROI 方向/尺寸不匹配：%s',entries(k).maskFile);
        masks{k}=mask;
    end
end
