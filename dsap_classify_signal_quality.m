function [valid_mask, model, features] = dsap_classify_signal_quality(sequence, noise_map, limit_mask, sensitivity, reference, fixed_foreground)
% Pixelwise enhancement detectability. This does NOT segment anatomical brain.
% MIP spatial support first, then temporal detectability within that support.
    if nargin<4, sensitivity=0; end
    image_size=[size(sequence,2),size(sequence,3)];
    validateattributes(sequence,{'numeric'},{'nonempty','3d'});
    validateattributes(sensitivity,{'numeric'},{'scalar','finite','>=',-2,'<=',2});
    assert(isequal(size(noise_map),image_size) && all(isfinite(noise_map),'all') && ...
        all(noise_map>0,'all'),'噪声图必须是同尺寸的正数图像。');
    assert(islogical(limit_mask) && isequal(size(limit_mask),image_size),'上下限掩膜尺寸不匹配。');
    n=size(sequence,1);
    high=3*(0.8^sensitivity);
    low=1.5*(0.8^sensitivity);
    minimum_run=max(2,ceil(0.08*n));
    run=zeros(image_size,'uint16'); longest=run;
    peak=zeros(image_size,'single');
    nonfinite=false(image_size);
    for k=1:n
        dsap_task_control('check');
        frame=single(squeeze(sequence(k,:,:)));
        nonfinite=nonfinite | ~isfinite(frame);
        frame(~isfinite(frame))=0;
        peak=max(peak,frame);
        above=frame>=high*noise_map;
        run=(run+1).*uint16(above);
        longest=max(longest,run);
    end
    snr=peak./single(noise_map);
    if nargin<5,reference=peak;end
    if nargin>=6
        assert(islogical(fixed_foreground)&&isequal(size(fixed_foreground),image_size));
        foreground=fixed_foreground & limit_mask;
        spatial_model=struct('Method','user-confirmed-partition','AppliedThreshold',NaN, ...
            'Definition','manual geometry; signal quality does not trim the ROI');
        smooth_projection=single(reference);
    else
        [foreground,spatial_model,smooth_projection]=dsap_mip_foreground(reference,limit_mask,sensitivity);
    end
    spatial_background=limit_mask & ~foreground;
    valid_mask=foreground & ~nonfinite & longest>=minimum_run;
    no_signal=foreground & ~nonfinite & snr<low;
    uncertain=foreground & ~valid_mask & ~no_signal;
    labels=zeros(image_size,'uint8');
    labels(no_signal)=1; labels(uncertain)=2; labels(valid_mask)=3;
    labels(spatial_background)=7;
    features=struct('NoiseMap',single(noise_map),'PeakSNR',snr, ...
        'LongestDetectionRun',longest,'NoDetectableEnhancementMask',no_signal, ...
        'UncertainMask',uncertain,'NonfiniteInputMask',nonfinite, ...
        'SignalValidMask',valid_mask,'Labels',labels, ...
        'ProjectionForegroundMask',foreground,'ProjectionBackgroundMask',spatial_background, ...
        'SmoothedProjection',smooth_projection);
    model=struct('Method','MIP-main-component-plus-temporal-quality-v3', ...
        'AnatomicalBrainSegmentation',false,'Sensitivity',sensitivity, ...
        'DetectionSNR',high,'NoDetectionSNR',low,'MinimumConsecutiveFrames',minimum_run, ...
        'FrameCount',n,'ValidPixelCount',nnz(valid_mask),'UncertainPixelCount',nnz(uncertain), ...
        'NoDetectableEnhancementPixelCount',nnz(no_signal),'LimitPixelCount',nnz(limit_mask), ...
        'ThresholdStatus','engineering defaults for visual review, not clinically validated', ...
        'NoSignalMeaning','background OR undetectable/unopacified tissue; not proof of absent brain', ...
        'UsesAIFTemporalTemplate',false,'SpatialBoundary',spatial_model, ...
        'SpatialBackgroundPixelCount',nnz(spatial_background));
    if nargin>=6
        model.Method='manual-partition-with-advisory-signal-quality';
        model.ManualPartition=true;model.SignalQualityExcludesPixels=false;
    end
end
