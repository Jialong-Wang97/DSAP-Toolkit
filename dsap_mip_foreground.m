function [foreground,model,smooth_projection] = dsap_mip_foreground(reference,limit_mask,sensitivity)
% Find the bright spatial support in the displayed maximum projection.
% This is a foreground boundary, not an anatomical whole-brain segmentation.
    if nargin<3,sensitivity=0;end
    validateattributes(reference,{'numeric'},{'2d','nonempty'});
    validateattributes(sensitivity,{'numeric'},{'scalar','finite','>=',-2,'<=',2});
    assert(islogical(limit_mask)&&isequal(size(reference),size(limit_mask)),'上下限与投影尺寸不匹配。');
    projection=single(reference);
    projection(~isfinite(projection))=0;
    projection=single(mat2gray(projection));
    scale=min(size(projection));
    sigma=max(0.5,scale/170);
    smooth_projection=imgaussfilt(projection,sigma,'Padding','replicate');
    values=smooth_projection(limit_mask);
    if isempty(values) || max(values)<=min(values)
        foreground=false(size(projection));
        threshold=Inf; otsu=NaN;
    else
        otsu=graythresh(values);
        threshold=max(0.5/255,otsu*0.75*(0.9^sensitivity));
        seed=smooth_projection>threshold & limit_mask;
        % Closing repairs tiny breaks in the observed bright boundary.
        % Enclosed dark holes remain available for temporal assessment;
        % no convex hull is used.
        radius=max(1,round(scale/256));
        seed=imclose(seed,strel('disk',radius,0)) & limit_mask;
        seed=bwareaopen(seed,max(4,round(numel(seed)*0.0001)),8);
        foreground=imfill(seed,'holes') & limit_mask;
    end
    % Keep the main spatial support only, without altering its boundary.
    % Do this before temporal/vessel exclusion: valid tissue inside the
    % main support may legitimately split into multiple disconnected parts.
    components=bwconncomp(foreground,8);
    original_pixels=nnz(foreground);
    if components.NumObjects>1
        [~,main_index]=max(cellfun(@numel,components.PixelIdxList));
        foreground(:)=false;
        foreground(components.PixelIdxList{main_index})=true;
    end
    model=struct('Method','smoothed-MIP-main-component-support', ...
        'SmoothingSigmaPixels',sigma,'OtsuThreshold',otsu, ...
        'AppliedThreshold',threshold,'Sensitivity',sensitivity, ...
        'ForegroundPixelCount',nnz(foreground),'LargestComponentOnly',true, ...
        'Connectivity',8,'OriginalComponentCount',components.NumObjects, ...
        'RemovedComponentCount',max(0,components.NumObjects-1), ...
        'RemovedSatellitePixelCount',original_pixels-nnz(foreground), ...
        'ConvexHullUsed',false,'EnclosedDarkRegionsRetained',true, ...
        'Definition','bright projection support; not proof of anatomical brain extent');
end
